---
phase: 02-menu-bar-app-iokit-integration
plan: 03
subsystem: infra
tags: [swift, macos, app-bundle, codesign, entitlements, info-plist, bluetooth, sandbox]

# Dependency graph
requires:
  - phase: 02-menu-bar-app-iokit-integration/02-01
    provides: BluetoothDevice model, BatteryService (IOKit), BluetoothService (IOBluetooth)
  - phase: 02-menu-bar-app-iokit-integration/02-02
    provides: AppDelegate, StatusBarController, PopoverView + SwiftUI UI layer

provides:
  - Info.plist with LSUIElement, NSBluetoothAlwaysUsageDescription, LSMinimumSystemVersion
  - BTBatteryMonitor.entitlements with App Sandbox + Bluetooth device entitlement
  - build.sh producing ad-hoc signed BTBatteryMonitor.app bundle
  - Package.swift updated with -sectcreate linker flag for TCC Info.plist embedding
  - Complete runnable BTBatteryMonitor.app (checkpoint pending human launch verification)

affects: [02-04, phase-03]

# Tech tracking
tech-stack:
  added: [codesign ad-hoc signing, macOS .app bundle structure, -sectcreate linker flag]
  patterns:
    - Xcode-less .app bundle: swift build -> manual Contents/MacOS/ structure -> codesign
    - Info.plist dual embedding: Contents/Info.plist for .app bundle + -sectcreate for binary TCC
    - Ad-hoc codesign with --options runtime and --entitlements for local sandbox testing

key-files:
  created:
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Resources/Info.plist
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Resources/BTBatteryMonitor.entitlements
    - BTBatteryMonitor/build.sh
  modified:
    - BTBatteryMonitor/Package.swift (swiftSettings -sectcreate added)
    - .gitignore (BTBatteryMonitor/*.app/ excluded)

key-decisions:
  - "Info.plist embedded via both Contents/Info.plist (for .app bundle) and -sectcreate linker flag (for direct binary TCC access — Phase 1 pattern)"
  - "Ad-hoc codesign (--sign -) sufficient for local dev; App Store requires Developer ID"
  - "Package.swift swiftSettings must precede linkerSettings — Swift compiler ordering constraint"

patterns-established:
  - "Pattern: Xcode-less build via build.sh — swift build + manual .app dir + codesign"
  - "Pattern: -sectcreate __TEXT __info_plist for TCC NSBluetoothAlwaysUsageDescription recognition"

requirements-completed: [LIFE-02]

# Metrics
duration: 8min
completed: 2026-03-27
---

# Phase 02 Plan 03: Info.plist, Entitlements, and Build Script Summary

**Info.plist (LSUIElement + NSBluetoothAlwaysUsageDescription) + entitlements (sandbox+bluetooth) + Xcode-less build.sh producing ad-hoc signed BTBatteryMonitor.app**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-27T04:15:04Z
- **Completed:** 2026-03-27T04:23:00Z
- **Tasks:** 1 of 2 (Task 2 is a human-verify checkpoint — pending)
- **Files modified:** 5

## Accomplishments

- Created Info.plist with LSUIElement=YES (no Dock icon), NSBluetoothAlwaysUsageDescription (Korean), bundle ID, and LSMinimumSystemVersion=13.0
- Created BTBatteryMonitor.entitlements with com.apple.security.app-sandbox and com.apple.security.device.bluetooth (D-08/FEAS-02)
- Created build.sh that builds, bundles, and ad-hoc signs BTBatteryMonitor.app (exits 0, codesign --verify passes)
- Updated Package.swift to embed Info.plist via -sectcreate for TCC recognition when binary run directly (Phase 1 pattern)

## Task Commits

1. **Task 1: Info.plist, entitlements, and build script** - `80aa587` (feat)
2. **Task 2: Human verify — menu bar app launches and popover works** - PENDING (checkpoint)

## Files Created/Modified

- `BTBatteryMonitor/Sources/BTBatteryMonitor/Resources/Info.plist` - App metadata: LSUIElement, bundle ID, NSBluetoothAlwaysUsageDescription, LSMinimumSystemVersion
- `BTBatteryMonitor/Sources/BTBatteryMonitor/Resources/BTBatteryMonitor.entitlements` - Sandbox + Bluetooth device entitlements
- `BTBatteryMonitor/build.sh` - Xcode-less build script: swift build -> .app bundle -> codesign (executable, exits 0)
- `BTBatteryMonitor/Package.swift` - Added swiftSettings with -sectcreate for Info.plist TCC embedding
- `.gitignore` - Added BTBatteryMonitor/*.app/ to exclude generated app bundle

## Decisions Made

- Info.plist is copied to both Contents/Info.plist (required for .app bundle macOS lookup) and embedded via -sectcreate (required for TCC Bluetooth permission when binary invoked directly)
- Ad-hoc codesign (`--sign -`) is sufficient for local dev/test; Apple Developer ID needed for distribution
- `--options runtime` flag included to enable Hardened Runtime with sandbox entitlements

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Package.swift swiftSettings/linkerSettings parameter order**
- **Found during:** Task 1 (build.sh run)
- **Issue:** Swift package manifest requires `swiftSettings` to precede `linkerSettings`; the plan specified adding swiftSettings after linkerSettings, causing a manifest compilation error
- **Fix:** Reordered parameters: swiftSettings placed before linkerSettings in executableTarget
- **Files modified:** BTBatteryMonitor/Package.swift
- **Verification:** swift build exits 0 after reorder
- **Committed in:** 80aa587 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug — parameter ordering)
**Impact on plan:** Essential fix for build to succeed. No scope creep.

## Issues Encountered

- Package.swift manifest ordering: `swiftSettings` must come before `linkerSettings` in Swift Package Manager — compiler enforces argument label ordering matching the API declaration. Fixed immediately.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- BTBatteryMonitor.app builds and passes codesign --verify
- Human checkpoint (Task 2) required: user must run `bash build.sh && open BTBatteryMonitor.app` to confirm menu bar icon appears and popover opens
- After checkpoint approval: Phase 02 is complete, Phase 03 (BLE GATT / device selection) can proceed

## Known Stubs

None - all files are complete implementations. Task 2 is a verification checkpoint, not a stub.

---
*Phase: 02-menu-bar-app-iokit-integration*
*Completed: 2026-03-27 (Task 2 checkpoint pending)*
