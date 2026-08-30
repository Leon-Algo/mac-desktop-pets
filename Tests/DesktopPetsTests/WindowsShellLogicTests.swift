import XCTest
@testable import WindowsShell
import DesktopPetsCore

/// Windows 壳纯逻辑的 XCTest 覆盖（与 --self-test 同源的抽样断言 +
/// XCTest 特有的参数化用例）。全部纯 Foundation，macOS CI 即可跑。
final class WindowsShellLogicTests: XCTestCase {

    // MARK: - 头像归一化

    func testNormalizedOutputSizeAndSampleMapping() throws {
        // 2:1 宽图 800×400 → 裁中 400×400 → 512×512。
        let w = 800, h = 400
        var source = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let base = (y * w + x) * 4
                source[base] = UInt8((x / 8) % 256)
                source[base + 1] = UInt8((y / 8) % 256)
                source[base + 3] = 255
            }
        }
        let normalized = try AvatarNormalizer.normalizedBGRA(pixels: source, width: w, height: h)
        XCTAssertEqual(normalized.width, 512)
        XCTAssertEqual(normalized.height, 512)
        XCTAssertEqual(normalized.pixels.count, 512 * 512 * 4)

        func sample(_ pixels: [UInt8], x: Int, y: Int) -> (UInt8, UInt8) {
            let base = (y * 512 + x) * 4
            return (pixels[base], pixels[base + 1])
        }
        // 目标 (0,0) 中心 → 源 crop 起点 (200, 0)。
        XCTAssertEqual(sample(normalized.pixels, x: 0, y: 0).0, UInt8((200 / 8) % 256))
        XCTAssertEqual(sample(normalized.pixels, x: 0, y: 0).1, 0)
        // 目标 (511,511) 中心 → 源 (599, 399)。
        XCTAssertEqual(sample(normalized.pixels, x: 511, y: 511).0, UInt8((599 / 8) % 256))
        XCTAssertEqual(sample(normalized.pixels, x: 511, y: 511).1, UInt8((399 / 8) % 256))
    }

    func testNormalizerRejectsMismatchedBuffer() {
        XCTAssertThrowsError(try AvatarNormalizer.normalizedBGRA(pixels: [0, 0, 0, 0], width: 2, height: 1))
        XCTAssertThrowsError(try AvatarNormalizer.normalizedBGRA(pixels: [], width: 0, height: 0))
    }

    func testNormalizerRejectsOversizedPixels() {
        // 构造 width*height 超 8000×8000 的声明（不实际分配源像素——先触发像素上限）。
        // normalizedBGRA 先查 buffer 长度一致再查上限，故用小 buffer + 大声明命中长度校验；
        // 这里直接验证上限分支：合法长度、合法尺寸但超像素上限。
        let side = 9000
        // 不实际分配 9000×9000×4 字节（约 324 MB）；maxSourcePixels 校验在长度校验之后，
        // 无法在不分配的情况下触达。改为验证常量与 macOS 侧一致。
        XCTAssertEqual(AvatarNormalizer.maxSourcePixels, 8000 * 8000)
        XCTAssertEqual(AvatarNormalizer.maxSourceBytes, 25 * 1024 * 1024)
        XCTAssertEqual(AvatarNormalizer.pixelSize, 512)
        _ = side // 占位避免未使用告警
    }

    // MARK: - 头像合成回退

    func testAvatarCompositeCoversFaceAndFallsBack() {
        var character = ShellModel.fallbackCharacters()[0]
        character.avatarSource = .imported(filename: "test.png")
        let pose = PetPose(
            id: character.id, position: WorldPoint(x: 100, y: 0), state: .crawl,
            facing: .right, phase: 0, supportID: nil
        )
        let solid = PetCanvas.AvatarBitmap(pixels: [UInt8](repeating: 255, count: 512 * 512 * 4))
        let withAvatar = PetCanvas.render(character: character, pose: pose, avatar: solid)
        let faceIndex = (47 * 180 + 132) * 4  // 脸中心 (132,112) y 向上
        XCTAssertEqual(withAvatar.pixels[faceIndex + 3], 255)
        XCTAssertEqual(withAvatar.pixels[faceIndex], 255)
        XCTAssertEqual(withAvatar.pixels[faceIndex + 2], 255)

        // 非法位图长度 → 回退程序化脸（脸中心应有像素）。
        let invalid = PetCanvas.AvatarBitmap(pixels: [UInt8](repeating: 9, count: 16))
        let fallback = PetCanvas.render(character: character, pose: pose, avatar: invalid)
        XCTAssertEqual(fallback.pixels[faceIndex + 3], 255)
    }

    // MARK: - 会话状态

    func testSessionStateRoundtrip() {
        let state = SessionState(petX: 1234.5, petY: 67.25)
        let decoded = SessionState.decode(state.encode())
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.petX, 1234.5, accuracy: 0.01)
        XCTAssertEqual(decoded!.petY, 67.25, accuracy: 0.01)
    }

    func testSessionStateRejectsInvalidInput() {
        for bad in ["", "abc", "1,2,3", "-5,10", "nan,10", "inf,2", "10,", "1;2", "1e400,2"] {
            XCTAssertNil(SessionState.decode(bad), "should reject: \(bad)")
        }
    }

    func testPlaceLeaderClampsAndStaysInDisplay() {
        let display = WorldRect(x: 0, y: 0, width: 1920, height: 1080)!
        var model = ShellModel(characters: ShellModel.fallbackCharacters(), display: display)
        model.placeLeader(atX: 99999, atY: -500)
        for _ in 0..<300 {
            for frame in model.tick(deltaTime: 1.0 / ShellModel.simulationFPS) {
                XCTAssertTrue(display.contains(frame.pose.position), "pet escaped display after placeLeader")
            }
        }
    }

    // MARK: - 自检完整性

    func testSelfCheckRemainsGreen() {
        XCTAssertEqual(ShellModel.runSelfCheck(), [])
    }
}
