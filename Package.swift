// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IHatePDFs",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "IHatePDFs", targets: ["IHatePDFs"]),
        .library(name: "IHatePDFsCore", targets: ["IHatePDFsCore"])
    ],
    targets: [
        .target(
            name: "IHatePDFsCore",
            path: "sources/core"
        ),
        .executableTarget(
            name: "IHatePDFs",
            dependencies: ["IHatePDFsCore"],
            path: "sources/app"
        ),
        .testTarget(
            name: "IHatePDFsCoreTests",
            dependencies: ["IHatePDFsCore"],
            path: "tests/core"
        ),
        .testTarget(
            name: "IHatePDFsTests",
            dependencies: ["IHatePDFs", "IHatePDFsCore"],
            path: "tests/app"
        )
    ]
)
