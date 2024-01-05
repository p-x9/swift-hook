// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftHook",
    products: [
        .library(
            name: "SwiftHook",
            targets: ["SwiftHook"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/p-x9/fishhook", branch: "spm"),
        .package(url: "https://github.com/p-x9/Echo", branch: "swift5.9"),
        .package(url: "https://github.com/p-x9/MachOKit-SPM", .upToNextMajor(from: "0.4.0"))
    ],
    targets: [
        .target(
            name: "SwiftHook",
            dependencies: [
                .product(name: "fishhook", package: "fishhook"),
                .product(name: "Echo", package: "Echo"),
                .product(name: "MachOKit", package: "MachOKit-SPM")
            ]
        ),
        .testTarget(
            name: "SwiftHookTests",
            dependencies: ["SwiftHook"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker",
                    "-interposable"
                ])
            ]
        ),
    ]
)
