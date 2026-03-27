// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BTBatteryMonitor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BTBatteryMonitor",
            path: "Sources/BTBatteryMonitor",
            swiftSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/BTBatteryMonitor/Resources/Info.plist"
                ])
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreBluetooth"),
            ]
        ),
    ]
)
