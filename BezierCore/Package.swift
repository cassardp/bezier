// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BezierCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "BezierCore", targets: ["BezierCore"]),
    ],
    targets: [
        .target(name: "BezierCore"),
        .testTarget(name: "BezierCoreTests", dependencies: ["BezierCore"]),
    ]
)
