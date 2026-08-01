// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesktopPets",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DesktopPets", targets: ["DesktopPets"]),
    ],
    targets: [
        .executableTarget(name: "DesktopPets"),
        .testTarget(name: "DesktopPetsTests", dependencies: ["DesktopPets"]),
    ]
)
