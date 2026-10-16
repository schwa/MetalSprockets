// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ReconciliationBenchmark",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "ReconciliationBenchmark",
            dependencies: [
                .product(name: "MetalSprockets", package: "MetalSprockets")
            ]
        )
    ]
)
