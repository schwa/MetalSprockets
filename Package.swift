// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

public let package = Package(
    name: "MetalSprockets",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "MetalSprockets", targets: ["MetalSprockets"]),
        .library(name: "MetalSprocketsUI", targets: ["MetalSprocketsUI"]),
        .library(name: "MetalSprocketsUIShaders", targets: ["MetalSprocketsUIShaders"]),
        .library(name: "MetalSprocketsShaders", targets: ["MetalSprocketsShaders"]),
        .library(name: "MetalSprocketsSupport", targets: ["MetalSprocketsSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/GeometryLite3D", .upToNextMinor(from: "0.2.4")),
        .package(url: "https://github.com/schwa/GoldenImage", .upToNextMinor(from: "0.1.6")),
        .package(url: "https://github.com/schwa/MetalCompilerPlugin", .upToNextMinor(from: "0.4.1")),
        .package(url: "https://github.com/schwa/MetalSupport", .upToNextMinor(from: "1.0.7")),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0"),
        .package(url: "https://github.com/nalexn/ViewInspector", .upToNextMinor(from: "0.10.5")),
    ],
    targets: [
        .target(
            name: "MetalSprockets",
            dependencies: [
                "MetalSprocketsSupport",
                .product(name: "MetalSupport", package: "MetalSupport"),
            ]
        ),
        .target(
            name: "MetalSprocketsUI",
            dependencies: [
                "MetalSprockets",
                "MetalSprocketsSupport",
                "MetalSprocketsUIShaders",
                .product(name: "MetalSupport", package: "MetalSupport"),
            ]
        ),
        .target(
            name: "MetalSprocketsShaders"
        ),
        .target(
            name: "MetalSprocketsUIShaders",
            exclude: ["Metal"],
            cSettings: [
                .define("METAL_COMPILER_PLUGIN_DEBUG", .when(configuration: .debug))
            ],
            plugins: [
                .plugin(name: "MetalCompilerPlugin", package: "MetalCompilerPlugin")
            ]
        ),
        .target(
            name: "MetalSprocketsSupport",
            dependencies: [
                "MetalSprocketsMacros",
                .product(name: "MetalSupport", package: "MetalSupport"),
            ]
        ),
        .macro(
            name: "MetalSprocketsMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "MetalSprocketsTests",
            dependencies: [
                "MetalSprockets",
                "MetalSprocketsUI",
                "MetalSprocketsSupport",
                .product(name: "MetalSupport", package: "MetalSupport"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "GeometryLite3D",
                "GoldenImage",
                .product(name: "ViewInspector", package: "ViewInspector"),
            ],
            resources: [
                .copy("Golden Images"),
                .copy("Fixtures")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
