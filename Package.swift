// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ParcelCore", platforms: [.macOS(.v13), .iOS(.v17)], products: [.library(name: "ParcelCore", targets: ["ParcelCore"])], targets: [.target(name: "ParcelCore"), .testTarget(name: "ParcelCoreTests", dependencies: ["ParcelCore"])])
