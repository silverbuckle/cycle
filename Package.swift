// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CycleNaviCore",
    products: [.library(name: "CycleNaviCore", targets: ["CycleNaviCore"])],
    targets: [
        .target(name: "CycleNaviCore"),
        .testTarget(name: "CycleNaviCoreTests", dependencies: ["CycleNaviCore"])
    ]
)
