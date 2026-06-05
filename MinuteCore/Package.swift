// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MinuteCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MinuteCore",
            targets: ["MinuteCore"]
        ),
        .library(
            name: "MinuteWhisper",
            targets: ["MinuteWhisper"]
        ),
        .library(
            name: "MinuteLlama",
            targets: ["MinuteLlama"]
        ),
        .library(
            name: "MinuteOllama",
            targets: ["MinuteOllama"]
        ),
        .library(
            name: "MinuteLMStudio",
            targets: ["MinuteLMStudio"]
        ),
        .library(
            name: "MinuteSherpaONNX",
            targets: ["MinuteSherpaONNX"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", revision: "e5c6456dd9cbbd6bcdc3aeefbddfcd483c5d3ca6"),
        // Prebuilt sherpa-onnx + onnxruntime (macOS arm64) for the GigaAM backend.
        .package(url: "https://github.com/vlsi/sherpa-onnx-apple-arm64", exact: "1.13.2"),
    ],
    targets: [
        // Precompiled whisper.cpp XCFramework (downloaded from ggml-org/whisper.cpp releases).
        .binaryTarget(
            name: "whisper",
            path: "Vendor/whisper/build-apple/whisper.xcframework"
        ),
        .binaryTarget(
            name: "llama",
            path: "Vendor/llama/llama.xcframework"
        ),

        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MinuteCore",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .target(
            name: "MinuteWhisper",
            dependencies: ["MinuteCore", "whisper"]
        ),
        .target(
            name: "MinuteLlama",
            dependencies: ["MinuteCore", "llama"]
        ),
        .target(
            name: "MinuteOllama",
            dependencies: ["MinuteCore"]
        ),
        .target(
            name: "MinuteLMStudio",
            dependencies: ["MinuteCore"]
        ),
        .target(
            name: "MinuteSherpaONNX",
            dependencies: [
                "MinuteCore",
                .product(name: "SherpaOnnx", package: "sherpa-onnx-apple-arm64"),
            ]
        ),
        .testTarget(
            name: "MinuteCoreTests",
            dependencies: [
                "MinuteCore",
                "MinuteOllama",
                "MinuteLMStudio",
            ],
            resources: [
                .process("Fixtures/Transcript"),
                .process("Fixtures/Frontmatter"),
            ]
        ),
    ]
)
