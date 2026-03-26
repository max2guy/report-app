# Technology Stack

**Project:** BT Battery Monitor
**Researched:** 2026-03-27
**Overall Confidence:** MEDIUM (web search/fetch unavailable; based on training data up to May 2025 -- versions and API availability should be verified)

## Recommended Stack

### Language & Toolchain

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Swift | 5.9+ (ship with Xcode 16+) | Primary language | PROJECT.md specifies Swift. No reason to deviate -- first-class macOS APIs, ARC memory management, strong typing. | HIGH |
| Xcode | 16+ | IDE & build system | Required for macOS app signing, entitlements, and Interface Builder for menu bar icons. | HIGH |
| Swift Package Manager | Built-in | Dependency management | CocoaPods is legacy; SPM is Apple's official tool. No need for third-party deps in this project anyway. | HIGH |

### UI Framework

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| SwiftUI `MenuBarExtra` | macOS 13+ (Ventura) | Menu bar presence | Apple introduced `MenuBarExtra` in macOS 13 as the official SwiftUI way to build menu bar apps. Replaces the old NSStatusItem + AppDelegate dance. Declare in `@main App { ... }` body alongside `WindowGroup` or standalone. | HIGH |
| SwiftUI | 5.0+ (macOS 14+) / 4.0 (macOS 13) | Popover UI | Battery list, device selector, settings. SwiftUI is the right choice for a simple popover UI. | HIGH |
| AppKit (NSStatusItem) | Fallback only | Menu bar (if MenuBarExtra insufficient) | If you need pixel-level control of the status item icon (animated battery icon, custom drawing), drop down to `NSStatusItem` via `NSViewRepresentable`. MenuBarExtra handles 90% of cases. | HIGH |

**Key decision: MenuBarExtra vs NSStatusItem**

Use `MenuBarExtra` as the primary approach. It supports:
- `MenuBarExtra("Label", systemImage: "battery.100") { ... }` with a SwiftUI view as content
- `.menuBarExtraStyle(.window)` for a popover-style panel (what we want for the device list)
- `.menuBarExtraStyle(.menu)` for a traditional NSMenu-style dropdown

Only fall back to NSStatusItem if you need: custom animated icon drawing, drag-and-drop on the status item, or behavior MenuBarExtra does not expose.

### Bluetooth & Battery APIs (Critical Section)

There are **three distinct approaches** to reading Bluetooth device battery levels on macOS. The app should implement all three in a layered strategy because no single API covers all device types.

#### Layer 1: IOKit / IORegistry (Highest Priority)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| IOKit framework | System | Read battery levels from IORegistry | macOS stores battery info for paired Bluetooth devices in the IORegistry under `IOBluetoothDevice` entries. The key `BatteryPercent` (or `BatteryPercentCase`, `BatteryPercentLeft`, `BatteryPercentRight` for AirPods) is populated by the Bluetooth stack for devices that report battery via HID or vendor-specific protocols. This is how macOS System Preferences itself reads battery. | HIGH |

**How it works:**
```swift
import IOKit

// Iterate IORegistry matching IOBluetoothDevice
let matchingDict = IOServiceMatching("IOBluetoothDevice")
var iterator: io_iterator_t = 0
IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

var device = IOIteratorNext(iterator)
while device != IO_OBJECT_NULL {
    // Read "BatteryPercent" property
    if let batteryPercent = IORegistryEntryCreateCFProperty(
        device, "BatteryPercent" as CFString, kCFAllocatorDefault, 0
    )?.takeRetainedValue() as? Int {
        // Got battery level
    }
    // Also read "Name", "Address" for identification
    device = IOIteratorNext(iterator)
}
```

**Coverage:** Apple devices (Magic Keyboard, Magic Mouse, Magic Trackpad), AirPods, and many third-party devices that report battery via HID Battery Strength report. This is the broadest approach.

**Limitation:** Only works if the Bluetooth stack already knows the battery level. For devices where macOS shows no battery in System Settings, this key will be absent.

#### Layer 2: CoreBluetooth (BLE GATT Battery Service)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| CoreBluetooth | System | Read BLE Battery Service (0x180F) | For BLE devices that expose the standard GATT Battery Service, CoreBluetooth can read the Battery Level characteristic (0x2A19). This covers BLE peripherals that macOS does not natively surface battery info for. | HIGH |

**How it works:**
```swift
import CoreBluetooth

class BatteryManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    let batteryServiceUUID = CBUUID(string: "180F")
    let batteryLevelUUID = CBUUID(string: "2A19")

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([batteryServiceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics ?? [] {
            if char.uuid == batteryLevelUUID {
                peripheral.readValue(for: char)
                peripheral.setNotifyValue(true, for: char) // Subscribe to changes
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value, let level = data.first {
            // level is 0-100 battery percentage
        }
    }
}
```

**Coverage:** Any BLE device implementing the Battery Service profile. Many Bluetooth keyboards, mice, and headphones support this.

**Limitation:** Classic Bluetooth (BR/EDR) devices are invisible to CoreBluetooth. Also requires the device to be connected and the app to actively scan/connect. Sandboxed apps need `com.apple.security.device.bluetooth` entitlement.

#### Layer 3: IOBluetooth (Classic Bluetooth / Fallback)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| IOBluetooth | System | Enumerate paired devices, get Classic BT info | For discovering paired/connected Classic Bluetooth devices and their properties. Useful for device enumeration even if battery comes from IOKit. | MEDIUM |

**How it works:**
```swift
import IOBluetooth

// Get all paired devices
let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
for device in devices {
    let name = device.name ?? "Unknown"
    let address = device.addressString ?? ""
    let isConnected = device.isConnected()
    // Battery not directly available here -- use IOKit IORegistry for that
}
```

**Coverage:** Device enumeration for Classic BT. Battery data still comes from IOKit Layer 1.

**Limitation:** IOBluetooth is an older Objective-C framework. It works but is not actively evolving. The API is stable but not Swift-friendly (lots of bridging). Not available in sandboxed apps without the Bluetooth entitlement.

### Recommended Layered Strategy

```
1. IOKit IORegistry scan (covers most devices macOS already knows about)
   |
   v
2. CoreBluetooth BLE GATT 0x180F (catches BLE devices IOKit misses)
   |
   v
3. IOBluetooth device enumeration (for device list, names, connection status)
```

**Priority:** Start with Layer 1 (IOKit). It gives the most results with the least complexity. Layer 2 (CoreBluetooth BLE) adds coverage for BLE-only devices. Layer 3 (IOBluetooth) is mainly for device discovery/metadata.

### App Lifecycle & System Integration

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| `SMAppService` | macOS 13+ | Login item (launch at startup) | Replaces the deprecated `SMLoginItemSetEnabled`. Register the app as a login item so it starts on boot. `SMAppService.mainApp.register()`. | HIGH |
| `UserDefaults` | System | Persist user preferences | Which devices to monitor, polling interval, UI preferences. Simple key-value storage is sufficient for this app's needs. | HIGH |
| `Timer` / `DispatchSourceTimer` | System | Periodic battery polling | Poll IOKit every 30-60 seconds. Use `Timer.publish(every:)` in Combine or a simple `Timer.scheduledTimer`. | HIGH |
| `NSWorkspace.didWakeNotification` | System | Refresh after sleep/wake | Bluetooth state changes after sleep. Re-scan on wake. | HIGH |

### App Distribution

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| Xcode notarization | Distribution outside App Store | App Sandbox + Bluetooth entitlement means App Store is possible, but direct distribution via notarized DMG is simpler for a utility. | HIGH |
| `createDMG` or `create-dmg` | Package as DMG | Standard macOS app distribution format. | MEDIUM |

## What NOT to Use

| Technology | Why Not |
|------------|---------|
| **Electron / Tauri** | Overkill for a menu bar utility. No access to IOKit/IOBluetooth. 100MB+ binary for a 5MB app. |
| **CocoaPods** | Legacy dependency manager. SPM is standard. This project likely needs zero third-party deps anyway. |
| **Carthage** | Same as CocoaPods -- legacy. |
| **RxSwift** | Combine is built-in and sufficient. No need for a third-party reactive framework for this scope. |
| **IOBluetooth for battery reading** | IOBluetooth does not directly expose battery levels. Use IOKit IORegistry instead. IOBluetooth is only for device enumeration. |
| **Private/undocumented APIs** | Tempting for battery access but breaks with macOS updates and prevents App Store distribution. Stick to IOKit + CoreBluetooth. |
| **`LSSharedFileListItemSetHidden` for login items** | Deprecated since macOS 13. Use `SMAppService` instead. |
| **Storyboards** | SwiftUI is sufficient and simpler for this app's UI. Storyboards add unnecessary complexity. |

## Entitlements & Permissions

```xml
<!-- App.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <!-- Required for CoreBluetooth scanning -->
    <key>com.apple.security.device.bluetooth</key>
    <true/>

    <!-- App Sandbox (required for distribution) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

```xml
<!-- Info.plist -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>BT Battery Monitor needs Bluetooth access to read device battery levels.</string>
```

**Note on Sandboxing:** IOKit IORegistry access works within the App Sandbox for reading Bluetooth device properties. CoreBluetooth requires the `com.apple.security.device.bluetooth` entitlement. If IOKit access is blocked by sandbox for certain registry paths, consider distributing outside the App Store (notarized but not sandboxed). This needs testing during Phase 1.

## Minimum Deployment Target

**macOS 13 (Ventura)** because:
- `MenuBarExtra` was introduced in macOS 13
- `SMAppService` was introduced in macOS 13
- SwiftUI maturity on macOS reached usable quality in macOS 13
- macOS 13 dropped support for pre-Apple Silicon Macs older than 2017, so the install base is modern

## Project Structure

```
BTBatteryMonitor/
  BTBatteryMonitorApp.swift       # @main, MenuBarExtra declaration
  Views/
    BatteryPopoverView.swift      # Main popover showing all devices
    DeviceRowView.swift           # Single device battery row
    SettingsView.swift            # Device selection, preferences
  Models/
    BluetoothDevice.swift         # Device model (name, address, battery, type)
    BatteryLevel.swift            # Battery level enum/struct
  Services/
    IOKitBatteryService.swift     # Layer 1: IORegistry battery reading
    BLEBatteryService.swift       # Layer 2: CoreBluetooth GATT reading
    DeviceDiscoveryService.swift  # IOBluetooth device enumeration
    BatteryMonitor.swift          # Combines all layers, polling logic
  Utilities/
    BluetoothPermissions.swift    # Permission checking/requesting
```

## Third-Party Dependencies

**None recommended.** This project's needs are fully covered by system frameworks:
- UI: SwiftUI + AppKit (MenuBarExtra)
- Bluetooth: IOKit + CoreBluetooth + IOBluetooth
- Persistence: UserDefaults
- Scheduling: Timer / Combine
- Login item: SMAppService

Zero dependencies means zero supply chain risk, zero version conflicts, and easier App Store review.

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| UI Framework | SwiftUI MenuBarExtra | NSStatusItem + AppKit | MenuBarExtra is the modern approach; only use NSStatusItem if MenuBarExtra can't do something specific |
| Battery Reading | IOKit IORegistry | Private APIs (e.g., `IOBluetoothDevice.batteryPercent()`) | Private APIs break across OS versions, block App Store |
| BLE Battery | CoreBluetooth | Third-party BLE libraries | CoreBluetooth is the official API; no benefit from wrapping it |
| Reactive | Combine | RxSwift | Combine is built-in, no external dep needed for this scope |
| State Management | @Observable (macOS 14+) or ObservableObject | SwiftData, Core Data | Overkill. UserDefaults + in-memory models are sufficient |
| Login Item | SMAppService | LaunchAgent plist | SMAppService is the official API since macOS 13 |

## Sources & Confidence Notes

- **IOKit IORegistry battery reading:** Based on well-established pattern used by tools like `ioreg -l | grep BatteryPercent`. HIGH confidence this works, but exact key names should be verified on target macOS version.
- **CoreBluetooth GATT Battery Service (0x180F):** Standard Bluetooth SIG profile. HIGH confidence on API, MEDIUM confidence on coverage (depends on whether specific keyboards expose this service).
- **MenuBarExtra:** Introduced WWDC 2022 for macOS 13. HIGH confidence.
- **SMAppService:** Introduced WWDC 2022 for macOS 13. HIGH confidence.
- **Version numbers:** MEDIUM confidence -- Swift 5.9/6.0 and Xcode 16 versions should be verified against current Xcode release notes as of March 2026.
- **Sandbox + IOKit interaction:** MEDIUM confidence -- needs empirical testing during Phase 1. IOKit registry reads are generally allowed in sandbox but specific paths may vary.
