// swift-tools-version:6.0
import PackageDescription

// MacCask：macOS 应用程序管理工具
let package = Package(
    name: "MacCask",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "MacCask",
            path: "Sources/MacCask",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MacCaskTests",
            dependencies: ["MacCask"],
            path: "Tests/MacCaskTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
