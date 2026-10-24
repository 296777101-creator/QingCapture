// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QingCapture",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "QingCapture", targets: ["QingCaptureApp"])],
    targets: [
        .target(name: "QingCaptureCore"),
        .executableTarget(name: "QingCaptureApp", dependencies: ["QingCaptureCore"])
    ]
)
