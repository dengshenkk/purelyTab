// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PurelyTab",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "PurelyTab", targets: ["PurelyTab"])
    ],
    targets: [
        .executableTarget(
            name: "PurelyTab",
            path: "Sources"
        )
    ]
)
