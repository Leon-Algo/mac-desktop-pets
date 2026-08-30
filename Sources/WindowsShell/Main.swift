// WindowsShell 入口。
// - `--self-test`：无头自检（渲染/长时/确定性/配色断言），CI 用退出码判定。
// - Windows 上无参数：进入 Win32 消息循环，4 个分层透明窗口跑共享核心模拟。
// - macOS 上无参数：打印提示后退出（macOS 用户运行 DesktopPets 主程序）。

import Foundation
import DesktopPetsCore

#if os(Windows)
import CRT
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
        runWindows()
        #else
        print("WindowsShell: GUI shell is only built for Windows. Use --self-test for headless checks, or run the DesktopPets app on macOS.")
        #endif
    }

    #if os(Windows)
    private static func runWindows() {
        let appDelegate = ShellAppDelegate()
        appDelegate.run()
    }
    #endif
}

#if os(Windows)
import WinSDK

/// Win32 壳：为每个宠物开一个 WS_EX_LAYERED 顶层窗口，
/// 每 tick 用 UpdateLayeredWindow 提交 PetCanvas 的 BGRA 缓冲。
final class ShellAppDelegate {
    private var model: ShellModel!
    private var windows: [(id: String, hwnd: HWND, memory: HDC)] = []
    private var lastTick: Double = 0

    func run() {
        let display = primaryDisplayRect()
        model = ShellModel(characters: ShellModel.fallbackCharacters(), display: display)

        guard let classRegistered = registerWindowClass() else { return }
        _ = classRegistered

        for character in model.characters {
            let hwnd = createPetWindow(id: character.id)
            let memory = CreateCompatibleDC(nil)
            windows.append((character.id, hwnd!, memory))
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

    private func registerWindowClass() -> BOOL? {
        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.lpfnWndProc = { hwnd, msg, wparam, lparam in
            if msg == WM_DESTROY { PostQuitMessage(0); return 0 }
            return DefWindowProcW(hwnd, msg, wparam, lparam)
        }
        wc.hInstance = GetModuleHandleW(nil)
        wc.lpszClassName = ("DesktopPetShell" as NSString).utf16String
        let atom = RegisterClassExW(&wc)
        return atom == 0 ? nil : 1
    }

    private func createPetWindow(id: String) -> HWND? {
        let exStyle = UINT(DWORD(WS_EX_LAYERED) | DWORD(WS_EX_TRANSPARENT) | DWORD(WS_EX_TOOLWINDOW) | DWORD(WS_EX_TOPMOST))
        return CreateWindowExW(
            exStyle,
            ("DesktopPetShell" as NSString).utf16String,
            (id as NSString).utf16String,
            UINT(DWORD(WS_POPUP)),
            100, 100, Int32(ShellModel.windowWidth), Int32(ShellModel.windowHeight),
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

    private func draw(canvas: PetCanvas, hwnd: HWND, memory: HDC) {
        var info = BITMAPINFO()
        info.bmiHeader.biSize = UINT(MemoryLayout<BITMAPINFOHEADER>.size)
        info.bmiHeader.biWidth = INT32(canvas.width)
        info.bmiHeader.biHeight = INT32(canvas.height)  // 正值 = 自上而下
        info.bmiHeader.biPlanes = 1
        info.bmiHeader.biBitCount = 32
        info.bmiHeader.biCompression = DWORD(BI_RGB)

        var pixels = canvas.pixels
        let oldBitmap = SelectObject(memory, CreateDIBSection(memory, &info, DIB_RGB_COLORS, nil, nil, 0))
        // DIB 数据布局即 BGRA：直接写回。
        pixels.withUnsafeMutableBytes { raw in
            _ = SetDIBits(memory, /*bitmap*/ nil, 0, UINT(canvas.height), raw.baseAddress, &info, DIB_RGB_COLORS)
        }
        let screenSize = SIZE(cx: INT32(canvas.width), cy: INT32(canvas.height))
        let zero = POINT(x: 0, y: 0)
        var blend = BLENDFUNCTION()
        blend.BlendOp = BYTE(AC_SRC_OVER)
        blend.SourceConstantAlpha = 255
        UpdateLayeredWindow(hwnd, nil, nil, &screenSize, memory, &zero, COLORREF(0), &blend, UINT(ULW_ALPHA))
        _ = oldBitmap
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
            Sleep(1)
        }
    }
}
#endif
