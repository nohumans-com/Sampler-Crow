// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SamplerCrowApp",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "SamplerCrowApp",
            path: "SamplerCrowApp",
            linkerSettings: [
                .linkedFramework("CoreMIDI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
