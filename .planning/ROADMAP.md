# Roadmap: BT Battery Monitor

## Overview

BT Battery Monitor delivers a macOS menu bar app for real-time Bluetooth device battery monitoring. The roadmap starts with a critical feasibility gate (can we read battery from the target devices?), then builds a complete working app with IOKit integration, extends coverage with BLE and user device management, and finishes with visual polish and system lifecycle integration.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Feasibility Validation** - Prove battery reading is technically viable before building the app (completed 2026-03-27)
- [ ] **Phase 2: Menu Bar App + IOKit Integration** - Working menu bar app showing device battery levels via IOKit
- [ ] **Phase 3: BLE Extension + Device Management** - Extend battery coverage with CoreBluetooth and add user device controls
- [ ] **Phase 4: Polish + App Lifecycle** - Color-coded battery indicators, auto-launch, and sleep/wake resilience

## Phase Details

### Phase 1: Feasibility Validation
**Goal**: Confirm that Bluetooth device battery data can be read programmatically, establishing a go/no-go gate before significant development
**Depends on**: Nothing (first phase)
**Requirements**: FEAS-01, FEAS-02, FEAS-03
**Success Criteria** (what must be TRUE):
  1. Running `ioreg` shows battery level data for at least one connected Bluetooth device
  2. A Swift CLI prototype can read battery level from IOKit IORegistry for a connected device
  3. App Sandbox compatibility with IOKit battery reads is confirmed or a distribution workaround is documented
  4. BLE GATT Battery Service (0x180F) scan results are documented for connected devices
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Swift package scaffold + IOKit battery probe (FEAS-01)
- [x] 01-02-PLAN.md — BLE GATT 0x180F battery probe (FEAS-03)
- [x] 01-03-PLAN.md — App Sandbox test + Phase 1 findings report (FEAS-02, D-09 distribution decision)

### Phase 2: Menu Bar App + IOKit Integration
**Goal**: Users can see their Bluetooth devices and battery levels in a fully functional menu bar app using IOKit — targeting Bluetooth mice, headsets, trackpads, and other devices that expose standard battery data (D-05: keyboard scope excluded — uses proprietary FN+B indicator, not standard HID/BLE battery profile)
**Depends on**: Phase 1
**Requirements**: DISC-01, DISC-02, DISC-03, BATT-01, BATT-04, UI-01, UI-03, UI-04, LIFE-02
**Success Criteria** (what must be TRUE):
  1. A menu bar icon with battery percentage is visible in the macOS menu bar
  2. Clicking the menu bar icon opens a popover listing all connected Bluetooth devices with name, type icon, battery level, and connection status
  3. Device connection/disconnection is reflected in the UI without restarting the app
  4. Devices that do not expose battery data show "battery info unavailable" instead of incorrect values
  5. The app runs as a menu-bar-only agent (no Dock icon)
**Plans**: TBD
**UI hint**: yes

### Phase 3: BLE Extension + Device Management
**Goal**: Users can monitor additional devices via BLE and choose which devices to track
**Depends on**: Phase 2
**Requirements**: BATT-02, BATT-03, MGMT-01, MGMT-02, MGMT-03
**Success Criteria** (what must be TRUE):
  1. Devices exposing BLE GATT Battery Service (0x180F) show battery levels even if IOKit does not report them
  2. Battery levels refresh automatically at a configurable interval (default 5 minutes)
  3. User can toggle individual devices on/off for monitoring, and the selection persists across app restarts
  4. User can change the polling interval from a settings view
**Plans**: TBD
**UI hint**: yes

### Phase 4: Polish + App Lifecycle
**Goal**: The app feels production-ready with visual battery indicators and seamless system integration
**Depends on**: Phase 3
**Requirements**: UI-02, LIFE-01, LIFE-03
**Success Criteria** (what must be TRUE):
  1. Battery icon/text color changes based on level: green (70%+), yellow (30-70%), red (below 30%)
  2. The app launches automatically on macOS login without manual setup
  3. After macOS sleep/wake, Bluetooth device states recover correctly and battery levels update
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Feasibility Validation | 3/3 | Complete   | 2026-03-27 |
| 2. Menu Bar App + IOKit Integration | 0/0 | Not started | - |
| 3. BLE Extension + Device Management | 0/0 | Not started | - |
| 4. Polish + App Lifecycle | 0/0 | Not started | - |
