// swift-tools-version:6.0
import PackageDescription

// MacCask：macOS 应用程序管理工具
let package = Package(
    name: "MacCask",
    platforms: [.macOS(.v15)],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .executableTarget(
            name: "MacCask",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/MacCask",
            resources: [.copy("App/Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "MacCaskTests",
            dependencies: ["MacCask"],
            path: "Tests/MacCaskTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
