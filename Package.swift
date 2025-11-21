// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrcaRemix",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OrcaRemixCore",
            targets: ["OrcaRemixCore"]),
    ],
    targets: [
        .target(
            name: "OrcaRemixCore",
            dependencies: [],
            path: "OrcaRemix",
            sources: [
                "AudioDeviceManager.swift",
                "AudioDeviceViewModel.swift"
            ]),
        .testTarget(
            name: "OrcaRemixTests",
            dependencies: ["OrcaRemixCore"],
            path: "OrcaRemixTests"),
    ]
)
