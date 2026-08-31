// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TemizlikVakti",
    platforms: [.macOS("14.0")],
    targets: [
        .executableTarget(
            name: "TemizlikVakti",
            path: "Sources/TemizlikVakti",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
