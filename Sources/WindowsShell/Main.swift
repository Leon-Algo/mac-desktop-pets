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
            if failures.isEmpty {
                print("WindowsShell self-test: ok (render + coords + hit-test + interactions + monitors + 600 frames + determinism)")
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
final class ShellAppDelegate {
    private var model: ShellModel!
    private var windows: [PetWindowEntry] = []
    private var monitors: [WorldRect] = []
    private var pointers: [String: PointerModel] = [:]
    private var alphaBuffers: [String: [UInt8]] = [:]
    private var lastTapTime: [String: Double] = [:]
    private var trayCreated = false
    private var trayData = NOTIFYICONDATAW()

    struct PetWindowEntry {
        let id: String
        let hwnd: HWND
        let memory: HDC
    }

    // MARK: - 生命周期

    func run() {
        monitors = enumerateMonitors()
        model = ShellModel(characters: ShellModel.fallbackCharacters(), displays: monitors)
        g_delegate = self

        registerWindowClass()
        for character in model.characters {
            if let entry = createPetWindow(id: character.id) {
                windows.append(entry)
                pointers[character.id] = PointerModel()
                alphaBuffers[character.id] = PointerModel.alphaBuffer(
                    of: PetCanvas.render(character: character, pose: model.world.poses[0])
                )
            }
        }
        present(frames: model.tick(deltaTime: 0))
        createTrayIcon()
        messageLoop()
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
                g_monitorRects.append(world)
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
    private static func wndProc(hwnd: HWND?, msg: UINT, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
        guard let delegate = g_delegate else { return DefWindowProcW(hwnd, msg, wparam, lparam) }
        return delegate.handleMessage(hwnd: hwnd, msg: msg, wparam: wparam, lparam: lparam)
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
        trayData.hIcon = makeTrayIcon()
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

    /// 用 PetCanvas 软件光栅器渲染第一个宠物头像为 32×32 托盘图标。
    private func makeTrayIcon() -> HICON? {
        guard let character = model.characters.first,
              let pose = model.world.poses.first else { return fallbackIcon() }
        let canvas = PetCanvas.render(character: character, pose: pose, width: 32, height: 32)
        return hicon(from: canvas)
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
        case INT(ID_QUIT):
            if let anchor = windows.first?.hwnd {
                PostMessageW(anchor, UINT(WM_CLOSE), 0, 0)
            }
        default:
            break
        }
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
#endif
