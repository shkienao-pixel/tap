// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Tap", platforms: [.macOS(.v13)], products: [
    .executable(name: "Tap", targets: ["Tap"])
], targets: [
    .target(name: "ShortcutCore"),
    .executableTarget(name: "Tap", dependencies: ["ShortcutCore"], resources: [.copy("Resources")], linkerSettings: [.linkedFramework("Carbon"), .linkedFramework("ServiceManagement")]),
    .testTarget(name: "ShortcutCoreTests", dependencies: ["ShortcutCore"])
])
