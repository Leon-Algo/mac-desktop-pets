import Foundation

/// 纯 Swift PNG 编码器（无平台依赖，双端可编译可测试）。
///
/// 只支持 8-bit RGBA 非隔行 PNG（本工程头像管线的唯一输出格式）。
/// deflate 用 stored（无压缩）块：实现最短、确定性最强；512×512 头像
/// 约 1 MB，落盘体积可接受（导入图随即被 WIC/NSImage 解码回像素使用）。
///
/// 结构：PNG signature + IHDR + IDAT(zlib) + IEND。
/// zlib = 0x78 0x01 + stored deflate 块 + adler32。
/// 每条扫描行前置 filter byte 0（None）。
enum PNGEncoder {
    /// CRC-32（IEEE 802.3，反射多项式 0xEDB88320），PNG chunk 校验用。
    private static let crcTable: [UInt32] = {
        (0..<256).map { n -> UInt32 in
            var c = UInt32(n)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1
            }
            return c
        }
    }()

    private static func crc32(_ data: [UInt8], seed: UInt32 = 0xFFFF_FFFF) -> UInt32 {
        var c = seed
        for byte in data {
            c = crcTable[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
        }
        return c ^ 0xFFFF_FFFF
    }

    private static func adler32(_ data: [UInt8]) -> UInt32 {
        var a: UInt32 = 1
        var b: UInt32 = 0
        for byte in data {
            a = (a + UInt32(byte)) % 65_521
            b = (b + a) % 65_521
        }
        return (b << 16) | a
    }

    /// BGRA（行序自上而下）→ 8-bit RGBA 非隔行 PNG。
    /// 输入非法（尺寸/缓冲不匹配/超上限）返回 nil。
    static func encode(bgra: [UInt8], width: Int, height: Int) -> Data? {
        guard width > 0, height > 0, width <= Int(UInt32.max), height <= Int(UInt32.max),
              width * height <= 8000 * 8000,
              bgra.count == width * height * 4 else { return nil }

        // 过滤后的原始扫描线：每行 1 字节 filter(0) + RGBA 像素。
        var raw = [UInt8]()
        raw.reserveCapacity(height * (1 + width * 4))
        for y in 0..<height {
            raw.append(0)  // filter type: None
            let rowBase = y * width * 4
            var x = 0
            while x < width * 4 {
                // BGRA → RGBA
                raw.append(bgra[rowBase + x + 2])
                raw.append(bgra[rowBase + x + 1])
                raw.append(bgra[rowBase + x])
                raw.append(bgra[rowBase + x + 3])
                x += 4
            }
        }

        // zlib 封装（stored deflate）。
        var zlib = [UInt8]()
        zlib.append(0x78)  // CM=8, CINFO=7
        zlib.append(0x01)  // FLEVEL=0, fastest; FDICT=0
        var offset = 0
        while offset < raw.count {
            let chunkSize = min(65_535, raw.count - offset)
            let isFinal = offset + chunkSize >= raw.count
            zlib.append(isFinal ? 1 : 0)  // BFINAL, BTYPE=00 (stored)
            zlib.append(UInt8(chunkSize & 0xFF))
            zlib.append(UInt8((chunkSize >> 8) & 0xFF))
            let nlen = ~UInt16(chunkSize)
            zlib.append(UInt8(nlen & 0xFF))
            zlib.append(UInt8((nlen >> 8) & 0xFF))
            zlib.append(contentsOf: raw[offset..<(offset + chunkSize)])
            offset += chunkSize
        }
        let adler = adler32(raw)
        zlib.append(UInt8((adler >> 24) & 0xFF))
        zlib.append(UInt8((adler >> 16) & 0xFF))
        zlib.append(UInt8((adler >> 8) & 0xFF))
        zlib.append(UInt8(adler & 0xFF))

        // 组装 PNG。
        var png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        png.append(contentsOf: chunk(.IHDR, ihdrPayload(width: width, height: height)))
        png.append(contentsOf: chunk(.IDAT, zlib))
        png.append(contentsOf: chunk(.IEND, []))
        return Data(png)
    }

    private enum ChunkType {
        case IHDR, IDAT, IEND
        var bytes: [UInt8] {
            switch self {
            case .IHDR: return [0x49, 0x48, 0x44, 0x52]
            case .IDAT: return [0x49, 0x44, 0x41, 0x54]
            case .IEND: return [0x49, 0x45, 0x4E, 0x44]
            }
        }
    }

    private static func ihdrPayload(width: Int, height: Int) -> [UInt8] {
        var payload = [UInt8]()
        func appendBE32(_ value: Int) {
            payload.append(UInt8((value >> 24) & 0xFF))
            payload.append(UInt8((value >> 16) & 0xFF))
            payload.append(UInt8((value >> 8) & 0xFF))
            payload.append(UInt8(value & 0xFF))
        }
        appendBE32(width)
        appendBE32(height)
        payload.append(8)   // bit depth
        payload.append(6)   // color type: RGBA
        payload.append(0)   // compression: deflate
        payload.append(0)   // filter: adaptive (per-row byte)
        payload.append(0)   // interlace: none
        return payload
    }

    private static func chunk(_ type: ChunkType, _ payload: [UInt8]) -> [UInt8] {
        var out = [UInt8]()
        let length = UInt32(payload.count)
        out.append(UInt8((length >> 24) & 0xFF))
        out.append(UInt8((length >> 16) & 0xFF))
        out.append(UInt8((length >> 8) & 0xFF))
        out.append(UInt8(length & 0xFF))
        out.append(contentsOf: type.bytes)
        out.append(contentsOf: payload)
        let crc = crc32(Array(type.bytes) + payload)
        out.append(UInt8((crc >> 24) & 0xFF))
        out.append(UInt8((crc >> 16) & 0xFF))
        out.append(UInt8((crc >> 8) & 0xFF))
        out.append(UInt8(crc & 0xFF))
        return out
    }
}
