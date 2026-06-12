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
        .target(name: "IHatePDFsCore"),
        .executableTarget(
            name: "IHatePDFs",
            dependencies: ["IHatePDFsCore"]
        ),
        .testTarget(
            name: "IHatePDFsCoreTests",
            dependencies: ["IHatePDFsCore"]
        )
    ]
)
