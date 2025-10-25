// swift-tools-version: 6.1

import CompilerPluginSupport
import PackageDescription

public let package = Package(
    name: "MetalSprockets",
    platforms: [
        .iOS("18.5"),
        .macOS("15.5"),
        .visionOS("2.5")
    ],
    products: [
        .library(name: "MetalSprockets", targets: ["MetalSprockets"]),
        .library(name: "MetalSprocketsUI", targets: ["MetalSprocketsUI"]),
        .library(name: "MetalSprocketsSupport", targets: ["MetalSprocketsSupport"]),
        .library(name: "MetalSprocketsSnapshotUI", targets: ["MetalSprocketsSnapshotUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0-latest"),
//        .package(url: "https://github.com/schwa/MetalCompilerPlugin", from: "0.1.0"),
        .package(url: "https://github.com/schwa/GeometryLite3D", branch: "main"),
    ],
    targets: [
        .target(
            name: "MetalSprockets",
            dependencies: [
                "MetalSprocketsSupport"
            ]
        ),
        .target(
            name: "MetalSprocketsUI",
            dependencies: [
                "MetalSprockets",
                "MetalSprocketsSupport",
            ]
        ),
        .target(
            name: "MetalSprocketsSnapshotUI",
            dependencies: [
                "MetalSprockets",
                "MetalSprocketsUI"
            ]
        ),
        .target(
            name: "MetalSprocketsSupport",
            dependencies: [
                "MetalSprocketsMacros"
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
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "GeometryLite3D",
            ],
            resources: [
                .copy("Golden Images")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
