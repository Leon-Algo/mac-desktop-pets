import Foundation
import DesktopPetsCore

/// 头像归一化纯逻辑（跨平台可测）：
/// 任意源图像（已解码为 BGRA 像素缓冲）→ 居中方裁剪 → 最近邻缩放到 512×512 BGRA。
/// 与 macOS AvatarImageProcessor 的裁剪语义一致（居中裁最短边、zoom/offset 不做，
/// Windows 版交互从简）；字节/像素上限与 macOS 相同，防解码炸弹。
///
/// 平台差异边界：解码（PNG/JPEG → BGRA）由平台壳完成（Windows WIC / macOS NSImage），
/// 本文件只做确定性像素运算，双端可编译可测试。
enum AvatarNormalizer {
    static let pixelSize = 512
    /// 源文件字节上限（约 25 MB），与 macOS AvatarImageProcessor 一致。
    static let maxSourceBytes = 25 * 1024 * 1024
    /// 源图像像素上限（宽×高），与 macOS 一致。
    static let maxSourcePixels = 8000 * 8000

    enum NormalizeError: Error, Equatable {
        case sourceTooLarge
        case sourceExceedsPixelLimit
        case invalidDimensions
    }

    /// 归一化：输入 BGRA（行序自上而下）→ 输出 512×512 BGRA。
    /// 裁剪：取 min(w,h) 为边、源中心对齐（偶数差偏左/上，与整数除法语义一致）。
    static func normalizedBGRA(
        pixels: [UInt8], width: Int, height: Int
    ) throws -> (pixels: [UInt8], width: Int, height: Int) {
        guard width > 0, height > 0 else { throw NormalizeError.invalidDimensions }
        guard pixels.count == width * height * 4 else { throw NormalizeError.invalidDimensions }
        guard width * height <= maxSourcePixels else { throw NormalizeError.sourceExceedsPixelLimit }

        let side = min(width, height)
        let cropX = (width - side) / 2
        let cropY = (height - side) / 2

        var output = [UInt8](repeating: 0, count: pixelSize * pixelSize * 4)
        let scaleX = Double(side) / Double(pixelSize)
        for oy in 0..<pixelSize {
            // 最近邻采样：目标像素中心映射回源。
            let sy = cropY + min(side - 1, Int((Double(oy) + 0.5) * scaleX))
            let rowBase = (sy * width + cropX) * 4
            let outRow = oy * pixelSize * 4
            for ox in 0..<pixelSize {
                let sx = min(side - 1, Int((Double(ox) + 0.5) * scaleX))
                let src = rowBase + sx * 4
                let dst = outRow + ox * 4
                output[dst] = pixels[src]
                output[dst + 1] = pixels[src + 1]
                output[dst + 2] = pixels[src + 2]
                output[dst + 3] = pixels[src + 3]
            }
        }
        return (output, pixelSize, pixelSize)
    }

    /// 编码为 PNG 字节（Windows 用 WIC 编码器；非 Windows 桩返回 nil，
    /// 桩路径仅用于纯逻辑单测，不落盘）。
    static func encodePNG(bgra: [UInt8], width: Int, height: Int) -> Data? {
        #if os(Windows)
        return WICSupport.encodePNG(bgra: bgra, width: width, height: height)
        #else
        _ = bgra
        _ = width
        _ = height
        return nil
        #endif
    }
}

#if os(Windows)
import WinSDK

// MARK: - WIC 手写 COM vtable 绑定
//
// swift-win-sdk 的 C importer 只导入 wincodec.h 的 C 表面：接口类型名
// （IWICImagingFactory 等）以不透明结构存在，C++ 虚方法不导入，也没有
// SUCCEEDED/E_FAIL 宏。因此按 swift.org 官方博客《Swift Everywhere: Windows
// Interop》展示的 IUnknownVtbl 模式手写绑定：
//
// - vtable 结构体字段顺序 = 头文件方法声明顺序（C++ 单继承布局：基类方法在前）。
//   同模块 fragile struct 按声明序布局，指针各 8 字节无对齐空洞。
//   槽位错位不会在编译期暴露、会直接造成运行期内存错乱，因此每条实际调用的
//   方法都对照 wincodec.h / MSDN 方法顺序逐一核对，并由 --self-test 的
//   WIC PNG 编解码往返在 CI Windows 真机上执行验证（错位会当场崩溃或报错）。
// - 只声明到最后一个被调用槽位的前缀；未调用的中间槽位用指针尺寸占位
//   （不解引用，ABI 上只需 8 字节对齐），把签名书写错误面降到最小。
// - COM 对象以裸指针 + RAII（ComObject.deinit 调 Release）管理，
//   异常路径不泄漏；全程在主线程单线程上下文使用。

/// 未调用槽位占位：与真实方法同为 8 字节函数指针，永不解引用。
private typealias UnusedComSlot = @convention(c) (UnsafeMutableRawPointer?) -> HRESULT

/// SUCCEEDED 宏等价：COM HRESULT 失败 = 负值（高位为 1）。
private func comOK(_ hr: HRESULT) -> Bool { hr >= 0 }
/// E_FAIL（0x80004005 不适配 Int32 字面量，按位模式构造）。
private let comEFail: HRESULT = Int32(bitPattern: 0x8000_4005)

private struct IUnknownVtbl {
    var QueryInterface: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
    var AddRef: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Release: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
}

/// IWICImagingFactory 前缀（槽位 0–9）。实际调用：
/// CreateDecoderFromStream(4)、CreateEncoder(8)、CreateFormatConverter(9)。
private struct IWICImagingFactoryVtbl {
    var QueryInterface: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
    var AddRef: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Release: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var CreateDecoderFromFilename: UnusedComSlot
    var CreateDecoderFromStream: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeRawPointer?, UINT, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
    var CreateDecoderFromFileHandle: UnusedComSlot
    var CreateComponentInfo: UnusedComSlot
    var CreateDecoder: UnusedComSlot
    var CreateEncoder: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
    var CreateFormatConverter: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
}

/// IStream 前缀（槽位 0–12，ISequentialStream 在前）。实际调用：
/// Read(3)、Write(4)、Stat(12)。
private struct IStreamVtbl {
    var QueryInterface: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
    var AddRef: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Release: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Read: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, ULONG, UnsafeMutablePointer<ULONG>?) -> HRESULT
    var Write: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, ULONG, UnsafeMutablePointer<ULONG>?) -> HRESULT
    var Seek: UnusedComSlot
    var SetSize: UnusedComSlot
    var CopyTo: UnusedComSlot
    var Commit: UnusedComSlot
    var Revert: UnusedComSlot
    var LockRegion: UnusedComSlot
    var UnlockRegion: UnusedComSlot
    var Stat: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<STATSTG>?, UINT) -> HRESULT
}

/// IWICBitmapDecoder 前缀（槽位 0–13）。实际调用：GetFrame(13)。
private struct IWICBitmapDecoderVtbl {
    var QueryInterface: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
    var AddRef: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Release: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var QueryCapability: UnusedComSlot
    var Initialize: UnusedComSlot
    var GetContainerFormat: UnusedComSlot
    var GetDecoderInfo: UnusedComSlot
    var CopyPalette: UnusedComSlot
    var GetMetadataQueryReader: UnusedComSlot
    var GetPreview: UnusedComSlot
    var GetColorContexts: UnusedComSlot
    var GetThumbnail: UnusedComSlot
    var GetFrameCount: UnusedComSlot
    var GetFrame: @convention(c) (UnsafeMutableRawPointer?, UINT, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
}

/// IWICBitmapFrameDecode（基类 IWICBitmapSource 的 5 方法在前，槽位 0–10）。
/// 实际调用：GetSize(3)、CopyPixels(7)。
private struct IWICBitmapFrameDecodeVtbl {
    var QueryInterface: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
    var AddRef: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Release: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var GetSize: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UINT>?, UnsafeMutablePointer<UINT>?) -> HRESULT
    var GetPixelFormat: UnusedComSlot
    var GetResolution: UnusedComSlot
    var CopyPalette: UnusedComSlot
    var CopyPixels: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UINT, UINT32, UnsafeMutableRawPointer?) -> HRESULT
    var GetMetadataQueryReader: UnusedComSlot
    var GetColorContexts: UnusedComSlot
    var GetThumbnail: UnusedComSlot
}

/// IWICFormatConverter（基类 IWICBitmapSource 在前，槽位 0–9）。
/// 实际调用：CopyPixels(7)、Initialize(8)。
private struct IWICFormatConverterVtbl {
    var QueryInterface: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
    var AddRef: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Release: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var GetSize: UnusedComSlot
    var GetPixelFormat: UnusedComSlot
    var GetResolution: UnusedComSlot
    var CopyPalette: UnusedComSlot
    var CopyPixels: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UINT, UINT32, UnsafeMutableRawPointer?) -> HRESULT
    var Initialize: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeRawPointer?, UINT, UnsafeRawPointer?, Double, UINT) -> HRESULT
    var CanConvert: UnusedComSlot
}

/// IWICBitmapEncoder 前缀（槽位 0–10）。实际调用：Initialize(3)、CreateNewFrame(10)。
private struct IWICBitmapEncoderVtbl {
    var QueryInterface: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
    var AddRef: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Release: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Initialize: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UINT) -> HRESULT
    var GetContainerFormat: UnusedComSlot
    var GetEncoderInfo: UnusedComSlot
    var SetColorContexts: UnusedComSlot
    var SetPalette: UnusedComSlot
    var SetThumbnail: UnusedComSlot
    var SetPreview: UnusedComSlot
    var CreateNewFrame: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
}

/// IWICBitmapFrameEncode 前缀（槽位 0–14）。实际调用：
/// Initialize(3)、SetSize(4)、SetPixelFormat(6)、WritePixels(10)、Commit(14)。
private struct IWICBitmapFrameEncodeVtbl {
    var QueryInterface: @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> HRESULT
    var AddRef: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Release: @convention(c) (UnsafeMutableRawPointer?) -> ULONG
    var Initialize: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> HRESULT
    var SetSize: @convention(c) (UnsafeMutableRawPointer?, UINT32, UINT32) -> HRESULT
    var SetResolution: UnusedComSlot
    var SetPixelFormat: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<GUID>?) -> HRESULT
    var SetColorContexts: UnusedComSlot
    var SetPalette: UnusedComSlot
    var SetThumbnail: UnusedComSlot
    var WritePixels: @convention(c) (UnsafeMutableRawPointer?, UINT, UINT32, UINT32, UnsafeMutableRawPointer?) -> HRESULT
    var WriteSource: UnusedComSlot
    var WriteMetadata: UnusedComSlot
    var SetMetadata: UnusedComSlot
    var Commit: @convention(c) (UnsafeMutableRawPointer?) -> HRESULT
}

/// 极简 COM 对象包装：持有裸指针，deinit 统一 Release（RAII，异常路径不泄漏）。
/// vtable 经对象首字段（C++ vptr）重绑定到对应槽位结构体后按字段调用。
private final class ComObject {
    let raw: UnsafeMutableRawPointer

    init(_ raw: UnsafeMutableRawPointer) { self.raw = raw }
    deinit { _ = vtbl(IUnknownVtbl.self).pointee.Release(raw) }

    func vtbl<T>(_ type: T.Type) -> UnsafeMutablePointer<T> {
        raw.load(as: UnsafeMutableRawPointer.self).assumingMemoryBound(to: T.self)
    }
}

// MARK: - 各接口包装（仅暴露用到的调用）

extension ComObject {
    fileprivate var factory: UnsafeMutablePointer<IWICImagingFactoryVtbl> {
        vtbl(IWICImagingFactoryVtbl.self)
    }

    func createDecoderFromStream(_ stream: ComObject, metadataOptions: UINT) -> ComObject? {
        var out: UnsafeMutableRawPointer? = nil
        let hr = factory.pointee.CreateDecoderFromStream(raw, stream.raw, nil, metadataOptions, &out)
        guard comOK(hr), let p = out else { return nil }
        return ComObject(p)
    }

    func createEncoder(containerFormat: GUID) -> ComObject? {
        var out: UnsafeMutableRawPointer? = nil
        let hr = withUnsafePointer(to: containerFormat) { fmt in
            factory.pointee.CreateEncoder(raw, UnsafeRawPointer(fmt), nil, &out)
        }
        guard comOK(hr), let p = out else { return nil }
        return ComObject(p)
    }

    func createFormatConverter() -> ComObject? {
        var out: UnsafeMutableRawPointer? = nil
        let hr = factory.pointee.CreateFormatConverter(raw, &out)
        guard comOK(hr), let p = out else { return nil }
        return ComObject(p)
    }
}

extension ComObject {
    fileprivate var stream: UnsafeMutablePointer<IStreamVtbl> { vtbl(IStreamVtbl.self) }

    func write(_ bytes: Data) -> Bool {
        let hr = bytes.withUnsafeBytes { buffer -> HRESULT in
            guard let base = buffer.baseAddress else { return comEFail }
            var written: ULONG = 0
            return stream.pointee.Write(raw, base, ULONG(buffer.count), &written)
        }
        return comOK(hr)
    }

    func streamSize() -> Int {
        var stat = STATSTG()
        // STATFLAG_NONAME = 0x1（固定常量，避免依赖 SDK 符号导入形态）。
        guard comOK(stream.pointee.Stat(raw, &stat, UINT(1))) else { return 0 }
        return stat.cbSize.QuadPart > 0 ? Int(stat.cbSize.QuadPart) : 0
    }

    func readAll(_ count: Int) -> Data? {
        guard count > 0 else { return nil }
        var data = Data(count: count)
        var got: ULONG = 0
        let hr = data.withUnsafeMutableBytes { buffer -> HRESULT in
            guard let base = buffer.baseAddress else { return comEFail }
            return stream.pointee.Read(raw, base, ULONG(count), &got)
        }
        guard comOK(hr), got > 0 else { return nil }
        return data.prefix(Int(got))
    }
}

extension ComObject {
    fileprivate func frame(at index: UINT) -> ComObject? {
        var out: UnsafeMutableRawPointer? = nil
        let hr = vtbl(IWICBitmapDecoderVtbl.self).pointee.GetFrame(raw, index, &out)
        guard comOK(hr), let p = out else { return nil }
        return ComObject(p)
    }
}

extension ComObject {
    fileprivate func getSize() -> (width: UINT, height: UINT)? {
        var width: UINT = 0
        var height: UINT = 0
        let hr = vtbl(IWICBitmapFrameDecodeVtbl.self).pointee.GetSize(raw, &width, &height)
        guard comOK(hr), width > 0, height > 0 else { return nil }
        return (width, height)
    }

    /// prc 传 nil = 全图拷贝。
    fileprivate func copyPixels(stride: UINT32, bufferSize: UINT32, buffer: UnsafeMutableRawPointer) -> HRESULT {
        vtbl(IWICBitmapFrameDecodeVtbl.self).pointee.CopyPixels(raw, nil, stride, bufferSize, buffer)
    }
}

extension ComObject {
    fileprivate func initializeToBGRA(from source: ComObject, pixelFormat: GUID) -> Bool {
        let hr = withUnsafePointer(to: pixelFormat) { fmt in
            vtbl(IWICFormatConverterVtbl.self).pointee.Initialize(
                raw, source.raw, UnsafeRawPointer(fmt),
                UINT(WICBitmapDitherTypeNone.rawValue), nil, 0.0,
                UINT(WICBitmapPaletteTypeCustom.rawValue)
            )
        }
        return comOK(hr)
    }

    /// 解码帧像素到 BGRA（强制经 FormatConverter，不依赖源格式）。
    fileprivate func copyPixelsAsBGRA(width: UINT, height: UINT) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: Int(width) * Int(height) * 4)
        let stride = Int(width) * 4
        let hr = pixels.withUnsafeMutableBytes { raw -> HRESULT in
            guard let base = raw.baseAddress else { return comEFail }
            return copyPixels(stride: UINT32(stride), bufferSize: UINT32(raw.count), buffer: base)
        }
        return comOK(hr) ? pixels : nil
    }
}

extension ComObject {
    fileprivate func initialize(stream: ComObject, cacheOption: UINT) -> Bool {
        comOK(vtbl(IWICBitmapEncoderVtbl.self).pointee.Initialize(raw, stream.raw, cacheOption))
    }

    func createNewFrame() -> ComObject? {
        var out: UnsafeMutableRawPointer? = nil
        // 属性袋（编码器选项）传 nil：WIC 文档允许，免去 IPropertyBag2 绑定。
        let hr = vtbl(IWICBitmapEncoderVtbl.self).pointee.CreateNewFrame(raw, &out, nil)
        guard comOK(hr), let p = out else { return nil }
        return ComObject(p)
    }
}

extension ComObject {
    fileprivate func initialize() -> Bool {
        comOK(vtbl(IWICBitmapFrameEncodeVtbl.self).pointee.Initialize(raw, nil))
    }

    func setSize(width: UINT32, height: UINT32) -> Bool {
        comOK(vtbl(IWICBitmapFrameEncodeVtbl.self).pointee.SetSize(raw, width, height))
    }

    func setPixelFormat(_ desired: GUID) -> Bool {
        var actual = desired
        guard comOK(vtbl(IWICBitmapFrameEncodeVtbl.self).pointee.SetPixelFormat(raw, &actual)) else {
            return false
        }
        // SetPixelFormat 回写「最接近的受支持格式」；编码器必须确实落在 32bppBGRA，
        // 否则后续 WritePixels 的缓冲布局假设不成立。逐字段比较（GUID 无 == 约定）。
        return actual.Data1 == desired.Data1 && actual.Data2 == desired.Data2
            && actual.Data3 == desired.Data3 && actual.Data4.0 == desired.Data4.0
            && actual.Data4.1 == desired.Data4.1 && actual.Data4.2 == desired.Data4.2
            && actual.Data4.3 == desired.Data4.3 && actual.Data4.4 == desired.Data4.4
            && actual.Data4.5 == desired.Data4.5 && actual.Data4.6 == desired.Data4.6
            && actual.Data4.7 == desired.Data4.7
    }

    /// 诊断用：原始 HRESULT 版本（不经 Bool 收敛）。
    fileprivate func rawSetPixelFormat(_ format: inout GUID) -> HRESULT {
        vtbl(IWICBitmapFrameEncodeVtbl.self).pointee.SetPixelFormat(raw, &format)
    }

    func writePixels(lineCount: UINT, stride: UINT32, bufferSize: UINT32, buffer: UnsafeMutableRawPointer) -> HRESULT {
        vtbl(IWICBitmapFrameEncodeVtbl.self).pointee.WritePixels(raw, lineCount, stride, bufferSize, buffer)
    }

    func commit() -> Bool {
        comOK(vtbl(IWICBitmapFrameEncodeVtbl.self).pointee.Commit(raw))
    }
}

// MARK: - GUID 常量（let 全局，传参时经 withUnsafePointer 取址）

/// CLSID_WICImagingFactory1 {cacaf262-9370-4615-a13b-9f5539da4c0a}
/// （经典工厂 CLSID，Vista 起始终注册；Win8+ 头文件宏 CLSID_WICImagingFactory
///  指向 Factory2 {317d06e8-5f24-433d-bdf7-79ce68d8abc2}，两者实现同一接口可互换）
private let wicFactoryCLSID = GUID(
    Data1: 0xcacaf262, Data2: 0x9370, Data3: 0x4615,
    Data4: (0xa1, 0x3b, 0x9f, 0x55, 0x39, 0xda, 0x4c, 0x0a)
)
/// IID_IWICImagingFactory —— 复制 SDK 导出的 let 全局（全局 let 不能直接取址）。
private let wicFactoryIID = IID_IWICImagingFactory
/// GUID_WICPixelFormat32bppBGRA {6fddc324-4e03-4bfe-b185-3d77768dc90e}
private let wicBGRAFormatGUID = GUID(
    Data1: 0x6fddc324, Data2: 0x4e03, Data3: 0x4bfe,
    Data4: (0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x0e)
)
/// GUID_ContainerFormatPng {1b7cfaf4-713f-473c-bbcd-6137425faeaf}
private let wicPNGContainerGUID = GUID(
    Data1: 0x1b7cfaf4, Data2: 0x713f, Data3: 0x473c,
    Data4: (0xbb, 0xcd, 0x61, 0x37, 0x42, 0x5f, 0xae, 0xaf)
)

/// WIC（Windows Imaging Component）封装：解码任意格式图像 → BGRA，
/// 以及 BGRA → PNG 编码。COM 以局部初始化 + RAII Release 管理，
/// 全部调用发生在启动/导入的单线程上下文。
enum WICSupport {
    /// 解码图像字节（PNG/JPEG/BMP/GIF 首帧）为 BGRA 像素缓冲。
    static func decodeBGRA(data: Data) -> (pixels: [UInt8], width: Int, height: Int)? {
        guard data.count <= AvatarNormalizer.maxSourceBytes else { return nil }
        guard let factory = createFactory(),
              let stream = memoryStream(containing: data),
              let decoder = factory.createDecoderFromStream(
                  stream, metadataOptions: UINT(WICDecodeMetadataCacheOnDemand.rawValue)),
              let decodedFrame = decoder.frame(at: 0),
              let (width, height) = decodedFrame.getSize(),
              Int(width) * Int(height) <= AvatarNormalizer.maxSourcePixels,
              let converter = factory.createFormatConverter(),
              converter.initializeToBGRA(from: decodedFrame, pixelFormat: wicBGRAFormatGUID),
              // 拷贝走 converter（源是已转换的 32bppBGRA 位图）。
              let pixels = converter.copyPixelsAsBGRA(width: width, height: height) else {
            return nil
        }
        return (pixels, Int(width), Int(height))
    }

    /// BGRA 像素编码为 PNG 字节。帧像素格式显式锁定 32bppBGRA。
    static func encodePNG(bgra: [UInt8], width: Int, height: Int) -> Data? {
        guard width > 0, height > 0,
              width * height <= AvatarNormalizer.maxSourcePixels,
              bgra.count == width * height * 4 else { return nil }
        guard let factory = createFactory(),
              let stream = memoryStream(),
              let encoder = factory.createEncoder(containerFormat: wicPNGContainerGUID),
              encoder.initialize(stream: stream, cacheOption: UINT(WICBitmapEncoderNoCache.rawValue)),
              let frame = encoder.createNewFrame(),
              frame.initialize(),
              frame.setSize(width: UINT32(width), height: UINT32(height)),
              frame.setPixelFormat(wicBGRAFormatGUID) else {
            return nil
        }
        let stride = width * 4
        let hr = bgra.withUnsafeBytes { raw -> HRESULT in
            guard let base = raw.baseAddress else { return comEFail }
            return frame.writePixels(
                lineCount: UINT(height), stride: UINT32(stride),
                bufferSize: UINT32(raw.count), buffer: UnsafeMutableRawPointer(mutating: base)
            )
        }
        guard comOK(hr), frame.commit(), encoder.commit() else { return nil }
        return stream.readAll(stream.streamSize())
    }

    /// CI 自检：合成 8×8 渐变 → PNG 编码 → 解码 → 逐像素核对。
    /// PNG 无损，BGRA 32bpp 全程直通，解码结果必须逐字节一致。
    /// 这是手写 COM vtable 绑定的运行期正确性验证（槽位错位/GUID 错误在此暴露）。
    static func roundTripSelfTest() -> Bool {
        var trace: [String] = []
        let ok = roundTripSelfTest(trace: &trace)
        for line in trace { print("  WIC: \(line)") }
        return ok
    }

    /// 带步骤追踪的版本：CI 日志可定位首个失败环节。
    static func roundTripSelfTest(trace: inout [String]) -> Bool {
        let side = 8
        var bgra = [UInt8](repeating: 0, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                let i = (y * side + x) * 4
                bgra[i] = UInt8(truncatingIfNeeded: x * 30)
                bgra[i + 1] = UInt8(truncatingIfNeeded: y * 30)
                bgra[i + 2] = 0x40
                bgra[i + 3] = 255
            }
        }
        // createFactory 诊断：直接展开 CoInitializeEx + CoCreateInstance 看 HRESULT。
        _ = CoInitializeEx(nil, UINT(0x2))
        do {
            var probeClsid = wicFactoryCLSID
            var probeIid = wicFactoryIID
            var probeOut: UnsafeMutableRawPointer? = nil
            let probeHr = CoCreateInstance(&probeClsid, nil, DWORD(CLSCTX_INPROC_SERVER.rawValue), &probeIid, &probeOut)
            trace.append("diag CoInitializeEx+CoCreateInstance hr=0x\(String(UInt32(bitPattern: probeHr), radix: 16)) out=\(probeOut != nil)")
            if let p = probeOut { _ = ComObject(p) }
        }
        guard let factory = createFactory() else {
            trace.append("FAIL createFactory")
            return false
        }
        trace.append("ok createFactory")
        guard let stream = memoryStream() else {
            trace.append("FAIL memoryStream")
            return false
        }
        guard let encoder = factory.createEncoder(containerFormat: wicPNGContainerGUID) else {
            trace.append("FAIL createEncoder")
            return false
        }
        trace.append("ok createEncoder")
        guard encoder.initialize(stream: stream, cacheOption: UINT(WICBitmapEncoderNoCache.rawValue)) else {
            trace.append("FAIL encoder.initialize")
            return false
        }
        guard let frame = encoder.createNewFrame() else {
            trace.append("FAIL createNewFrame")
            return false
        }
        trace.append("ok createNewFrame")
        guard frame.initialize() else {
            trace.append("FAIL frame.initialize")
            return false
        }
        guard frame.setSize(width: UINT32(side), height: UINT32(side)) else {
            trace.append("FAIL frame.setSize")
            return false
        }
        if !frame.setPixelFormat(wicBGRAFormatGUID) {
            // 诊断：区分「HRESULT 失败」与「回读格式不符」，并打印回读格式尾字节。
            var probe = wicBGRAFormatGUID
            let phr = frame.rawSetPixelFormat(&probe)
            trace.append("FAIL frame.setPixelFormat hr=0x\(String(UInt32(bitPattern: phr), radix: 16)) gotTail=\(probe.Data4.7)")
            return false
        }
        trace.append("ok frame setup (initialize/setSize/setPixelFormat)")
        let stride = side * 4
        let hr = bgra.withUnsafeBytes { raw -> HRESULT in
            guard let base = raw.baseAddress else { return comEFail }
            return frame.writePixels(
                lineCount: UINT(side), stride: UINT32(stride),
                bufferSize: UINT32(raw.count), buffer: UnsafeMutableRawPointer(mutating: base)
            )
        }
        guard comOK(hr) else {
            trace.append("FAIL writePixels hr=0x\(String(UInt32(bitPattern: hr), radix: 16))")
            return false
        }
        guard frame.commit() else {
            trace.append("FAIL frame.commit")
            return false
        }
        guard encoder.commit() else {
            trace.append("FAIL encoder.commit")
            return false
        }
        let size = stream.streamSize()
        guard size > 8, let png = stream.readAll(size) else {
            trace.append("FAIL stream readback size=\(size)")
            return false
        }
        trace.append("ok encode (\(png.count) bytes)")

        guard let decodedStream = memoryStream(containing: png) else {
            trace.append("FAIL decode memoryStream")
            return false
        }
        guard let decoder = factory.createDecoderFromStream(
            decodedStream, metadataOptions: UINT(WICDecodeMetadataCacheOnDemand.rawValue)) else {
            trace.append("FAIL createDecoderFromStream")
            return false
        }
        trace.append("ok createDecoderFromStream")
        guard let decodedFrame = decoder.frame(at: 0) else {
            trace.append("FAIL decoder.frame(0)")
            return false
        }
        guard let (w, h) = decodedFrame.getSize() else {
            trace.append("FAIL frame.getSize")
            return false
        }
        trace.append("ok frame size \(w)x\(h)")
        guard w == UINT(side), h == UINT(side) else {
            trace.append("FAIL size mismatch \(w)x\(h)")
            return false
        }
        guard let converter = factory.createFormatConverter() else {
            trace.append("FAIL createFormatConverter")
            return false
        }
        guard converter.initializeToBGRA(from: decodedFrame, pixelFormat: wicBGRAFormatGUID) else {
            trace.append("FAIL converter.initialize")
            return false
        }
        guard let pixels = converter.copyPixelsAsBGRA(width: w, height: h) else {
            trace.append("FAIL converter.copyPixels")
            return false
        }
        trace.append("ok decode + convert")
        for (x, y) in [(0, 0), (side - 1, 0), (0, side - 1), (side - 1, side - 1), (3, 5)] {
            let i = (y * side + x) * 4
            let expected = (UInt8(truncatingIfNeeded: x * 30), UInt8(truncatingIfNeeded: y * 30), UInt8(0x40), UInt8(255))
            let actual = (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
            guard actual == expected else {
                trace.append("FAIL pixel(\(x),\(y)) got \(actual) want \(expected)")
                return false
            }
        }
        return true
    }

    // MARK: - 基础设施

    private static func createFactory() -> ComObject? {
        // COM 必须先初始化：WIC 工厂是进程内 COM 组件。apartment threaded
        // 单线程模式（进程单线程消息循环，符合约定）；已初始化则幂等跳过
        // （S_FALSE 同样算成功）。COINIT_APARTMENTTHREADED = 0x2（固定常量，
        // SDK 的 tagCOINIT 枚举不能直接转 UINT）。
        _ = CoInitializeEx(nil, UINT(0x2))
        var clsid = wicFactoryCLSID
        var iid = wicFactoryIID
        var out: UnsafeMutableRawPointer? = nil
        let hr = CoCreateInstance(&clsid, nil, DWORD(CLSCTX_INPROC_SERVER.rawValue), &iid, &out)
        guard comOK(hr), let p = out else { return nil }
        return ComObject(p)
    }

    /// 进程内内存 IStream（HGLOBAL 承载）。fDeleteOnRelease = true 随对象释放。
    private static func memoryStream(containing data: Data? = nil) -> ComObject? {
        var rawStream: LPSTREAM? = nil
        let hr = CreateStreamOnHGlobal(nil, true, &rawStream)
        guard comOK(hr), let p = rawStream else { return nil }
        let stream = ComObject(UnsafeMutableRawPointer(p))
        if let data, !stream.write(data) { return nil }
        return stream
    }}
#endif
