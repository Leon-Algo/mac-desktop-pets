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

    /// 编码为 PNG 字节（Windows 用 WIC 编码器；非 Windows 桩返回原始字节，
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

/// WIC（Windows Imaging Component）封装：解码任意格式图像 → BGRA，
/// 以及 BGRA → PNG 编码。COM 以局部初始化 + 手动 Release 管理，
/// 全部调用发生在启动/导入的单线程上下文。
enum WICSupport {
    /// CLSID_WICImagingFactory {cacaf262-9370-4615-a13b-9f5539dae4c4}
    static let imagingFactoryCLSID = CLSID(
        Data1: 0xcacaf262, Data2: 0x9370, Data3: 0x4615,
        Data4: (0xa1, 0x3b, 0x9f, 0x55, 0x39, 0xda, 0xe4, 0xc4)
    )
    /// GUID_WICPixelFormat32bppBGRA {6fddc324-4e03-4bfe-b185-3d77768dc90e}
    static let bgraPixelFormatGUID = GUID(
        Data1: 0x6fddc324, Data2: 0x4e03, Data3: 0x4bfe,
        Data4: (0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x0e)
    )
    /// GUID_ContainerFormatPng {1b7cfaf4-713f-473c-bbcd-6137425faeaf}
    static let pngContainerGUID = GUID(
        Data1: 0x1b7cfaf4, Data2: 0x713f, Data3: 0x473c,
        Data4: (0xbb, 0xcd, 0x61, 0x37, 0x42, 0x5f, 0xae, 0xaf)
    )

    /// 解码图像字节（PNG/JPEG/BMP/GIF 首帧）为 BGRA 像素缓冲。
    static func decodeBGRA(data: Data) -> (pixels: [UInt8], width: Int, height: Int)? {
        guard data.count <= AvatarNormalizer.maxSourceBytes else { return nil }
        guard let factory = createFactory() else { return nil }
        defer { factory.Release() }

        // 内存流。
        var stream: IStream? = nil
        guard SUCCEEDED(CreateStreamOnHGlobal(nil, BOOL(true), &stream)), let stream else { return nil }
        defer { stream.Release() }
        let ok = data.withUnsafeBytes { raw -> HRESULT in
            guard let base = raw.baseAddress else { return E_FAIL }
            var written: ULONG = 0
            return stream.Write(base, UINT32(raw.count), &written)
        }
        guard SUCCEEDED(ok) else { return nil }

        guard let decoder = tryQuery(factory, { p in
            factory.CreateDecoderFromStream(OpaquePointer(stream), nil, UINT(WICDecodeMetadataCacheOnDemand), p)
        }) else { return nil }
        defer { decoder.Release() }

        var frame: IWICBitmapFrameDecode? = nil
        guard SUCCEEDED(decoder.GetFrame(0, &frame)), let bitmapFrame else { return nil }
        defer { bitmapFrame.Release() }

        var width: UINT = 0
        var height: UINT = 0
        guard SUCCEEDED(bitmapFrame.GetSize(&width)), SUCCEEDED(bitmapFrame.GetSize2(&height)),
              width > 0, height > 0 else { return nil }
        guard Int(width) * Int(height) <= AvatarNormalizer.maxSourcePixels else { return nil }

        guard let converter = tryQuery(factory, { p in
            factory.CreateFormatConverter(p)
        }) else { return nil }
        defer { converter.Release() }
        guard SUCCEEDED(converter.Initialize(
            OpaquePointer(bitmapFrame), bgraPixelFormatGUID,
            UINT(WICBitmapDitherTypeNone), nil, 0, UINT(WICBitmapPaletteTypeCustom)
        )) else { return nil }

        var pixels = [UInt8](repeating: 0, count: Int(width) * Int(height) * 4)
        let stride = Int(width) * 4
        let result = pixels.withUnsafeMutableBytes { raw -> HRESULT in
            guard let base = raw.baseAddress else { return E_FAIL }
            return converter.CopyPixels(nil, UINT32(stride), UINT32(raw.count), base)
        }
        guard SUCCEEDED(result) else { return nil }
        return (pixels, Int(width), Int(height))
    }

    /// BGRA 像素编码为 PNG 字节。
    static func encodePNG(bgra: [UInt8], width: Int, height: Int) -> Data? {
        guard width > 0, height > 0, bgra.count == width * height * 4 else { return nil }
        guard let factory = createFactory() else { return nil }
        defer { factory.Release() }

        var bitmap: IWICBitmap? = nil
        guard SUCCEEDED(factory.CreateBitmapFromMemory(
            UINT32(width), UINT32(height), bgraPixelFormatGUID,
            UINT32(width * 4), UInt32(bgra.count), bgra, &bitmap
        )), let bitmap else { return nil }
        defer { bitmap.Release() }

        var stream: IWICStream? = nil
        guard let created = tryQuery(factory, { p in factory.CreateStream(p) }) else { return nil }
        stream = unsafeDownCast(created, to: IWICStream.self)
        defer { stream?.Release() }
        guard SUCCEEDED(stream!.InitializeAsInMemory()) else { return nil }

        var encoder: IWICBitmapEncoder? = nil
        guard SUCCEEDED(factory.CreateEncoder(pngContainerGUID, nil, &encoder)), let encoder else { return nil }
        defer { encoder.Release() }
        guard SUCCEEDED(encoder.Initialize(OpaquePointer(stream!), UINT(WICBitmapEncoderNoCache))) else { return nil }

        var frame: IWICBitmapFrameEncode? = nil
        var props: IPropertyBag2? = nil
        guard SUCCEEDED(encoder.CreateNewFrame(&frame, &props)), let frameEncode = frame else { return nil }
        defer { frameEncode.Release() }
        props?.Release()
        guard SUCCEEDED(frameEncode.Initialize(nil)) else { return nil }
        guard SUCCEEDED(frameEncode.SetSize(UINT32(width), UINT32(height))) else { return nil }
        let stride = width * 4
        let result = bgra.withUnsafeBytes { raw -> HRESULT in
            guard let base = raw.baseAddress else { return E_FAIL }
            return frameEncode.WritePixels(UINT32(height), UINT32(stride), UINT32(raw.count), base)
        }
        guard SUCCEEDED(result) else { return nil }
        guard SUCCEEDED(frameEncode.Commit()) else { return nil }
        guard SUCCEEDED(encoder.Commit()) else { return nil }

        // 从 IStream 读回全部字节。
        var stat = STATSTG()
        guard SUCCEEDED(stream!.Stat(&stat, UINT(STATFLAG_NONAME))), stat.cbSize.QuadPart > 0 else { return nil }
        let size = Int(stat.cbSize.QuadPart)
        var data = Data(count: size)
        var read: ULONG = 0
        let readOK = data.withUnsafeMutableBytes { raw -> HRESULT in
            guard let base = raw.baseAddress else { return E_FAIL }
            return stream!.Read(base, UINT32(size), &read)
        }
        guard SUCCEEDED(readOK), read > 0 else { return nil }
        return data.prefix(Int(read))
    }

    // MARK: - COM 基础设施

    private static func createFactory() -> IWICImagingFactory? {
        var factory: IWICImagingFactory? = nil
        let status = CoCreateInstance(
            imagingFactoryCLSID, nil, DWORD(CLSCTX_INPROC_SERVER),
            &IID_IWICImagingFactory, &factory
        )
        guard status == S_OK, let factory else { return nil }
        return factory
    }

    /// QueryInterface + CoCreateInstance 输出参数模式收敛。
    private static func tryQuery<T>(_ factory: IWICImagingFactory, _ create: (UnsafeMutablePointer<T?>) -> HRESULT) -> T? {
        var output: T? = nil
        guard SUCCEEDED(create(&output)), let value = output else { return nil }
        return value
    }
}
#endif
