// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "AppLatchCore",
    platforms: [.macOS(.v11)],
    products: [.library(name: "AppLatchCore", targets: ["AppLatchCore"])],
    targets: [
        .target(name: "AppLatchCore", path: "AppLatch", exclude: ["AppLatchApp.swift", "AppModel.swift", "Views.swift", "Info.plist"], sources: ["LockPolicy.swift"]),
        .testTarget(name: "AppLatchCoreTests", dependencies: ["AppLatchCore"], path: "Tests/AppLatchCoreTests")
    ]
)
