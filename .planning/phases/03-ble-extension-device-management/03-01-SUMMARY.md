---
phase: 03-ble-extension-device-management
plan: 01
subsystem: bluetooth-battery-services
tags: [CoreBluetooth, IOHIDManager, BLE-GATT, HID-Generic, UserDefaults, PollingInterval]
dependency_graph:
  requires: [02-02 (BluetoothService, BatteryService, BluetoothDevice base implementation)]
  provides: [BLEService (GATT 0x180F reader), probeHIDGenericDevice (HID UsagePage=6), DevicePreferences (UserDefaults), PollingInterval enum, BluetoothDevice.isMonitored]
  affects: [BluetoothService (orchestration), BatteryService (HID layer merge), BluetoothDevice (isMonitored field)]
tech_stack:
  added: [CoreBluetooth framework link]
  patterns: [CBCentralManagerDelegate+CBPeripheralDelegate one-shot read, IOHIDManager non-exclusive open, withCheckedContinuation async bridge, UserDefaults Set<String> persistence]
key_files:
  created:
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Services/BLEService.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Models/PollingInterval.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Settings/DevicePreferences.swift
  modified:
    - BTBatteryMonitor/Package.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Models/BluetoothDevice.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Services/BatteryService.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Services/BluetoothService.swift
decisions:
  - "BLEService uses Task.detached capture pattern to avoid Swift 5 @MainActor isolation warning when accessing bleService from nonisolated context"
  - "IOHIDDeviceGetValue requires Unmanaged<IOHIDValue> (non-optional) — dummy IOHIDValueCreateWithIntegerValue used as initial value storage"
  - "IOKit layer 1 takes priority over HID Generic layer 2 and BLE layer 3 on product name collision (merging strategy)"
metrics:
  duration_minutes: 4
  completed_date: "2026-03-27"
  tasks_completed: 2
  files_created: 3
  files_modified: 4
---

# Phase 03 Plan 01: BLE Extension + Service Layer Summary

**One-liner:** BLEService (CoreBluetooth GATT 0x180F) + IOHIDManager HID Generic battery layer + UserDefaults DevicePreferences + PollingInterval enum integrated into 3-source battery orchestration.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | BLEService + PollingInterval + DevicePreferences + BluetoothDevice.isMonitored | 4d5e8b5 | Package.swift, BLEService.swift (new), PollingInterval.swift (new), DevicePreferences.swift (new), BluetoothDevice.swift |
| 2 | BatteryService HID Generic layer + BluetoothService orchestration | 1023e80 | BatteryService.swift, BluetoothService.swift |

## What Was Built

### BLEService.swift (new)
CoreBluetooth one-shot BLE GATT Battery Service reader. Uses `retrieveConnectedPeripherals(withServices: [batteryServiceUUID])` (no scan) on a `.global(qos: .userInitiated)` CBCentralManager queue. 5-second timeout via DispatchWorkItem. Calls completion with `[product_name: battery_percent]` map.

### PollingInterval.swift (new)
`enum PollingInterval: Int` with cases 1/2/5/10/30 minutes. Default = 5 minutes (300s). `from(userDefaults:)` factory reads from `com.btbatterymonitor.pollingInterval` key. Replaces the hardcoded 60-second timer in BluetoothService.

### Settings/DevicePreferences.swift (new)
Singleton `DevicePreferences.shared` backed by `UserDefaults.standard`. Stores monitored device names as `[String]` under `com.btbatterymonitor.monitoredDevices`. First-install default: all devices monitored (key missing = true). `pollingInterval` computed property reads/writes `PollingInterval` via raw value.

### BatteryService.swift (modified)
Added `probeHIDGenericDevice()` — uses IOHIDManager with UsagePage=6/Usage=0x20 matching. Filters to Bluetooth transport only. Reads cached IOHIDValue via `IOHIDDeviceGetValue`. Skips value=0 (stale initial cache). `fetchBatteryLevels()` now merges: IOKit (layer 1) > HID Generic (layer 2), IOKit priority on collision.

### BluetoothService.swift (modified)
- Added `bleService: BLEService` property
- `schedulePolling()` → `schedulePolling(interval:)` using `PollingInterval` (default from UserDefaults), timer invalidated before rescheduling (Pitfall 6)
- `refresh()` now runs 3-layer battery collection: IOKit+HID Generic (sync) + BLE GATT (async via withCheckedContinuation), merged IOKit-priority
- `buildDeviceList()` applies `DevicePreferences.isMonitored()` filter + sets `isMonitored` on each device
- Added `updatePollingInterval()` for settings UI

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed IOHIDDeviceGetValue Swift type mismatch**
- **Found during:** Task 2 build
- **Issue:** `IOHIDDeviceGetValue` requires `UnsafeMutablePointer<Unmanaged<IOHIDValue>>` but plan code used `IOHIDValue?` (optional direct type) — Swift compiler error
- **Fix:** Used `var valueStorage: Unmanaged<IOHIDValue>` with a dummy `IOHIDValueCreateWithIntegerValue` initial value, then called `takeUnretainedValue()` after successful GetValue
- **Files modified:** BatteryService.swift
- **Commit:** 1023e80

**2. [Rule 1 - Bug] Fixed @MainActor isolation warning for BLEService in Task.detached**
- **Found during:** Task 2 build
- **Issue:** `bleService` is a `@MainActor`-isolated property. Accessing it directly inside `Task.detached` (nonisolated context) triggers Swift 5 actor isolation warning (would be error in Swift 6 mode)
- **Fix:** Captured `bleService` into a local constant (`let ble = self.bleService`) on the main actor before entering `Task.detached`, then used the captured value inside the detached task
- **Files modified:** BluetoothService.swift
- **Commit:** 1023e80

## Known Stubs

None. All three battery read layers are functionally wired. HID Generic layer will return empty results if no matching devices are present at runtime (normal — not a stub).

## Self-Check: PASSED

- FOUND: BTBatteryMonitor/Sources/BTBatteryMonitor/Services/BLEService.swift
- FOUND: BTBatteryMonitor/Sources/BTBatteryMonitor/Models/PollingInterval.swift
- FOUND: BTBatteryMonitor/Sources/BTBatteryMonitor/Settings/DevicePreferences.swift
- FOUND commit 4d5e8b5 (Task 1)
- FOUND commit 1023e80 (Task 2)
- swift build: Build complete
