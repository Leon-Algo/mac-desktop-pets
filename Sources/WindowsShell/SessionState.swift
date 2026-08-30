import Foundation
import DesktopPetsCore

/// 会话状态纯逻辑：窗口/宠物位置持久化的编解码与校验（跨平台可测）。
/// 存储介质由平台壳决定（Windows 注册表 REG_SZ / macOS 用户默认值），
/// 本类型只负责「字符串 ↔ 结构化状态」的可靠转换。
///
/// 只持久化 petX/petY（leader 锚点，世界坐标 y 向上）：重启后按 PetWorld
/// 布局逻辑从该锚点重排全部宠物，避免存 N 份坐标带来的漂移与越界风险。
struct SessionState: Equatable {
    /// 首宠物（leader）退出时的世界坐标锚点。
    var petX: Double
    var petY: Double

    static let boundsTolerance: Double = 0.001

    /// 反序列化 + 校验：非有限数或负值一律拒绝（返回 nil，调用方回退默认布局）。
    static func decode(_ string: String) -> SessionState? {
        let parts = string.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let x = Double(parts[0]),
              let y = Double(parts[1]),
              x.isFinite, y.isFinite, x >= 0, y >= 0 else { return nil }
        return SessionState(petX: x, petY: y)
    }

    /// 序列化为 "x,y"（小数点后 2 位，控制注册表值长度）。
    func encode() -> String {
        String(format: "%.2f,%.2f", petX, petY)
    }
}

/// Windows 会话状态存取纯逻辑（值名/序列化约定），实际注册表读写仅 Windows 编译。
enum SessionStatePolicy {
    /// HKCU\Software\DesktopPets 下的值名。
    static let valueName = "SessionState"
    static let subKeyPath = "Software\\DesktopPets"
}
