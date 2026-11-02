// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacSwitch",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MacSwitchCore", targets: ["MacSwitchCore"]),
        .executable(name: "MacSwitch", targets: ["MacSwitch"])
    ],
    targets: [
        .target(name: "MacSwitchCore"),
        .executableTarget(name: "MacSwitch", dependencies: ["MacSwitchCore"],
                          resources: [.copy("Resources")]),
        .testTarget(name: "MacSwitchCoreTests", dependencies: ["MacSwitchCore"])
    ],
    swiftLanguageModes: [.v5]
)
