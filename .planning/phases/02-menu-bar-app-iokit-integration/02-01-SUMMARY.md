---
phase: 02-menu-bar-app-iokit-integration
plan: "01"
subsystem: bluetooth-service
tags: [swift, iokit, iobluetooth, spm, macos, battery, observable-object]

# Dependency graph
requires: []
provides:
  - "BTBatteryMonitor Swift Package with IOKit + IOBluetooth service layer"
  - "BluetoothDevice model (Identifiable, Comparable, batteryPercent: Int?)"
  - "DeviceType enum with CoD bitmask factory and SF Symbol mapping"
  - "BatteryService.fetchBatteryLevels() -> [String:Int] via IOKit probe"
  - "BluetoothService @ObservableObject with @Published devices and startMonitoring()"
affects:
  - "02-02 (menu bar UI consumes BluetoothService as @ObservedObject)"
  - "02-03 (AppDelegate wires BluetoothService.startMonitoring)"

# Tech tracking
tech-stack:
  added: [Swift Package Manager, IOKit, IOBluetooth, AppKit, Combine]
  patterns:
    - "@MainActor class with Task.detached for background IOKit reads"
    - "ObservableObject + @Published for reactive device list"
    - "IOBluetoothDevice connect/disconnect notification registration"

key-files:
  created:
    - BTBatteryMonitor/Package.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Models/BluetoothDevice.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Models/DeviceType.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Services/BatteryService.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Services/BluetoothService.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/main.swift
  modified:
    - .gitignore (added BTBatteryMonitor/.build/)

key-decisions:
  - "IOKit probe ported verbatim from Phase 1 IOKitProbe.swift (D-06)"
  - "BluetoothService uses @MainActor class with Task.detached for IOKit calls to avoid Pitfall 5 (main thread blocking)"
  - "60-second polling timer added for periodic battery refresh alongside connect/disconnect notifications"
  - "Comparable nil-last sort on BluetoothDevice implements D-03/D-04 sort order"
  - "main.swift placeholder keeps package as executable target for Plan 02-03 AppDelegate integration"

patterns-established:
  - "Pattern 1: BatteryService is a pure struct; BluetoothService is the @ObservableObject that drives UI"
  - "Pattern 2: DeviceType.from(classOfDevice:) takes UInt32 — callers cast with UInt32(device.classOfDevice)"
  - "Pattern 3: Battery name matching is best-effort by product name string — IOKit Product key may differ from IOBluetooth name"

requirements-completed: [DISC-01, DISC-02, DISC-03, BATT-01, BATT-04]

# Metrics
duration: 3min
completed: 2026-03-27
---

# Phase 2 Plan 01: Swift Package foundation + IOKit battery service + IOBluetooth device discovery

**BTBatteryMonitor Swift Package built with BluetoothDevice/DeviceType models, IOKit battery probe ported from Phase 1, and @ObservableObject BluetoothService driving connected device discovery with connect/disconnect notifications**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-27T03:41:18Z
- **Completed:** 2026-03-27T03:44:36Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Swift Package compiles cleanly (swift build exits 0) with IOKit + IOBluetooth + AppKit linker flags
- BluetoothDevice model (Identifiable, Comparable) with batteryPercent: Int? — nil sorts last per D-03/D-04
- DeviceType CoD bitmask factory: 0x04=headset, 0x05+0x02=keyboard, 0x05+0x05=mouse
- BatteryService contains verbatim IOKit probe from Phase 1 (fetchBatteryLevels() -> [String:Int])
- BluetoothService @ObservableObject wires IOBluetoothDevice discovery, battery merge, connect/disconnect notifications (DISC-03), and 60s polling; IOKit reads dispatched off main thread via Task.detached

## Task Commits

Each task was committed atomically:

1. **Task 1: Swift Package scaffold + data models** - `4404b68` (feat)
2. **Task 2: BatteryService + BluetoothService** - `29ebd56` (feat)

## Files Created/Modified

- `BTBatteryMonitor/Package.swift` - SPM manifest: macOS 13+, links IOKit/IOBluetooth/AppKit
- `BTBatteryMonitor/Sources/BTBatteryMonitor/Models/BluetoothDevice.swift` - Canonical device model, Comparable nil-last sort
- `BTBatteryMonitor/Sources/BTBatteryMonitor/Models/DeviceType.swift` - CoD bitmask enum + SF Symbol mapping
- `BTBatteryMonitor/Sources/BTBatteryMonitor/Services/BatteryService.swift` - IOKit probe (verbatim from Phase 1) + fetchBatteryLevels()
- `BTBatteryMonitor/Sources/BTBatteryMonitor/Services/BluetoothService.swift` - @MainActor ObservableObject, IOBluetooth discovery, connect/disconnect notifications
- `BTBatteryMonitor/Sources/BTBatteryMonitor/main.swift` - Placeholder executable entry point
- `.gitignore` - Added BTBatteryMonitor/.build/

## Decisions Made

- IOKit probe ported verbatim from Phase 1 IOKitProbe.swift (D-06 — no rewrite)
- BluetoothService uses Task.detached for background IOKit reads to keep main thread free (Pitfall 5)
- 60-second polling timer ensures battery levels stay fresh beyond connect events
- main.swift placeholder added so executable target compiles; AppDelegate integration deferred to Plan 02-03

## Deviations from Plan

None — plan executed exactly as written. main.swift entry point was implied by the executable target requirement and added without deviation.

## Issues Encountered

None — swift build succeeded on first attempt for both tasks.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- BluetoothDevice model and BluetoothService @ObservableObject ready for Plan 02-02 SwiftUI popover views
- Contract: `BluetoothService.devices: [BluetoothDevice]` is the data source for the UI layer
- Contract: `BluetoothService.startMonitoring()` called from AppDelegate in Plan 02-03
- No blockers

## Self-Check: PASSED

- All 6 source files created and verified to exist
- Both task commits confirmed: 4404b68 (Task 1), 29ebd56 (Task 2)
- swift build exits 0
- All acceptance criteria verified with grep

---
*Phase: 02-menu-bar-app-iokit-integration*
*Completed: 2026-03-27*
