// WindowsShell 入口。
// - `--self-test`：无头自检（渲染/长时/确定性/坐标桥/命中/交互/多显示器），CI 用退出码判定。
// - Windows 上无参数：进入 Win32 消息循环，4 个分层透明窗口跑共享核心模拟。
// - macOS 上无参数：打印提示后退出（macOS 用户运行 DesktopPets 主程序）。
//
// Windows 侧类型注意：Swift on Windows 的 WinSDK 模块里 BOOL = Int32 别名
// WindowsBool；宽字符串用 Array<UInt16>（无 NSString）；API 多要求 UINT(Int32)。

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

/// 全局回跳指针：WndProc 是 C 函数指针，无法捕获 self。
private var g_delegate: ShellAppDelegate?

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
    private var trayCreated = false
    private var currentExecutablePath: String {
        // GetModuleFileNameW 拿 exe 绝对路径（不依赖进程启动方式）。
        var buffer = [WCHAR](repeating: 0, count: 1024)
        let length = GetModuleFileNameW(nil, &buffer, UINT(buffer.count))
        guard length > 0 else { return "" }
        return String(decoding: buffer.prefix(Int(length)), as: UTF16.self)
    }

    struct PetWindowEntry {
        let id: String
        let hwnd: HWND
        let memory: HDC
        let title: [WCHAR]
    }

    // MARK: - 生命周期

    func run() {
        monitors = enumerateMonitors()
        model = ShellModel(characters: ShellModel.fallbackCharacters(), displays: monitors)
        g_delegate = self

        registerWindowClass()
        for character in model.characters {
            guard let entry = createPetWindow(id: character.id) else { continue }
            let memoryDC = CreateCompatibleDC(nil)!
            windows.append(entry)
            pointers[character.id] = PointerModel()
            alphaBuffers[character.id] = PointerModel.alphaBuffer(of: PetCanvas.render(character: character, pose: model.world.poses[0]))
        }
        present(frames: model.tick(deltaTime: 0))
        createTrayIcon()
        messageLoop()
    }

    // MARK: - 多显示器

    private func enumerateMonitors() -> [WorldRect] {
        var rects: [WorldRect] = []
        withUnsafeMutablePointer(to: &rects) { pointer in
            EnumDisplayMonitors(nil, nil, { rawMonitor, rawDC, rawRect, rawData in
                let rect = rawRect!.pointee
                guard let data = rawData?.assumingMemoryBound(to: [WorldRect].self) else { return 1 }
                if let world = WorldRect(
                    x: Double(rect.left), y: Double(rect.top),
                    width: Double(rect.right - rect.left),
                    height: Double(rect.bottom - rect.top)
                ) {
                    data.pointee.append(world)
                }
                return 1
            }, pointer)
        }
        return MonitorLayout.resolve(rects)
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

    /// 统一消息分发：托盘/命令消息送 delegate，宠物窗口消息按标题路由。
    private static func wndProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
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
        guard let hwnd else { return nil }
        return PetWindowEntry(id: id, hwnd: hwnd, memory: CreateCompatibleDC(nil)!, title: title)
    }

    // MARK: - 消息处理

    private func handleMessage(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
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
            handleCommand(id: INT(wparam.lowWord))
            return 0
        case UINT(WM_APP_TRAY):
            handleTrayCallback(lparam: lparam, screenX: Double(INT16(lparam.lowWord)), screenY: Double(INT16(lparam.highWord)))
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
    private func hitTest(hwnd: HWND, lparam: LPARAM) -> LRESULT {
        guard let entry = windows.first(where: { $0.hwnd == hwnd }),
              let alpha = alphaBuffers[entry.id] else { return LRESULT(HTTRANSPARENT) }
        let localX = Double(INT16(lparam.lowWord))
        let localY = Double(INT16(lparam.highWord))
        let normalizedX = localX / Double(ShellModel.windowWidth)
        let normalizedY = localY / Double(ShellModel.windowHeight)
        return LRESULT(PointerModel.isOpaque(
            normalizedX: normalizedX, normalizedY: normalizedY,
            alpha: alpha, width: ShellModel.windowWidth, height: ShellModel.windowHeight
        ) ? HTCLIENT : HTTRANSPARENT)
    }

    private func handlePress(hwnd: HWND, lparam: LPARAM) {
        guard let entry = windows.first(where: { $0.hwnd == hwnd }) else { return }
        let screen = screenPoint(from: lparam)
        pointers[entry.id]?.press(atX: screen.x, atY: screen.y)
    }

    private func handleMove(hwnd: HWND, lparam: LPARAM) {
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

    private func handleRelease(hwnd: HWND, lparam: LPARAM) {
        guard let entry = windows.first(where: { $0.hwnd == hwnd }) else { return }
        let screen = screenPoint(from: lparam)
        // 双击：系统 GetDoubleClickTime 窗口内的第二次按下；这里用 PointerModel
        // 的 tap 判定 + 手动计时近似（WM_LBUTTONUP 之间隔 < 双击时长即双击）。
        let isDoubleClick = lastTapTime[entry.id].map { elapsed in
            (Double(Date().timeIntervalSince1970) - elapsed) * 1000 < Double(GetDoubleClickTime())
        } ?? false
        lastTapTime[entry.id] = Double(Date().timeIntervalSince1970)
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
    }

    private var lastTapTime: [String: Double] = [:]

    /// LPARAM（屏幕坐标，多显示器可为负）→ (x, y)。
    private func screenPoint(from lparam: LPARAM) -> (x: Double, y: Double) {
        (Double(INT16(lparam.lowWord)), Double(INT16(lparam.highWord)))
    }

    // MARK: - 托盘

    private var trayData: NOTIFYICONDATAW = NOTIFYICONDATAW()

    private func createTrayIcon() {
        guard !trayCreated else { return }
        trayData = NOTIFYICONDATAW()
        trayData.cbSize = UINT(MemoryLayout<NOTIFYICONDATAW>.size)
        trayData.hWnd = windows.first?.hwnd
        trayData.uID = 1
        trayData.uFlags = UINT(NIF_MESSAGE | NIF_ICON | NIF_TIP)
        trayData.uCallbackMessage = UINT(WM_APP_TRAY)
        trayData.hIcon = makeTrayIcon()
        // 提示文字：桌面伙伴
        var tip = wide("桌面伙伴 DesktopPets")
        let maxTip = MemoryLayout<NOTIFYICONDATAW>.offset(of: NOTIFYICONDATAW.szTip)! / MemoryLayout<WCHAR>.size
        tip = Array(tip.prefix(maxTip - 1))
        withUnsafeMutableBytes(of: &trayData.szTip) { destination in
            tip.withUnsafeBytes { source in
                memcpy(destination.baseAddress, source.baseAddress, source.count)
            }
        }
        trayCreated = Shell_NotifyIconW(UINT(NIM_ADD), &trayData)
    }

    private func removeTrayIcon() {
        guard trayCreated else { return }
        _ = Shell_NotifyIconW(UINT(NIM_DELETE), &trayData)
        trayCreated = false
    }

    /// 用 PetCanvas 软件光栅器渲染第一个宠物头像为 32×32 托盘图标。
    private func makeTrayIcon() -> HICON {
        guard let character = model.characters.first,
              let pose = model.world.poses.first else { return LoadIconW(nil, IDC_APPLICATION) }
        let canvas = PetCanvas.render(character: character, pose: pose, width: 32, height: 32)
        return hicon(from: canvas)
    }

    private func hicon(from canvas: PetCanvas) -> HICON {
        var info = BITMAPV5HEADER()
        info.bV5Size = UINT32(MemoryLayout<BITMAPV5HEADER>.size)
        info.bV5Width = INT32(canvas.width)
        info.bV5Height = INT32(canvas.height)
        info.bV5Planes = 1
        info.bV5BitCount = 32
        info.bV5Compression = DWORD(BI_BITFIELDS)
        info.bV5RedMask = 0x00FF0000
        info.bV5GreenMask = 0x0000FF00
        info.bV5BlueMask = 0x000000FF
        info.bV5AlphaMask = 0xFF000000

        let screenDC = GetDC(nil)
        defer { ReleaseDC(nil, screenDC) }
        var bits: UnsafeMutableRawPointer?
        guard let dib = CreateDIBSection(screenDC, &info, UINT(DIB_RGB_COLORS), &bits, nil, 0),
              let bits else {
            return LoadIconW(nil, IDC_APPLICATION)
        }
        defer { DeleteObject(dib) }
        var pixels = canvas.pixels
        pixels.withUnsafeBytes { raw in
            memcpy(bits, raw.baseAddress, raw.count)
        }
        var iconInfo = ICONINFO()
        iconInfo.fIcon = true
        iconInfo.hbmColor = dib
        iconInfo.hbmMask = nil
        guard let icon = CreateIconIndirect(&iconInfo) else {
            return LoadIconW(nil, IDC_APPLICATION)
        }
        return icon
    }

    // MARK: - 菜单与命令

    /// 托盘右键 → 弹出菜单。TrackPopupMenu 需要窗口先 SetForegroundWindow，
    /// 否则菜单不响应外部点击（Win32 经典坑）。
    private func handleTrayCallback(lparam: LPARAM, screenX: Double, screenY: Double) {
        guard INT(lparam.lowWord) == WM_RBUTTONUP else { return }
        let menu = buildTrayMenu()
        guard let menu else { return }
        defer { DestroyMenu(menu) }
        guard let anchorWindow = windows.first?.hwnd else { return }
        SetForegroundWindow(anchorWindow)
        var point = POINT()
        GetCursorPos(&point)
        var command = UINT32(0)
        command = UINT32(TrackPopupMenuEx(
            menu,
            UINT(TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON),
            point.x, point.y, anchorWindow, nil
        ))
        PostMessageW(anchorWindow, UINT(WM_COMMAND), WPARAM(UINT(command)), 0)
    }

    private func buildTrayMenu() -> HMENU? {
        let menu = CreatePopupMenu()
        guard let menu else { return nil }
        let autostart = RegistryAutostart.isEnabled()
        _ = AppendMenuW(menu, UINT(MF_STRING | (autostart ? MF_CHECKED : MF_UNCHECKED)), UINT_PTR(ID_AUTOSTART), wide("开机自启"))
        _ = AppendMenuW(menu, UINT(MF_SEPARATOR), 0, nil)
        _ = AppendMenuW(menu, UINT(MF_STRING), UINT_PTR(ID_QUIT), wide("退出桌面伙伴"))
        return menu
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

// MARK: - 常量与小工具

private let WM_APP_TRAY = WM_APP + 1
private let ID_AUTOSTART = 2001
private let ID_QUIT = 2002

extension WPARAM {
    var lowWord: UINT { UINT(self & 0xFFFF) }
    var highWord: UINT { UINT((self >> 16) & 0xFFFF) }
}

extension LPARAM {
    var lowWord: INT16 { INT16(truncatingIfNeeded: self & 0xFFFF) }
    var highWord: INT16 { INT16(truncatingIfNeeded: (self >> 16) & 0xFFFF) }
}
#endif
