// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CycleNaviCore",
    platforms: [.macOS(.v13), .iOS(.v18)],
    products: [.library(name: "CycleNaviCore", targets: ["CycleNaviCore"])],
    targets: [
        .target(name: "CycleNaviCore"),
        .testTarget(name: "CycleNaviCoreTests", dependencies: ["CycleNaviCore"])
    ]
)
