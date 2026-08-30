// WindowsShell 入口。
// - `--self-test`：无头自检（渲染/长时/确定性/配色断言），CI 用退出码判定。
// - Windows 上无参数：进入 Win32 消息循环，4 个分层透明窗口跑共享核心模拟。
// - macOS 上无参数：打印提示后退出（macOS 用户运行 DesktopPets 主程序）。
//
// Windows 侧类型注意：Swift on Windows 的 WinSDK 模块里 BOOL = Int32 别名
// WindowsBool；宽字符串用 Array<UInt16>（无 NSString）；API 多要求 UINT(Int32)。

import Foundation
import DesktopPetsCore

#if os(Windows)
import WinSDK
#endif

@main
struct WindowsShell {
    static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--self-test") {
            let failures = ShellModel.runSelfCheck()
            if failures.isEmpty {
                print("WindowsShell self-test: ok (render + 600 frames + determinism + palette)")
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

/// Win32 壳：为每个宠物开一个 WS_EX_LAYERED 顶层窗口，
/// 每 tick 用 UpdateLayeredWindow 提交 PetCanvas 的 BGRA 缓冲。
final class ShellAppDelegate {
    private var model: ShellModel!
    private var windows: [(id: String, hwnd: HWND, memory: HDC)] = []

    func run() {
        let display = primaryDisplayRect()
        model = ShellModel(characters: ShellModel.fallbackCharacters(), display: display)

        registerWindowClass()
        for character in model.characters {
            guard let hwnd = createPetWindow(id: character.id) else { continue }
            let memory = CreateCompatibleDC(nil)
            windows.append((character.id, hwnd, memory))
        }
        present(frames: model.tick(deltaTime: 0))
        messageLoop()
    }

    private func primaryDisplayRect() -> WorldRect {
        var rect = RECT()
        GetClientRect(GetDesktopWindow(), &rect)
        return WorldRect(
            x: 0,
            y: 0,
            width: Double(rect.right - rect.left),
            height: Double(rect.bottom - rect.top)
        ) ?? WorldRect(x: 0, y: 0, width: 1920, height: 1080)!
    }

    private func registerWindowClass() {
        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.lpfnWndProc = { hwnd, msg, wparam, lparam in
            if msg == UINT(WM_DESTROY) { PostQuitMessage(0); return 0 }
            return DefWindowProcW(hwnd, msg, wparam, lparam)
        }
        wc.hInstance = GetModuleHandleW(nil)
        wc.lpszClassName = wide("DesktopPetShell")
        _ = RegisterClassExW(&wc)
    }

    private func createPetWindow(id: String) -> HWND? {
        let exStyle = DWORD(WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_TOPMOST)
        let style = DWORD(WS_POPUP)
        let className = wide("DesktopPetShell")
        let title = wide(id)
        return CreateWindowExW(
            exStyle, className, title, UINT(style),
            100, 100, INT32(ShellModel.windowWidth), INT32(ShellModel.windowHeight),
            nil, nil, GetModuleHandleW(nil), nil
        )
    }

    private func present(frames: [(id: String, x: Int, y: Int, pose: PetPose, canvas: PetCanvas)]) {
        for frame in frames {
            guard let entry = windows.first(where: { $0.id == frame.id }) else { continue }
            SetWindowPos(entry.hwnd, nil, INT32(frame.x), INT32(frame.y), 0, 0, UINT(SWP_NOSIZE | SWP_NOACTIVATE))
            draw(canvas: frame.canvas, hwnd: entry.hwnd, memory: entry.memory)
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

        let screenSize = SIZE(cx: INT32(canvas.width), cy: INT32(canvas.height))
        let zero = POINT(x: 0, y: 0)
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
            while PeekMessageW(&msg, nil, 0, 0, UINT(PM_REMOVE)) != 0 {
                if msg.message == UINT(WM_QUIT) { running = false }
                TranslateMessage(&msg)
                DispatchMessageW(&msg)
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
#endif
