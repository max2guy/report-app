---
phase: 02-menu-bar-app-iokit-integration
plan: "02"
subsystem: menu-bar-ui
tags: [swift, swiftui, appkit, nsstatusitem, nspopover, combine, macos, menu-bar]

# Dependency graph
requires:
  - "02-01: BluetoothService ObservableObject + BluetoothDevice model"
provides:
  - "AppDelegate with .accessory activation policy (LIFE-02)"
  - "StatusBarController with NSStatusItem + NSPopover (UI-01, UI-03)"
  - "PopoverView / HeaderView / DeviceRowView SwiftUI views (UI-04, D-02, D-04, D-05)"
  - "Full app entry point via NSApplicationMain in main.swift"
affects:
  - "BTBatteryMonitor/Package.swift (added SwiftUI linker framework)"

# Tech stack
added:
  - "SwiftUI (NSHostingController wrapping PopoverView)"
  - "Combine (AnyCancellable sink on BluetoothService.$devices)"
patterns:
  - "AppKit + SwiftUI hybrid: NSHostingController<PopoverView> as NSPopover.contentViewController"
  - "@EnvironmentObject BluetoothService bridged from AppDelegate via .environmentObject()"
  - "NSStatusItem with variableLength + NSStatusBarButton image + title combo"
  - "@MainActor StatusBarController holding Combine subscription set"

# Key files
created:
  - BTBatteryMonitor/Sources/BTBatteryMonitor/main.swift (replaced placeholder)
  - BTBatteryMonitor/Sources/BTBatteryMonitor/App/AppDelegate.swift
  - BTBatteryMonitor/Sources/BTBatteryMonitor/MenuBar/StatusBarController.swift
  - BTBatteryMonitor/Sources/BTBatteryMonitor/Views/PopoverView.swift
  - BTBatteryMonitor/Sources/BTBatteryMonitor/Views/HeaderView.swift
  - BTBatteryMonitor/Sources/BTBatteryMonitor/Views/DeviceRowView.swift
modified:
  - BTBatteryMonitor/Package.swift (added SwiftUI to linkerSettings)

# Decisions
key-decisions:
  - "AppDelegate not annotated @MainActor — BluetoothService init deferred to applicationDidFinishLaunching to avoid actor isolation error from main.swift"
  - "main.swift stays at Sources root (not moved to App/) — Swift compiler requires exactly one main.swift per target at any path"
  - "StatusBarController is @MainActor final class owning Combine AnyCancellable set"
  - "PopoverView stub committed with Task 1 to allow incremental build verification before Task 2 full implementation"

# Metrics
duration: ~10 minutes
completed: 2026-03-27
tasks_completed: 2
files_created: 6
files_modified: 2
---

# Phase 02 Plan 02: Menu Bar UI Layer Summary

AppKit + SwiftUI presentation layer: NSStatusItem menu bar icon, NSPopover with SwiftUI views, wired to BluetoothService from Plan 01.

## What Was Built

The full UI layer for BT Battery Monitor:

- **main.swift** — NSApplicationMain entry point (no `@main` attribute — compiler-prohibited in main.swift)
- **AppDelegate** — `.accessory` activation policy (no Dock icon, LIFE-02), creates BluetoothService + StatusBarController
- **StatusBarController** — NSStatusItem with variable-length button; Combine sink on `BluetoothService.$devices` updates icon (battery.25/50/100/bluetooth) and text (lowest %, "--" loading state); NSPopover with `.transient` behavior
- **PopoverView** — SwiftUI root: HeaderView + LazyVStack in ScrollView; empty state when no devices
- **HeaderView** — `"BT Battery Monitor  •  N개 장치"` (exact copy), 13pt semibold, controlBackgroundColor surface
- **DeviceRowView** — SF Symbol type icon + device name + 80pt ProgressView capsule + 12pt battery % (color-coded); no-battery variant with tertiaryLabelColor + "배터리 정보 없음"

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] @MainActor actor isolation error on AppDelegate**
- **Found during:** Task 1 build
- **Issue:** Plan's `AppDelegate` had `let bluetoothService = BluetoothService()` as a stored property. Since `BluetoothService` is `@MainActor`, Swift 5.9 raises an error for calling its initializer from a non-isolated context (class property init runs outside main actor). Marking `AppDelegate` as `@MainActor` pushed the error to `main.swift` where `AppDelegate()` is called before the main actor is available.
- **Fix:** Removed stored property initializer; moved `BluetoothService()` init to `applicationDidFinishLaunching(_:)` which runs on main thread. `AppDelegate` is not annotated `@MainActor` (NSApplicationDelegate callbacks are main-thread by contract).
- **Files modified:** `App/AppDelegate.swift`
- **Commit:** 8749023

**2. [Rule 2 - Missing functionality] SwiftUI framework not in Package.swift**
- **Found during:** Task 1 — StatusBarController.swift uses NSHostingController (SwiftUI)
- **Fix:** Added `.linkedFramework("SwiftUI")` to Package.swift linkerSettings
- **Files modified:** `BTBatteryMonitor/Package.swift`
- **Commit:** 8749023

**3. [Rule 3 - Blocking] PopoverView stub needed for Task 1 build**
- **Found during:** Task 1 — StatusBarController references PopoverView before Task 2
- **Fix:** Created minimal stub PopoverView.swift with `@EnvironmentObject` to unblock compilation, replaced with full implementation in Task 2
- **Files modified:** `Views/PopoverView.swift`
- **Commit:** 8749023 (stub), 2a15e64 (full)

## Known Stubs

None — all views are fully implemented with real data bindings through `@EnvironmentObject BluetoothService`.

## Verification Results

```
$ swift build
Build complete!

$ grep -r "setActivationPolicy(.accessory)" BTBatteryMonitor/Sources/
→ App/AppDelegate.swift

$ grep -r "배터리 정보 없음" BTBatteryMonitor/Sources/
→ Views/DeviceRowView.swift (display text + accessibilityLabel)

$ grep -r "\.transient" BTBatteryMonitor/Sources/
→ MenuBar/StatusBarController.swift
```

All 4 verification checks from plan passed.

## Self-Check: PASSED

- `BTBatteryMonitor/Sources/BTBatteryMonitor/App/AppDelegate.swift` — EXISTS
- `BTBatteryMonitor/Sources/BTBatteryMonitor/MenuBar/StatusBarController.swift` — EXISTS
- `BTBatteryMonitor/Sources/BTBatteryMonitor/Views/PopoverView.swift` — EXISTS
- `BTBatteryMonitor/Sources/BTBatteryMonitor/Views/HeaderView.swift` — EXISTS
- `BTBatteryMonitor/Sources/BTBatteryMonitor/Views/DeviceRowView.swift` — EXISTS
- Task 1 commit 8749023 — EXISTS
- Task 2 commit 2a15e64 — EXISTS
- swift build exits 0 — CONFIRMED

---
*Phase: 02-menu-bar-app-iokit-integration*
*Completed: 2026-03-27*
