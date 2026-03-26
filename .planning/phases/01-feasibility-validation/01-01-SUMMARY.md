---
phase: 01-feasibility-validation
plan: 01
subsystem: infra
tags: [swift, iokit, swift-package-manager, bluetooth, cli, battery]

# Dependency graph
requires: []
provides:
  - bt-battery-probe Swift Package Manager executable CLI tool
  - IOKitProbe layer scanning AppleDeviceManagementHIDEventService and IOBluetoothDevice for BatteryPercent
  - CLI entry point with --iokit, --ble, --sandbox flag dispatch
  - Stub placeholders for BLEProbe (Plan 02) and SandboxProbe (Plan 03)
affects: [01-02, 01-03, phase-02]

# Tech tracking
tech-stack:
  added: [swift-argument-parser 1.7.1, IOKit framework, IOBluetooth framework, CoreBluetooth framework]
  patterns:
    - Swift Package Manager executable with system framework linkerSettings
    - IOServiceMatching + IOIteratorNext pattern for IORegistry traversal
    - CFProperties dict cast for reading BatteryPercent and Product keys
    - ParsableCommand.main() entry point in main.swift (not @main due to Swift restriction)

key-files:
  created:
    - bt-battery-probe/Package.swift
    - bt-battery-probe/Sources/bt-battery-probe/main.swift
    - bt-battery-probe/Sources/bt-battery-probe/IOKitProbe.swift
    - bt-battery-probe/Sources/bt-battery-probe/BLEProbe.swift
    - bt-battery-probe/Sources/bt-battery-probe/SandboxProbe.swift
    - bt-battery-probe/Package.resolved
  modified:
    - .gitignore (added bt-battery-probe/.build/)

key-decisions:
  - "Used ParsableCommand.main() instead of @main attribute in main.swift — @main is not allowed when file is named main.swift in Swift"
  - "Dual IOKit matching strategy: AppleDeviceManagementHIDEventService (primary) + IOBluetoothDevice (secondary) with deduplication by product name"
  - "FEAS-01 preliminary finding: 0/3 devices expose BatteryPercent via IOKit on this machine (internal keyboard + 2 unknown BT devices found)"

patterns-established:
  - "Pattern 1: IOKit probe uses IOServiceGetMatchingServices + IOIteratorNext + CFProperties cast"
  - "Pattern 2: CLI stubs for unimplemented probes print explicit plan reference (e.g., 'see Plan 02')"

requirements-completed: [FEAS-01]

# Metrics
duration: 3min
completed: 2026-03-27
---

# Phase 01 Plan 01: Swift Package + IOKitProbe Summary

**bt-battery-probe Swift CLI scaffolded with IOKit IORegistry scan: 3 devices found via AppleDeviceManagementHIDEventService and IOBluetoothDevice, 0 expose BatteryPercent (FEAS-01 initial data point)**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-26T22:02:39Z
- **Completed:** 2026-03-26T22:05:17Z
- **Tasks:** 1 of 1
- **Files modified:** 7

## Accomplishments

- Swift Package Manager executable project created at `bt-battery-probe/` with IOKit, IOBluetooth, CoreBluetooth linkerSettings and swift-argument-parser 1.7.1 dependency
- IOKitProbe.swift implements dual-matching strategy (AppleDeviceManagementHIDEventService + IOBluetoothDevice) with deduplication and per-device BatteryPercent reporting
- main.swift CLI entry dispatches --iokit, --ble, --sandbox flags; BLEProbe and SandboxProbe are stubs referencing Plan 02 and 03

## IOKit Probe Output (FEAS-01 result)

```
=== IOKit IORegistry Probe (FEAS-01) ===
[IOKit] Found 3 device(s):
  Product: Apple Internal Keyboard / Trackpad, BatteryPercent: not found (via AppleDeviceManagementHIDEventService)
  Product: Unknown, BatteryPercent: not found (via IOBluetoothDevice)
  Product: Unknown, BatteryPercent: not found (via IOBluetoothDevice)
[IOKit] FEAS-01 result: 0/3 device(s) expose BatteryPercent
```

**FEAS-01 preliminary finding:** IOKit successfully enumerates HID and Bluetooth devices. None of the currently connected devices expose `BatteryPercent` via IORegistry on this machine. The keyboard does not appear in the IORegistry (only "Apple Internal Keyboard / Trackpad" and two unknown IOBluetoothDevice entries are listed). This suggests the user's Bluetooth keyboard may not expose battery data via IOKit — consistent with Pitfall 3 from research. BLE GATT (Plan 02) will probe this further.

## Task Commits

1. **Task 1: Scaffold Swift package and implement IOKitProbe** - `6bb1c7f` (feat)
2. **Gitignore update** - `13bfaa9` (chore)

## Files Created/Modified

- `bt-battery-probe/Package.swift` - SPM manifest with IOKit/IOBluetooth/CoreBluetooth linkerSettings and swift-argument-parser dep
- `bt-battery-probe/Sources/bt-battery-probe/IOKitProbe.swift` - IORegistry battery scanner, probeIOKit() + printIOKitResults()
- `bt-battery-probe/Sources/bt-battery-probe/main.swift` - CLI entry with --iokit/--ble/--sandbox flags via ParsableCommand
- `bt-battery-probe/Sources/bt-battery-probe/BLEProbe.swift` - Stub for Plan 02
- `bt-battery-probe/Sources/bt-battery-probe/SandboxProbe.swift` - Stub for Plan 03
- `bt-battery-probe/Package.resolved` - Resolved swift-argument-parser 1.7.1
- `.gitignore` - Added bt-battery-probe/.build/

## Decisions Made

- Used `ParsableCommand.main()` call at end of `main.swift` instead of `@main` attribute — Swift does not allow `@main` in a file named `main.swift` (compiler error: "'main' attribute cannot be used in a module that contains top-level code")
- Dual IOKit matching: AppleDeviceManagementHIDEventService covers BT HID devices; IOBluetoothDevice covers Classic BT with product deduplication
- IOKitResult struct uses optional `batteryPercent: Int?` to distinguish "0%" from "not found"

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed @main from main.swift, added ParsableCommand.main() call instead**
- **Found during:** Task 1 (first build attempt)
- **Issue:** Plan specified `@main struct BTBatteryProbe: ParsableCommand` in `main.swift`. Swift compiler rejects `@main` in a file named `main.swift` with error: "'main' attribute cannot be used in a module that contains top-level code"
- **Fix:** Removed `@main` attribute; added `BTBatteryProbe.main()` call at end of file — the standard ArgumentParser pattern for main.swift entry points
- **Files modified:** bt-battery-probe/Sources/bt-battery-probe/main.swift
- **Verification:** `swift build` exits 0 with "Build complete!"
- **Committed in:** 6bb1c7f (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in plan's Swift code pattern)
**Impact on plan:** Required fix for compilation. No behavioral change — ParsableCommand.main() is functionally equivalent to @main for CLI executables.

## Issues Encountered

- `swift package init --type executable` created files in the current directory (not `bt-battery-probe/` subdirectory). Moved Package.swift, Sources/, and Tests/ into `bt-battery-probe/` with `mv` and removed the generated Tests/ directory (not needed for this probe).

## Known Stubs

- `bt-battery-probe/Sources/bt-battery-probe/BLEProbe.swift` — `runBLEProbe()` prints placeholder message. Intentional — Plan 02 implements this
- `bt-battery-probe/Sources/bt-battery-probe/SandboxProbe.swift` — `runSandboxProbe()` prints placeholder message. Intentional — Plan 03 implements this

## Next Phase Readiness

- Plan 02 (BLE GATT probe) can immediately implement `runBLEProbe()` in BLEProbe.swift — entry point already wired in main.swift
- Plan 03 (Sandbox probe) can immediately implement `runSandboxProbe()` in SandboxProbe.swift
- IOKitProbe code is reusable foundation per D-03 — probeIOKit() function is clean and independent
- FEAS-01 result indicates keyboard may not expose BatteryPercent; BLE scan (Plan 02) may reveal it via GATT 0x180F, or D-05 scope expansion applies

## Self-Check: PASSED

- bt-battery-probe/Package.swift: FOUND
- bt-battery-probe/Sources/bt-battery-probe/IOKitProbe.swift: FOUND
- bt-battery-probe/Sources/bt-battery-probe/main.swift: FOUND
- .planning/phases/01-feasibility-validation/01-01-SUMMARY.md: FOUND
- commit 6bb1c7f: FOUND

---
*Phase: 01-feasibility-validation*
*Completed: 2026-03-27*
