# Architecture Patterns

**Domain:** macOS Menu Bar App - Bluetooth Battery Monitor
**Researched:** 2026-03-27
**Overall Confidence:** MEDIUM (based on training data; web verification tools were unavailable)

## Recommended Architecture

A menu-bar-only macOS app (no main window) with three distinct layers: **UI Layer** (SwiftUI MenuBarExtra), **Service Layer** (Bluetooth monitoring + battery reading), and **Persistence Layer** (UserDefaults for settings). The app runs as an `LSUIElement` (agent app) with no Dock icon.

```
+--------------------------------------------------+
|              SwiftUI MenuBarExtra                 |
|  (Icon + percentage label in menu bar)            |
|  (Popover/Menu with device list on click)         |
+---------------------------+----------------------+
                            |
                   Observes (Combine / @Observable)
                            |
+---------------------------v----------------------+
|            BluetoothDeviceManager                |
|  (@Observable / ObservableObject)                |
|  - discoveredDevices: [BTDevice]                 |
|  - monitoredDevices: [BTDevice]                  |
|  - batteryLevels: [UUID: Int]                    |
|  - polling timer                                 |
+-------+------------------+-----------------------+
        |                  |
        v                  v
+-------+------+   +------+-----------------------+
| IOKit Bridge |   | CoreBluetooth (BLE) Scanner  |
| (Classic BT  |   | CBCentralManager             |
|  + HID       |   | Battery Service 0x180F       |
|  battery)    |   +------------------------------+
+--------------+
        |
        v
+-------+------+
| IORegistry   |
| (IOService   |
|  matching)   |
+--------------+
```

## Component Boundaries

| Component | Responsibility | Communicates With | Framework |
|-----------|---------------|-------------------|-----------|
| **App Entry** | App lifecycle, MenuBarExtra declaration | BluetoothDeviceManager | SwiftUI |
| **MenuBarView** | Icon rendering, percentage display in menu bar | BluetoothDeviceManager (read) | SwiftUI |
| **DeviceListView** | Popover/menu showing all devices with battery | BluetoothDeviceManager (read), SettingsManager (read/write) | SwiftUI |
| **BluetoothDeviceManager** | Central coordinator: merges IOKit + BLE data, manages polling | IOKitBatteryReader, BLEBatteryScanner, SettingsManager | Foundation, Combine |
| **IOKitBatteryReader** | Reads battery from IORegistry (Classic BT, HID devices) | IOKit/IOBluetooth C APIs | IOKit, IOBluetooth |
| **BLEBatteryScanner** | Discovers BLE peripherals, reads GATT Battery Service (0x180F) | CoreBluetooth | CoreBluetooth |
| **SettingsManager** | Persists monitored device selection, polling interval | UserDefaults | Foundation |
| **LoginItemManager** | Register/unregister as Login Item | ServiceManagement | ServiceManagement |

## Data Flow

### 1. Battery Level Discovery (Primary Flow)

```
IORegistry (IOKit)                     BLE Peripheral (CoreBluetooth)
       |                                        |
       v                                        v
IOKitBatteryReader                     BLEBatteryScanner
  reads IOService properties             discovers services,
  "BatteryPercent" / "BatteryLevel"      reads 0x180F char
       |                                        |
       +------- BTDevice model --------+--------+
                                       |
                                       v
                          BluetoothDeviceManager
                          (merges, deduplicates,
                           publishes @Published/
                           @Observable state)
                                       |
                          Combine / Observation
                                       |
                                       v
                              SwiftUI Views
                          (MenuBarView, DeviceListView)
```

### 2. User Interaction Flow

```
User clicks menu bar icon
       |
       v
MenuBarExtra shows popover/menu
       |
       v
DeviceListView renders device list
  - Each device: name, icon, battery %, last updated
  - Toggle: monitored or not
       |
       v (user toggles device)
SettingsManager persists selection
       |
       v
BluetoothDeviceManager updates which device
  shows in the menu bar icon/label
```

### 3. Polling Flow

```
Timer (every 60-300 seconds, configurable)
       |
       v
BluetoothDeviceManager.refresh()
       |
       +---> IOKitBatteryReader.readAll()
       |          |
       |          v  (IORegistryEntryCreateCFProperties)
       |          returns [UUID: batteryLevel]
       |
       +---> BLEBatteryScanner.readAll()
                   |
                   v  (CBPeripheral.readValue for 0x180F)
                   returns [UUID: batteryLevel]
       |
       v
Merge results, update @Observable state
       |
       v
SwiftUI re-renders automatically
```

## Detailed Component Design

### App Entry Point

```swift
@main
struct BTBatteryApp: App {
    @State private var deviceManager = BluetoothDeviceManager()

    var body: some Scene {
        MenuBarExtra {
            DeviceListView()
                .environment(deviceManager)
        } label: {
            MenuBarLabel()
                .environment(deviceManager)
        }
        // No WindowGroup — menu-bar-only app
    }
}
```

**Key decisions:**
- `MenuBarExtra` (macOS 14+ for `.window` style; macOS 13+ for `.menu` style) replaces legacy NSStatusItem approach
- For macOS 13 support, use `.menuBarExtraStyle(.menu)` which works as a standard NSMenu
- For richer UI (popover with custom views), use `.menuBarExtraStyle(.window)` which requires macOS 14+
- Set `LSUIElement = true` in Info.plist to hide Dock icon

**Confidence:** HIGH for MenuBarExtra availability in macOS 13+. MEDIUM for `.window` style requiring macOS 14 (may have been macOS 13 with limited features).

### IOKitBatteryReader (Classic Bluetooth + HID)

This is the primary battery reading mechanism for most Bluetooth devices that macOS already tracks.

```swift
import IOKit

class IOKitBatteryReader {
    struct DeviceBattery {
        let name: String
        let address: String
        let batteryLevel: Int // 0-100
        let vendorID: Int?
        let productID: Int?
    }

    func readAllBatteryLevels() -> [DeviceBattery] {
        // 1. Match IOService entries for Bluetooth HID devices
        // 2. Read "BatteryPercent" or "BatteryLevel" property
        // 3. Return array of device battery info
    }
}
```

**How IOKit battery reading works:**
1. Use `IOServiceGetMatchingServices` to find Bluetooth HID device entries in the IORegistry
2. Matching dictionary: `IOServiceNameMatching("AppleDeviceManagementHIDEventService")` or iterate `IOBluetoothDevice` entries
3. Read properties via `IORegistryEntryCreateCFProperties`:
   - `"BatteryPercent"` — most common key for Apple and many third-party devices
   - `"BatteryLevel"` — alternative key
   - `"Product"` / `"Transport"` — to identify Bluetooth devices
4. This works for devices that expose battery via HID Battery Usage Page (0x85) without needing explicit BLE GATT connection

**What IOKit can read:**
- Apple peripherals (Magic Keyboard, Magic Mouse, Magic Trackpad) -- HIGH confidence
- Third-party Bluetooth HID devices that report battery via HID protocol -- MEDIUM confidence
- Many gaming peripherals and mechanical keyboards that have HID battery reporting -- LOW confidence (device-dependent)

**What IOKit CANNOT read:**
- Devices that do not implement HID Battery Usage Page
- Devices that only report battery through proprietary protocols
- Devices that report battery only through BLE GATT but are not HID

**Confidence:** MEDIUM. IOKit is the proven approach used by existing tools like `ioreg -l | grep BatteryPercent`. The specific IOService matching dictionaries may need experimentation.

### BLEBatteryScanner (BLE GATT)

Covers BLE-only devices that expose the standard Battery Service.

```swift
import CoreBluetooth

class BLEBatteryScanner: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var peripherals: [CBPeripheral] = []

    // Battery Service UUID
    let batteryServiceUUID = CBUUID(string: "180F")
    // Battery Level Characteristic UUID
    let batteryLevelUUID = CBUUID(string: "2A19")

    func startScanning() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // CBCentralManagerDelegate: discover peripherals
    // CBPeripheralDelegate: discover services -> discover characteristics
    //   -> read value of 0x2A19 -> parse single byte (0-100)
}
```

**BLE Battery Service (0x180F):**
- Standard Bluetooth SIG service
- Contains Battery Level characteristic (0x2A19): single unsigned byte, 0-100
- Supports notifications (subscribe for changes)
- Many BLE devices implement this, but not all

**Key challenge:** CoreBluetooth requires an active connection to read characteristics. Scanning alone does not reveal battery levels. The app must:
1. Scan for peripherals advertising Battery Service
2. Connect to each
3. Discover services and characteristics
4. Read or subscribe to battery level characteristic
5. Optionally disconnect (some devices allow read-then-disconnect)

**Confidence:** HIGH for the GATT protocol. MEDIUM for how well this works in practice with various devices.

### BluetoothDeviceManager (Central Coordinator)

```swift
@Observable
class BluetoothDeviceManager {
    var devices: [BTDevice] = []
    var primaryDevice: BTDevice? // shown in menu bar

    private let iokitReader = IOKitBatteryReader()
    private let bleScanner = BLEBatteryScanner()
    private let settings = SettingsManager()
    private var pollTimer: Timer?

    func startMonitoring() {
        // 1. Initial read from IOKit
        // 2. Start BLE scanning for additional devices
        // 3. Start polling timer
        // 4. Merge results
    }

    func refresh() {
        let iokitDevices = iokitReader.readAllBatteryLevels()
        // BLE results come asynchronously via delegate
        // Merge into unified device list
    }
}
```

**Design choice: @Observable (macOS 14+) vs ObservableObject (macOS 13+)**

For macOS 13+ target as specified in PROJECT.md, use `ObservableObject` with `@Published` properties for compatibility. If the target is raised to macOS 14+, prefer `@Observable` macro for simpler observation.

Recommendation: Target macOS 14+ if possible. MenuBarExtra `.window` style and `@Observable` both work best on macOS 14+. macOS 13 is now 3+ years old.

### BTDevice (Data Model)

```swift
struct BTDevice: Identifiable, Hashable {
    let id: UUID  // or hardware address as identifier
    let name: String
    let address: String
    let deviceType: DeviceType  // keyboard, mouse, headphones, etc.
    let source: BatterySource   // .iokit, .ble, .both
    var batteryLevel: Int?      // nil if unavailable
    var isMonitored: Bool       // user selection
    var lastUpdated: Date?
}

enum DeviceType: String, Codable {
    case keyboard, mouse, trackpad, headphones, gamepad, unknown
}

enum BatterySource {
    case iokit      // read via IORegistry
    case ble        // read via CoreBluetooth GATT
    case both       // available from both sources
}
```

### SettingsManager

```swift
class SettingsManager {
    @AppStorage("monitoredDeviceIDs") var monitoredDeviceIDs: Set<String> = []
    @AppStorage("pollingInterval") var pollingInterval: TimeInterval = 120
    @AppStorage("showPercentageInMenuBar") var showPercentage: Bool = true
}
```

Simple UserDefaults-based persistence. No database needed for this app.

## Patterns to Follow

### Pattern 1: Agent App (LSUIElement)

**What:** An app that has no Dock icon and no main menu bar. Only visible through its NSStatusItem / MenuBarExtra.

**How:**
- Set `LSUIElement = YES` in Info.plist (or `Application is agent (UIElement) = YES`)
- Do not declare any `WindowGroup` scene, only `MenuBarExtra`

**Why:** Standard pattern for menu bar utilities. Users expect no Dock clutter from battery monitors.

### Pattern 2: IOKit C API Bridge with Swift

**What:** IOKit is a C framework. Use Swift wrappers to manage memory (CFRetain/CFRelease) and type casting.

**How:**
```swift
func readIOKitBattery() -> [(String, Int)] {
    var results: [(String, Int)] = []
    var iterator: io_iterator_t = 0

    let matching = IOServiceMatching("AppleDeviceManagementHIDEventService")
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
        return results
    }
    defer { IOObjectRelease(iterator) }

    var service: io_object_t = IOIteratorNext(iterator)
    while service != 0 {
        defer {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any] else { continue }

        if let battery = dict["BatteryPercent"] as? Int,
           let product = dict["Product"] as? String {
            results.append((product, battery))
        }
    }
    return results
}
```

**Why:** IOKit provides the most reliable way to read battery from devices macOS already tracks. No connection management needed.

### Pattern 3: Timer-Based Polling with Combine

**What:** Periodic refresh of battery levels.

**How:**
```swift
Timer.publish(every: pollingInterval, on: .main, in: .common)
    .autoconnect()
    .sink { [weak self] _ in self?.refresh() }
    .store(in: &cancellables)
```

**Why:** Battery levels change slowly. Polling every 60-300 seconds is sufficient. BLE notifications can supplement but should not replace polling for IOKit-sourced data.

### Pattern 4: Merge Strategy for Dual Sources

**What:** A device may appear in both IOKit and CoreBluetooth. Deduplicate by hardware address.

**How:**
- IOKit provides Bluetooth address (e.g., `"XX-XX-XX-XX-XX-XX"`)
- CoreBluetooth provides a system-assigned UUID (not the same as hardware address on macOS since macOS 10.13+)
- To correlate: use IOBluetooth framework's `IOBluetoothDevice.init(address:)` to map between the two
- Prefer IOKit battery reading when available (no connection overhead)

**Why:** Avoids showing duplicate entries and unnecessary BLE connections.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Continuous BLE Scanning

**What:** Leaving CBCentralManager scanning indefinitely.

**Why bad:** Drains system battery, generates excessive delegate callbacks, may trigger macOS power management warnings. Apple recommends stopping scan as soon as target peripherals are found.

**Instead:** Scan briefly during refresh cycles, then stop. Use a scan timeout (5-10 seconds).

### Anti-Pattern 2: Using NSStatusItem Directly Instead of MenuBarExtra

**What:** Dropping down to AppKit's NSStatusItem for the menu bar integration.

**Why bad:** Unnecessary complexity. SwiftUI's MenuBarExtra handles the lifecycle, works with the Scene protocol, and is the modern approach. Mixing AppKit and SwiftUI creates maintenance burden.

**Instead:** Use `MenuBarExtra` for the menu bar presence. Only drop to AppKit if you need specific features MenuBarExtra does not support (e.g., drag-and-drop on the status item).

**Caveat:** If targeting macOS 13 with `.menu` style is too limiting, consider NSStatusItem + NSPopover as a fallback.

### Anti-Pattern 3: Storing Battery History in a Database

**What:** Using Core Data or SQLite to persist battery readings over time.

**Why bad:** Premature complexity for v1. Battery history is a v2 feature at best. Adds schema migration concerns.

**Instead:** Keep battery levels in memory only. Persist only user settings (which devices to monitor, polling interval).

### Anti-Pattern 4: Requesting Bluetooth Permission at Launch Without Context

**What:** Triggering the Bluetooth permission dialog immediately on first launch.

**Why bad:** Users deny permissions when they do not understand why they are needed.

**Instead:** Show a brief explanation before triggering the permission prompt. Or trigger it only when the user first opens the device list.

## Entitlements and Permissions

| Permission | Entitlement/Key | Required For |
|------------|----------------|--------------|
| Bluetooth | `NSBluetoothAlwaysUsageDescription` in Info.plist | CoreBluetooth scanning |
| Bluetooth (App Sandbox) | `com.apple.security.device.bluetooth` | IOKit + CoreBluetooth in sandboxed app |
| App Sandbox | `com.apple.security.app-sandbox` | App Store distribution (optional for direct distribution) |
| Login Items | ServiceManagement framework | Auto-start at login |

**Sandboxing consideration:** If distributing outside the App Store, consider NOT sandboxing. Sandbox restricts IOKit access and may prevent reading battery from some devices via IORegistry. For App Store distribution, the `com.apple.security.device.bluetooth` entitlement is needed.

**Confidence:** MEDIUM. Exact entitlement names and sandbox behavior with IOKit may need verification during development.

## Scalability Considerations

This app is inherently small-scale (monitoring a handful of personal Bluetooth devices), so traditional scalability is not a concern. Instead, consider:

| Concern | Approach |
|---------|----------|
| Many BLE devices (10+) | Batch connection, sequential not parallel to avoid CBCentralManager limits |
| Power efficiency | Poll infrequently (120s+), avoid constant BLE scanning |
| Memory | In-memory model only, no caching layers needed |
| Thread safety | IOKit reads on background queue, publish to MainActor |

## Suggested Build Order

Based on component dependencies:

```
Phase 1: Menu Bar Shell
  App Entry (MenuBarExtra) + Static UI
  -> No bluetooth needed, just get the app structure running
  -> Dependency: None

Phase 2: IOKit Battery Reading
  IOKitBatteryReader + BluetoothDeviceManager (IOKit only)
  -> Read battery from devices macOS already tracks
  -> Dependency: Phase 1 (needs UI to display results)

Phase 3: Device Selection + Settings
  SettingsManager + DeviceListView (interactive)
  -> User picks which device to show in menu bar
  -> Dependency: Phase 2 (needs devices to select from)

Phase 4: BLE Battery Service (0x180F)
  BLEBatteryScanner + merge logic in BluetoothDeviceManager
  -> Covers devices not visible via IOKit
  -> Dependency: Phase 2 (extends existing manager)

Phase 5: Polish
  Login Items, dynamic icons, error handling, edge cases
  -> Dependency: Phases 1-4
```

**Rationale for this order:**
1. **IOKit before BLE:** IOKit is simpler (no connection management), covers more devices that macOS already tracks, and provides immediate value. Many third-party keyboards that report battery via HID will show up here.
2. **Settings after IOKit:** Need real device data before building the selection UI.
3. **BLE last:** More complex (connection management, async delegates), covers fewer additional devices, and may not even be needed if the target keyboard reports via HID.

## Open Architecture Questions

1. **Does the target mechanical keyboard report battery via HID?** Test with `ioreg -r -l -n AppleDeviceManagementHIDEventService | grep -i battery`. If yes, IOKit alone may suffice for the primary use case.

2. **MenuBarExtra style choice:** `.menu` (macOS 13+, limited to NSMenu items) vs `.window` (macOS 14+, full SwiftUI popover). Recommend `.window` if macOS 14+ is acceptable.

3. **Sandbox vs non-sandbox:** For personal use / direct distribution, skip sandboxing. For App Store, sandboxing is mandatory and may limit IOKit access.

4. **IOBluetooth framework:** May be needed to enumerate paired Bluetooth devices and get hardware addresses for device correlation. This is a private-ish framework; verify current API stability.

## Sources

- Apple Developer Documentation: CoreBluetooth framework (training data, not verified live)
- Apple Developer Documentation: IOKit framework (training data)
- Apple Developer Documentation: SwiftUI MenuBarExtra (training data)
- Apple Developer Documentation: ServiceManagement for Login Items (training data)
- Bluetooth SIG Battery Service Specification (UUID 0x180F, characteristic 0x2A19) (training data)
- Common macOS menu bar app patterns from open-source projects (training data)

**Note:** Web verification tools were unavailable during this research. All findings are based on training data (cutoff ~early 2025). IOKit APIs and MenuBarExtra behavior should be verified against current documentation during implementation.
