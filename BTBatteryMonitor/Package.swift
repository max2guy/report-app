// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BTBatteryMonitor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BTBatteryMonitor",
            path: "Sources/BTBatteryMonitor",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
