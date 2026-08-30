// WindowsShell 入口。
// - `--self-test`：无头自检（渲染/长时/确定性/坐标桥/命中/交互/多显示器），CI 用退出码判定。
// - Windows 上无参数：进入 Win32 消息循环，4 个分层透明窗口跑共享核心模拟。
// - macOS 上无参数：打印提示后退出（macOS 用户运行 DesktopPets 主程序）。
//
// Windows 侧类型注意（swift-win-sdk 实际约定，CI 验证过）：
// - HWND/HICON/HMENU 等句柄别名 = 非可选指针；但 API 输入参数与回调参数
//   多声明为 Optional（允许 NULL）。
// - BOOL = Int32、UINT = UInt32、WPARAM = UInt、LPARAM/LRESULT = Int64/Int。
// - 宽字符串用 Array<UInt16> + withUnsafeBufferPointer 传参。
// - C 函数指针回调不能捕获上下文：用文件级 nonisolated(unsafe) 暂存
//   （进程为单线程消息循环）。

import Foundation
import DesktopPetsCore

@main
struct WindowsShell {
    static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--self-test") {
            let failures = ShellModel.runSelfCheck()
            #if os(Windows)
            // WIC 手写 COM vtable 绑定的运行期验证：PNG 编解码往返逐像素核对。
            // 槽位错位 / GUID 传参错误在此崩溃或数据不符（真机 CI 上才有意义）。
            if WICSupport.roundTripSelfTest() {
                print("WIC round-trip: ok")
            } else {
                failures.append("WIC round-trip self-test failed")
            }
            #endif
            if failures.isEmpty {
                print("WindowsShell self-test: ok (render + coords + hit-test + interactions + monitors + 600 frames + determinism + avatar + session)")
            } else {
                for failure in failures { print("WindowsShell self-test FAILURE: \(failure)") }
                exit(1)
            }
            return
        }

        #if os(Windows)
        ShellAppDelegate().run()
        #else
        print("WindowsShell: GUI shell is only built for Windows. Use --self-test for headless checks, or run the DesktopPets app on macOS.")
        #endif
    }
}

#if os(Windows)
import WinSDK

/// WndProc 回跳指针：C 函数指针无法捕获 self。
/// 进程单线程消息循环内初始化一次、只读使用；
/// Swift 6 严格并发不识别该模式，故显式标注 unsafe。
private nonisolated(unsafe) var g_delegate: ShellAppDelegate?

/// EnumDisplayMonitors 回调暂存（同 g_delegate 的单线程 unsafe 模式）。
private nonisolated(unsafe) var g_monitorRects: [WorldRect] = []

/// Win32 壳：
/// - 每宠物一个 WS_EX_LAYERED 顶层窗口，每 tick UpdateLayeredWindow 提交画布。
/// - 逐像素命中：不透明像素接收点击，透明区域穿透（WM_NCHITTEST）。
/// - 托盘图标 + 右键菜单（开机自启开关、退出）。
/// - 多显示器枚举 + 显示配置变化时召回宠物。
///
/// 整类 @MainActor：Win32 消息循环本就运行在进程主线程，所有状态（窗口、
/// 托盘、名册）只在主线程触碰；C 回调（WndProc / EnumDisplayMonitors）经
/// MainActor.assumeIsolated 跳回，与 CharacterRosterStore 的隔离标注对齐。
@MainActor
final class ShellAppDelegate {
    private var model: ShellModel!
    private var windows: [PetWindowEntry] = []
    private var monitors: [WorldRect] = []
    private var pointers: [String: PointerModel] = [:]
    private var alphaBuffers: [String: [UInt8]] = [:]
    private var lastTapTime: [String: Double] = [:]
    private var trayCreated = false
    private var trayData = NOTIFYICONDATAW()
    /// 已加载的 512×512 头像位图（id → 位图），无头像的角色不出现。
    private var avatars: [String: PetCanvas.AvatarBitmap] = [:]
    /// 角色名册存取（头像导入/持久化）。非 Windows 为 nil。
    private var rosterStore: CharacterRosterStore? = nil
    /// 当前名册（draft 源，头像导入后立即保存并重建）。
    private var roster: CharacterRoster = .default
    /// 托盘动态图标上次刷新时间（秒级时间戳）。
    private var lastTrayRefresh: Double = 0
    /// 当前托盘 HICON 由 makeTrayIcon 新建，属非共享 GDI 句柄，必须轮换销毁，
    /// 否则约 2 小时触顶 GDI 句柄上限后托盘静默失效。
    private var currentTrayIcon: HICON? = nil
    /// 托盘图标刷新间隔（秒）。过低无意义（托盘刷新有系统开销）。
    private static let trayRefreshInterval: Double = 0.8

    struct PetWindowEntry {
        let id: String
        let hwnd: HWND
        let memory: HDC
    }

    // MARK: - 生命周期

    func run() {
        monitors = enumerateMonitors()
        rosterStore = makeRosterStore()
        if let store = rosterStore {
            roster = store.load(fallback: .default)
        }
        let characters = roster.manifests
        model = ShellModel(characters: characters, displays: monitors)
        restoreSession()
        loadAvatars(for: characters)
        g_delegate = self

        registerWindowClass()
        for character in model.characters {
            if let entry = createPetWindow(id: character.id) {
                windows.append(entry)
                pointers[character.id] = PointerModel()
                alphaBuffers[character.id] = PointerModel.alphaBuffer(
                    of: renderFrame(character: character)
                )
            }
        }
        present(frames: model.tick(deltaTime: 0))
        createTrayIcon()
        messageLoop()
        persistSession()
    }

    /// Windows 数据目录：%APPDATA%（FOLDERID_RoamingAppData）。
    /// 用 ProcessInfo 环境变量取值：SDK 导出的 FOLDERID_RoamingAppData 是
    /// let 常量，不能作 SHGetKnownFolderPath 的 inout 实参，与其绕弯不如
    /// 直接读标准环境变量（用户级 Roaming 目录等价）。
    /// nil = 目录定位失败（理论罕见），名册功能整体回退默认。
    private func makeRosterStore() -> CharacterRosterStore? {
        guard let appData = ProcessInfo.processInfo.environment["APPDATA"],
              !appData.isEmpty else { return nil }
        return CharacterRosterStore(
            rootDirectory: URL(fileURLWithPath: appData, isDirectory: true)
                .appendingPathComponent("DesktopPets", isDirectory: true),
            normalizePNG: { data in
                let decoded = WICSupport.decodeBGRA(data: data)
                guard let (pixels, width, height) = decoded else {
                    throw AvatarNormalizeRuntimeError.undecodable
                }
                let normalized = try AvatarNormalizer.normalizedBGRA(pixels: pixels, width: width, height: height)
                guard let png = AvatarNormalizer.encodePNG(bgra: normalized.pixels, width: normalized.width, height: normalized.height) else {
                    throw AvatarNormalizeRuntimeError.encodingFailed
                }
                return png
            }
        )
    }

    /// 按名册加载各角色头像位图。导入源读盘失败 → 回退内置渲染（不崩溃）。
    private func loadAvatars(for characters: [CharacterManifest]) {
        avatars.removeAll(keepingCapacity: true)
        for character in characters {
            guard case let .imported(filename) = character.avatarSource,
                  let url = rosterStore?.importedAvatarURL(for: .imported(filename: filename)),
                  let data = try? Data(contentsOf: url),
                  let (pixels, width, height) = WICSupport.decodeBGRA(data: data),
                  let normalized = try? AvatarNormalizer.normalizedBGRA(pixels: pixels, width: width, height: height) else {
                continue
            }
            avatars[character.id] = PetCanvas.AvatarBitmap(pixels: normalized.pixels)
        }
    }

    /// 单帧渲染：带角色头像（若有）。
    private func renderFrame(character: CharacterManifest) -> PetCanvas {
        PetCanvas.render(character: character, pose: model.world.poses.first { $0.id == character.id } ?? model.world.poses[0], avatar: avatars[character.id])
    }

    // MARK: - 会话位置持久化

    /// 启动时恢复 leader 位置。解析失败/越界由 placeLeader 夹紧，静默回退默认。
    private func restoreSession() {
        guard let raw = RegistryStrings.get(
            subKeyPath: SessionStatePolicy.subKeyPath, valueName: SessionStatePolicy.valueName
        ), let state = SessionState.decode(raw) else { return }
        model.placeLeader(atX: state.petX, atY: state.petY)
    }

    /// 退出前保存 leader 位置。失败静默（下次回默认位置，可接受）。
    private func persistSession() {
        guard let leader = model.world.agents.first else { return }
        let state = SessionState(petX: leader.position.x, petY: leader.position.y)
        _ = RegistryStrings.set(
            subKeyPath: SessionStatePolicy.subKeyPath,
            valueName: SessionStatePolicy.valueName,
            string: state.encode()
        )
    }

    // MARK: - 多显示器

    private func enumerateMonitors() -> [WorldRect] {
        g_monitorRects.removeAll(keepingCapacity: true)
        _ = EnumDisplayMonitors(nil, nil, { _, _, rawRect, _ in
            guard let rawRect else { return false }
            let rect = rawRect.pointee
            if let world = WorldRect(
                x: Double(rect.left), y: Double(rect.top),
                width: Double(rect.right - rect.left),
                height: Double(rect.bottom - rect.top)
            ) {
                MainActor.assumeIsolated {
                    g_monitorRects.append(world)
                }
            }
            return true
        }, 0)
        return MonitorLayout.resolve(g_monitorRects)
    }

    /// WM_DISPLAYCHANGE 后重新枚举显示器；主屏变化时召回全部宠物到新主屏。
    private func refreshMonitors() {
        let old = model.obstacleMap.displays
        monitors = enumerateMonitors()
        model.obstacleMap = ObstacleMap(displays: monitors, obstacles: [])
        let newHome = MonitorLayout.homeDisplay(in: monitors)
        let oldHome = MonitorLayout.homeDisplay(in: old)
        if MonitorLayout.action(oldHome: oldHome, newHome: newHome) == .recall {
            model.world.recall(to: newHome)
        }
    }

    // MARK: - 窗口注册与创建

    private func registerWindowClass() {
        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.lpfnWndProc = { hwnd, msg, wparam, lparam in
            ShellAppDelegate.wndProc(hwnd: hwnd, msg: msg, wparam: wparam, lparam: lparam)
        }
        wc.hInstance = GetModuleHandleW(nil)
        var className = wide("DesktopPetShell")
        className.withUnsafeBufferPointer { buffer in
            wc.lpszClassName = buffer.baseAddress
        }
        // 类名缓冲必须在 RegisterClassExW 调用期间存活——上面 closure 内
        // 赋值即可；RegisterClassExW 在同一作用域调用。
        _ = className.withUnsafeBufferPointer { _ in RegisterClassExW(&wc) }
    }

    /// 统一消息分发（WndProc 回调参数句柄是 Optional，统一在此解包）。
    /// C 回调在主线程被系统调用，assumeIsolated 跳回 @MainActor 隔离域。
    private static func wndProc(hwnd: HWND?, msg: UINT, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
        guard let delegate = g_delegate else { return DefWindowProcW(hwnd, msg, wparam, lparam) }
        return MainActor.assumeIsolated {
            delegate.handleMessage(hwnd: hwnd, msg: msg, wparam: wparam, lparam: lparam)
        }
    }

    private func createPetWindow(id: String) -> PetWindowEntry? {
        // 不加 WS_EX_TRANSPARENT：逐像素命中在 WM_NCHITTEST 里做。
        let exStyle = DWORD(WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST)
        let style = DWORD(WS_POPUP)
        var className = wide("DesktopPetShell")
        var title = wide(id)
        let hwnd = className.withUnsafeBufferPointer { classBuffer in
            title.withUnsafeBufferPointer { titleBuffer in
                CreateWindowExW(
                    exStyle, classBuffer.baseAddress, titleBuffer.baseAddress, UINT(style),
                    100, 100, INT32(ShellModel.windowWidth), INT32(ShellModel.windowHeight),
                    nil, nil, GetModuleHandleW(nil), nil
                )
            }
        }
        guard let hwnd, let memory = CreateCompatibleDC(nil) else { return nil }
        return PetWindowEntry(id: id, hwnd: hwnd, memory: memory)
    }

    // MARK: - 消息处理

    private func handleMessage(hwnd: HWND?, msg: UINT, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
        switch msg {
        case UINT(WM_NCHITTEST):
            return hitTest(hwnd: hwnd, lparam: lparam)
        case UINT(WM_LBUTTONDOWN):
            handlePress(hwnd: hwnd, lparam: lparam)
            return 0
        case UINT(WM_MOUSEMOVE):
            handleMove(hwnd: hwnd, lparam: lparam)
            return 0
        case UINT(WM_LBUTTONUP):
            handleRelease(hwnd: hwnd, lparam: lparam)
            return 0
        case UINT(WM_COMMAND):
            handleCommand(id: INT(wparam & 0xFFFF))
            return 0
        case UINT(WM_APP_TRAY):
            handleTrayCallback(lparam: lparam)
            return 0
        case UINT(WM_DISPLAYCHANGE):
            refreshMonitors()
            return 0
        case UINT(WM_DESTROY):
            removeTrayIcon()
            PostQuitMessage(0)
            return 0
        default:
            return DefWindowProcW(hwnd, msg, wparam, lparam)
        }
    }

    /// 逐像素命中：点在不透明像素 → HTCLIENT（收点击）；否则 HTTRANSPARENT（穿透）。
    private func hitTest(hwnd: HWND?, lparam: LPARAM) -> LRESULT {
        guard let entry = windows.first(where: { $0.hwnd == hwnd }),
              let alpha = alphaBuffers[entry.id] else { return LRESULT(HTTRANSPARENT) }
        let localX = Double(INT16(truncatingIfNeeded: lparam & 0xFFFF))
        let localY = Double(INT16(truncatingIfNeeded: (lparam >> 16) & 0xFFFF))
        let normalizedX = localX / Double(ShellModel.windowWidth)
        let normalizedY = localY / Double(ShellModel.windowHeight)
        let opaque = PointerModel.isOpaque(
            normalizedX: normalizedX, normalizedY: normalizedY,
            alpha: alpha, width: ShellModel.windowWidth, height: ShellModel.windowHeight
        )
        return LRESULT(opaque ? HTCLIENT : HTTRANSPARENT)
    }

    private func handlePress(hwnd: HWND?, lparam: LPARAM) {
        guard let entry = windows.first(where: { $0.hwnd == hwnd }) else { return }
        let screen = screenPoint(from: lparam)
        pointers[entry.id]?.press(atX: screen.x, atY: screen.y)
    }

    private func handleMove(hwnd: HWND?, lparam: LPARAM) {
        guard let entry = windows.first(where: { $0.hwnd == hwnd }) else { return }
        let screen = screenPoint(from: lparam)
        guard let event = pointers[entry.id]?.move(toX: screen.x, toY: screen.y), event != .none else { return }
        switch event {
        case .beginDrag:
            model.handle(beginDrag: entry.id, screenX: screen.x, screenY: screen.y)
            present(frames: model.tick(deltaTime: 0))
        case .drag:
            model.handle(drag: entry.id, screenX: screen.x, screenY: screen.y)
            present(frames: model.tick(deltaTime: 0))
        default:
            break
        }
    }

    private func handleRelease(hwnd: HWND?, lparam: LPARAM) {
        guard let entry = windows.first(where: { $0.hwnd == hwnd }),
              let pointer = pointers[entry.id] else { return }
        let screen = screenPoint(from: lparam)
        // 双击判定：两次释放间隔 < 系统双击时长即双击。
        let now = Double(Date().timeIntervalSince1970)
        let isDoubleClick = lastTapTime[entry.id].map { (now - $0) * 1000 < Double(GetDoubleClickTime()) } ?? false
        lastTapTime[entry.id] = now
        guard let event = pointers[entry.id]?.release(isDoubleClick: isDoubleClick) else { return }
        switch event {
        case .drag:
            model.handle(release: entry.id, screenX: screen.x, screenY: screen.y)
            present(frames: model.tick(deltaTime: 0))
        case let .tap(double):
            if double {
                _ = model.handle(gather: entry.id)
            } else {
                _ = model.handle(react: entry.id)
            }
            present(frames: model.tick(deltaTime: 0))
        default:
            break
        }
        _ = pointer
    }

    /// LPARAM（屏幕坐标，多显示器可为负）→ (x, y)。
    private func screenPoint(from lparam: LPARAM) -> (x: Double, y: Double) {
        (Double(INT16(truncatingIfNeeded: lparam & 0xFFFF)),
         Double(INT16(truncatingIfNeeded: (lparam >> 16) & 0xFFFF)))
    }

    // MARK: - 托盘

    private func createTrayIcon() {
        guard !trayCreated, let anchor = windows.first?.hwnd else { return }
        trayData = NOTIFYICONDATAW()
        trayData.cbSize = UINT(MemoryLayout<NOTIFYICONDATAW>.size)
        trayData.hWnd = anchor
        trayData.uID = 1
        trayData.uFlags = UINT(NIF_MESSAGE | NIF_ICON | NIF_TIP)
        trayData.uCallbackMessage = UINT(WM_APP_TRAY)
        trayData.hIcon = initialTrayIcon()
        writeTooltip("桌面伙伴 DesktopPets")
        // swift-win-sdk 把 BOOL 返回桥接为 Swift Bool。
        trayCreated = Shell_NotifyIconW(UINT(NIM_ADD), &trayData)
    }

    /// 写入悬停提示文字。szTip 位于 NOTIFYICONDATAW 偏移 40
    /// （x64 C 布局：cbSize 0, hWnd 8, uID 16, uFlags 20, uCallbackMessage 24,
    /// hIcon 32, szTip 128 个 WCHAR 从 40 起）。结构体零初始化保证 NUL 结尾。
    private func writeTooltip(_ text: String) {
        let codeUnits = Array(text.utf16.prefix(126))
        withUnsafeMutableBytes(of: &trayData) { raw in
            guard let base = raw.baseAddress else { return }
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            for (index, unit) in codeUnits.enumerated() {
                bytes[40 + index * 2] = UInt8(unit & 0xFF)
                bytes[40 + index * 2 + 1] = UInt8((unit >> 8) & 0xFF)
            }
        }
    }

    private func removeTrayIcon() {
        guard trayCreated else { return }
        _ = Shell_NotifyIconW(UINT(NIM_DELETE), &trayData)
        trayCreated = false
    }

    /// 系统默认应用图标（LoadIconW 共享句柄，无需销毁）。
    /// swift-win-sdk 无 IDI_APPLICATION 常量，MAKEINTRESOURCEW 是 C 宏在 Swift
    /// 也无符号 —— 其展开就是 (LPWSTR)((INT_PTR)id)，故直接构造同位模式指针。
    private func fallbackIcon() -> HICON? {
        guard let name = UnsafePointer<WCHAR>(bitPattern: 32512) else { return nil }
        return LoadIconW(nil, name)
    }

    /// 初次挂托盘的图标（共享系统句柄，不参与轮换销毁）。
    private func initialTrayIcon() -> HICON? {
        fallbackIcon()
    }

    /// 用 PetCanvas 软件光栅器渲染第一个宠物头像为 32×32 托盘图标。
    private func makeTrayIcon() -> HICON? {
        guard let character = model.characters.first,
              let pose = model.world.poses.first else { return fallbackIcon() }
        let canvas = PetCanvas.render(character: character, pose: pose, avatar: avatars[character.id], width: 32, height: 32)
        return hicon(from: canvas)
    }

    /// 托盘动态图标：按当前帧重建并 NIM_MODIFY。失败静默保持旧图标。
    /// 动感来源：直接用 world 当前 pose（phase 随模拟 tick 自然推进），
    /// PetPose.phase 是 let 不可外部变异。旧图标轮换 DestroyIcon 防 GDI 泄漏。
    private func refreshTrayIcon() {
        guard trayCreated, let character = model.characters.first,
              let pose = model.world.poses.first else { return }
        let canvas = PetCanvas.render(character: character, pose: pose, avatar: avatars[character.id], width: 32, height: 32)
        guard let icon = hicon(from: canvas) else { return }
        trayData.hIcon = icon
        guard Shell_NotifyIconW(UINT(NIM_MODIFY), &trayData) else {
            DestroyIcon(icon)
            return
        }
        if let previous = currentTrayIcon { DestroyIcon(previous) }
        currentTrayIcon = icon
    }

    private func hicon(from canvas: PetCanvas) -> HICON? {
        // 32bpp BI_RGB DIB：每像素 BGRA，第 4 字节 alpha，CreateIconIndirect 直接支持。
        var info = BITMAPINFO()
        info.bmiHeader.biSize = UINT(MemoryLayout<BITMAPINFOHEADER>.size)
        info.bmiHeader.biWidth = INT32(canvas.width)
        info.bmiHeader.biHeight = INT32(canvas.height)
        info.bmiHeader.biPlanes = 1
        info.bmiHeader.biBitCount = 32
        info.bmiHeader.biCompression = DWORD(BI_RGB)

        let screenDC = GetDC(nil)
        defer { ReleaseDC(nil, screenDC) }
        var bits: UnsafeMutableRawPointer?
        guard let dib = CreateDIBSection(screenDC, &info, UINT(DIB_RGB_COLORS), &bits, nil, 0),
              let bits else {
            return fallbackIcon()
        }
        defer { DeleteObject(dib) }
        var pixels = canvas.pixels
        pixels.withUnsafeBytes { raw in
            memcpy(bits, raw.baseAddress, raw.count)
        }
        // CreateIconIndirect 要求 hbmMask 非 NULL（1bpp 单色掩码）。
        guard let mask = CreateBitmap(INT32(canvas.width), INT32(canvas.height), UINT32(1), UINT32(1), nil) else {
            return fallbackIcon()
        }
        defer { DeleteObject(mask) }
        var iconInfo = ICONINFO()
        iconInfo.fIcon = true
        iconInfo.hbmMask = mask
        iconInfo.hbmColor = dib
        return CreateIconIndirect(&iconInfo)
    }

    // MARK: - 菜单与命令

    /// 托盘右键 → 弹出菜单。TrackPopupMenu 需要窗口先 SetForegroundWindow，
    /// 否则菜单不响应外部点击（Win32 经典坑）。
    ///
    /// 不用 TPM_RETURNCMD：swift-win-sdk 把该函数 BOOL 返回盲桥接为 Swift Bool，
    /// 选中项 ID 无法通过返回值获取。改用默认模式 —— 菜单选中后向 anchor 窗口
    /// 自然投递 WM_COMMAND，由 handleMessage 现有路由处理，语义完全等价。
    private func handleTrayCallback(lparam: LPARAM) {
        guard INT(truncatingIfNeeded: lparam & 0xFFFF) == WM_RBUTTONUP,
              let anchor = windows.first?.hwnd else { return }
        guard let menu = buildTrayMenu() else { return }
        defer { DestroyMenu(menu) }
        SetForegroundWindow(anchor)
        var point = POINT()
        _ = GetCursorPos(&point)
        _ = TrackPopupMenuEx(
            menu,
            UINT(TPM_RIGHTBUTTON),
            point.x, point.y, anchor, nil
        )
        // 菜单选中项以 WM_COMMAND 形式到达 anchor 的 wndProc（已有路由）。
        // 补一次 PostMessageW(WM_NULL)：TrackPopupMenu 内部进入模态循环，
        // 若无后续消息，anchor 的 wndProc 在菜单关闭前收不到 WM_COMMAND。
        PostMessageW(anchor, UINT(WM_NULL), 0, 0)
    }

    private func buildTrayMenu() -> HMENU? {
        guard let menu = CreatePopupMenu() else { return nil }
        let autostart = RegistryAutostart.isEnabled()
        appendMenuItem(menu, flags: UINT(MF_STRING), id: ID_IMPORT_AVATAR, title: "导入头像…")
        appendMenuItem(menu, flags: UINT(MF_STRING), id: ID_RESET_ROSTER, title: "恢复默认角色")
        _ = AppendMenuW(menu, UINT(MF_SEPARATOR), 0, nil)
        appendMenuItem(menu, flags: UINT(MF_STRING | (autostart ? MF_CHECKED : MF_UNCHECKED)), id: ID_AUTOSTART, title: "开机自启")
        _ = AppendMenuW(menu, UINT(MF_SEPARATOR), 0, nil)
        appendMenuItem(menu, flags: UINT(MF_STRING), id: ID_QUIT, title: "退出桌面伙伴")
        return menu
    }

    private func appendMenuItem(_ menu: HMENU, flags: UINT, id: Int, title: String) {
        var text = wide(title)
        _ = text.withUnsafeBufferPointer { buffer in
            AppendMenuW(menu, flags, UINT_PTR(id), buffer.baseAddress)
        }
    }

    private func handleCommand(id: INT) {
        switch id {
        case INT(ID_AUTOSTART):
            let enable = !RegistryAutostart.isEnabled()
            _ = RegistryAutostart.setEnabled(enable, executablePath: currentExecutablePath)
        case INT(ID_IMPORT_AVATAR):
            importAvatarFlow()
        case INT(ID_RESET_ROSTER):
            resetRoster()
        case INT(ID_QUIT):
            if let anchor = windows.first?.hwnd {
                PostMessageW(anchor, UINT(WM_CLOSE), 0, 0)
            }
        default:
            break
        }
    }

    // MARK: - 头像导入（替换 leader 角色的头像）

    /// 文件对话框选图 → WIC 解码 → 居中裁剪 512×512 → PNG 落盘 →
    /// 更新名册 leader 的 avatarSource → 保存并热重建。
    private func importAvatarFlow() {
        guard let store = rosterStore else { return }
        guard let data = pickImageFile() else { return }  // 用户取消，静默返回
        guard let (pixels, width, height) = WICSupport.decodeBGRA(data: data),
              let normalized = try? AvatarNormalizer.normalizedBGRA(pixels: pixels, width: width, height: height),
              let png = AvatarNormalizer.encodePNG(bgra: normalized.pixels, width: normalized.width, height: normalized.height) else {
            return  // 解码/编码失败：静默放弃本次导入，保持现状
        }
        guard let filename = try? store.importAvatar(data: png) else { return }
        var draft = roster
        guard !draft.profiles.isEmpty else { return }
        draft.profiles[0].avatarSource = .imported(filename: filename)
        guard let valid = try? draft.validated(),
              (try? store.save(valid)) != nil else { return }
        roster = valid
        rebuild(with: roster.manifests)
    }

    /// 恢复默认角色：清名册 + 清导入头像 + 重建。
    private func resetRoster() {
        guard let store = rosterStore else { return }
        try? store.removeUnreferencedAvatars(roster: .default)
        try? FileManager.default.removeItem(at: store.rosterURL)
        roster = .default
        rebuild(with: roster.manifests)
    }

    /// 名册变化后的热重建：关窗 → 新角色重开窗（窗口数随之变化）。
    private func rebuild(with characters: [CharacterManifest]) {
        for entry in windows {
            DestroyWindow(entry.hwnd)
            DeleteDC(entry.memory)
        }
        windows.removeAll(keepingCapacity: true)
        pointers.removeAll(keepingCapacity: true)
        alphaBuffers.removeAll(keepingCapacity: true)
        lastTapTime.removeAll(keepingCapacity: true)
        model = ShellModel(characters: characters, displays: monitors)
        loadAvatars(for: characters)
        for character in characters {
            if let entry = createPetWindow(id: character.id) {
                windows.append(entry)
                pointers[character.id] = PointerModel()
                alphaBuffers[character.id] = PointerModel.alphaBuffer(of: renderFrame(character: character))
            }
        }
        present(frames: model.tick(deltaTime: 0))
        // anchor 窗口重建后托盘必须重挂（旧 hWnd 已失效）。
        removeTrayIcon()
        createTrayIcon()
    }

    /// GetOpenFileNameW 文件对话框（图片常见格式过滤）。取消返回 nil。
    private func pickImageFile() -> Data? {
        let filter = "图片\0*.png;*.jpg;*.jpeg;*.bmp;*.gif\0所有文件\0*.*\0\0"
        var ofn = OPENFILENAMEW()
        var fileBuffer = [WCHAR](repeating: 0, count: 1024)
        var filterBuffer = wide(filter).dropLast() + [0, 0]  // 双 NUL 结尾
        ofn.lStructSize = UINT32(MemoryLayout<OPENFILENAMEW>.size)
        ofn.hwndOwner = windows.first?.hwnd
        ofn.lpstrFilter = filterBuffer.withUnsafeBufferPointer { $0.baseAddress }
        ofn.lpstrFile = UnsafeMutablePointer<WCHAR>(mutating: fileBuffer.withUnsafeBufferPointer { $0.baseAddress })
        ofn.nMaxFile = UINT32(fileBuffer.count)
        ofn.Flags = DWORD(OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR)
        guard GetOpenFileNameW(&ofn) else { return nil }
        let pathLength = fileBuffer.prefix(while: { $0 != 0 }).count
        let path = String(decoding: fileBuffer.prefix(pathLength), as: UTF16.self)
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    /// GetModuleFileNameW 拿 exe 绝对路径（不依赖进程启动方式）。
    private var currentExecutablePath: String {
        var buffer = [WCHAR](repeating: 0, count: 1024)
        let length = GetModuleFileNameW(nil, &buffer, UINT(buffer.count))
        guard length > 0 else { return "" }
        return String(decoding: buffer.prefix(Int(length)), as: UTF16.self)
    }

    // MARK: - 渲染与消息循环

    private func present(frames: [(id: String, x: Int, y: Int, pose: PetPose, canvas: PetCanvas)]) {
        for frame in frames {
            guard let entry = windows.first(where: { $0.id == frame.id }) else { continue }
            let home = MonitorLayout.homeDisplay(in: model.obstacleMap.displays)
            let clamped = MonitorLayout.clampedWindowOrigin(
                x: frame.x, y: frame.y, width: ShellModel.windowWidth, height: ShellModel.windowHeight, in: home
            )
            SetWindowPos(entry.hwnd, nil, INT32(clamped.x), INT32(clamped.y), 0, 0, UINT(SWP_NOSIZE | SWP_NOACTIVATE))
            draw(canvas: frame.canvas, hwnd: entry.hwnd, memory: entry.memory)
            alphaBuffers[frame.id] = PointerModel.alphaBuffer(of: frame.canvas)
        }
    }

    /// 把画布 BGRA 缓冲经 DIB 提交到分层窗口（逐像素 alpha）。
    private func draw(canvas: PetCanvas, hwnd: HWND, memory: HDC) {
        var info = BITMAPINFO()
        info.bmiHeader.biSize = UINT(MemoryLayout<BITMAPINFOHEADER>.size)
        info.bmiHeader.biWidth = INT32(canvas.width)
        info.bmiHeader.biHeight = INT32(canvas.height)  // 正值 = 自上而下
        info.bmiHeader.biPlanes = 1
        info.bmiHeader.biBitCount = 32
        info.bmiHeader.biCompression = DWORD(BI_RGB)

        var pixels = canvas.pixels
        let screenDC = GetDC(nil)
        defer { ReleaseDC(nil, screenDC) }

        var bits: UnsafeMutableRawPointer?
        guard let dib = CreateDIBSection(screenDC, &info, UINT(DIB_RGB_COLORS), &bits, nil, 0) else { return }
        defer { DeleteObject(dib) }
        guard let bits else { return }

        pixels.withUnsafeBytes { raw in
            memcpy(bits, raw.baseAddress, raw.count)
        }

        var screenSize = SIZE(cx: INT32(canvas.width), cy: INT32(canvas.height))
        var zero = POINT(x: 0, y: 0)
        var blend = BLENDFUNCTION()
        blend.BlendOp = BYTE(AC_SRC_OVER)
        blend.SourceConstantAlpha = 255
        UpdateLayeredWindow(hwnd, screenDC, nil, &screenSize, memory, &zero, COLORREF(0), &blend, UINT(ULW_ALPHA))

        // 把 DIB 内容选入 memory DC，供下一帧 UpdateLayeredWindow 使用。
        let old = SelectObject(memory, dib)
        _ = old
    }

    private func messageLoop() {
        var msg = MSG()
        var last = Double(Date().timeIntervalSince1970)
        var running = true
        while running {
            var hasMessage = PeekMessageW(&msg, nil, 0, 0, UINT(PM_REMOVE))
            while hasMessage {
                if msg.message == UINT(WM_QUIT) { running = false }
                TranslateMessage(&msg)
                DispatchMessageW(&msg)
                hasMessage = PeekMessageW(&msg, nil, 0, 0, UINT(PM_REMOVE))
            }
            let now = Double(Date().timeIntervalSince1970)
            let delta = min(max(now - last, 0), 0.1)
            if delta >= 1.0 / ShellModel.simulationFPS {
                last = now
                present(frames: model.tick(deltaTime: delta))
            }
            // 托盘动态图标：低频刷新（重建 HICON 有 GDI 开销，不能按帧刷）。
            if now - lastTrayRefresh >= Self.trayRefreshInterval {
                lastTrayRefresh = now
                refreshTrayIcon()
            }
            Sleep(10)
        }
    }

    private func wide(_ string: String) -> [WCHAR] {
        Array(string.utf16) + [0]
    }
}

    // MARK: - 常量

private let WM_APP_TRAY = WM_APP + 1
private let ID_AUTOSTART = 2001
private let ID_QUIT = 2002
private let ID_IMPORT_AVATAR = 2003
private let ID_RESET_ROSTER = 2004

/// normalizePNG 闭包内抛错的运行时错误类型（跨闭包边界）。
enum AvatarNormalizeRuntimeError: Error {
    case undecodable
    case encodingFailed
}
#endif
