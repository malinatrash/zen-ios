// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FirefoxSyncKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "FirefoxSyncKit", targets: ["FirefoxSyncKit"])
    ],
    targets: [
        .target(name: "FirefoxSyncKit"),
        .testTarget(
            name: "FirefoxSyncKitTests",
            dependencies: ["FirefoxSyncKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)
