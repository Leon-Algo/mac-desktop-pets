// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesktopPets",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DesktopPets", targets: ["DesktopPets"]),
        .library(name: "DesktopPetsCore", targets: ["DesktopPetsCore"]),
    ],
    targets: [
        // 平台无关的模拟核心：仅 Foundation，macOS / Windows 双端共享。
        .target(name: "DesktopPetsCore"),
        // 跨平台可行性探针：验证核心能在 Windows 工具链下编译并自检运行。
        .executableTarget(
            name: "CoreProbe",
            dependencies: ["DesktopPetsCore"],
            path: "Sources/CoreProbe"
        ),
        // macOS 壳：AppKit 窗口/菜单/渲染，驱动共享核心。
        .executableTarget(
            name: "DesktopPets",
            dependencies: ["DesktopPetsCore"],
            resources: [
                .process("Resources/Characters"),
                .copy("Resources/Localization"),
            ]
        ),
        .testTarget(name: "DesktopPetsTests", dependencies: ["DesktopPets", "DesktopPetsCore"]),
    ]
)
