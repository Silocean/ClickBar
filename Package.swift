// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClickBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClickBar", targets: ["ClickBar"])
    ],
    targets: [
        .target(
            name: "ClickBarCore",
            path: "Sources/ClickBarCore"
        ),
        .executableTarget(
            name: "ClickBar",
            dependencies: ["ClickBarCore"],
            path: "Sources/ClickBar"
        )
    ]
)
