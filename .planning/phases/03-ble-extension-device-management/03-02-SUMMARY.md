---
phase: 03-ble-extension-device-management
plan: "02"
subsystem: settings-ui
tags: [settings, NSPanel, SwiftUI, device-management, polling-interval]
dependency_graph:
  requires: [03-01]
  provides: [settings-ui, device-toggle, polling-picker]
  affects: [HeaderView, DeviceRowView, AppDelegate]
tech_stack:
  added: [SettingsController, SettingsView]
  patterns: [NSPanel-settings, NotificationCenter-decoupling, MainActor.assumeIsolated]
key_files:
  created:
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Settings/SettingsController.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Settings/SettingsView.swift
  modified:
    - BTBatteryMonitor/Sources/BTBatteryMonitor/App/AppDelegate.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Views/HeaderView.swift
    - BTBatteryMonitor/Sources/BTBatteryMonitor/Views/DeviceRowView.swift
decisions:
  - "NSPanel + NSWindowDelegate for settings window — SettingsLink unreliable in LSUIElement apps"
  - "NotificationCenter 'OpenSettings' for HeaderView→AppDelegate decoupling — avoids injecting SettingsController into SwiftUI hierarchy"
  - "MainActor.assumeIsolated in applicationDidFinishLaunching — avoids @MainActor on AppDelegate (conflicts with main.swift non-isolated init)"
  - "macOS 13 compatible onChange single-param closure — two-param variant requires macOS 14+"
metrics:
  duration: 3min
  completed_date: "2026-03-27"
  tasks_completed: 2
  files_changed: 5
requirements: [MGMT-01, MGMT-03]
---

# Phase 03 Plan 02: Settings UI + Device Monitoring Toggle Summary

**One-liner:** NSPanel 설정 창(폴링 간격 Picker) + DeviceRowView 모니터링 Toggle로 MGMT-01/MGMT-03 UI 노출 완료

## What Was Built

Plan 01에서 구현된 `DevicePreferences` + `BluetoothService` API를 Settings UI로 연결했다.

- **SettingsController** (`Settings/SettingsController.swift`): NSPanel 기반 설정 창 컨트롤러. `showSettings()` 호출 시 NSPanel 생성 + `.regular` activation policy 전환으로 전면 표시. `windowWillClose` delegate에서 `.accessory` 복원.
- **SettingsView** (`Settings/SettingsView.swift`): SwiftUI Form — `PollingInterval` Picker. `onChange` → `bluetoothService.updatePollingInterval()`.
- **AppDelegate** (`App/AppDelegate.swift`): `settingsController` 프로퍼티 추가, `MainActor.assumeIsolated` 블록에서 초기화. `NotificationCenter` "OpenSettings" 리스너 등록.
- **HeaderView** (`Views/HeaderView.swift`): gearshape SF Symbol 버튼 추가. 탭 시 `NotificationCenter.default.post(name: "OpenSettings")`.
- **DeviceRowView** (`Views/DeviceRowView.swift`): `@State var isMonitored` + `Toggle` 추가. `onChange` → `DevicePreferences.shared.setMonitored` + `bluetoothService.refresh()`.

## Tasks Completed

| Task | Commit | Status |
|------|--------|--------|
| Task 1: SettingsController + SettingsView + AppDelegate 연결 | eba50cb | Done |
| Task 2: HeaderView 설정 버튼 + DeviceRowView 모니터링 토글 | 83b1772 | Done |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] AppDelegate에 @MainActor 추가 불가**
- **Found during:** Task 1 — swift build 오류
- **Issue:** `main.swift`에서 `AppDelegate()`를 비격리 컨텍스트에서 초기화하므로 `@MainActor`를 클래스에 붙이면 컴파일 에러 발생
- **Fix:** `settingsController`를 optional로 변경, `applicationDidFinishLaunching`에서 `MainActor.assumeIsolated` 블록 내 초기화. `openSettingsPanel`에서 `Task { @MainActor in }` 사용.
- **Files modified:** `AppDelegate.swift`
- **Commit:** eba50cb

**2. [Rule 1 - Bug] onChange 두-파라미터 클로저 macOS 14+ 전용**
- **Found during:** Task 1 — swift build 오류
- **Issue:** `onChange(of:) { _, newValue in }` 클로저는 macOS 14.0+이며 프로젝트는 macOS 13+를 타겟으로 함
- **Fix:** `onChange(of:) { newValue in }` 단일 파라미터 클로저로 변경 (macOS 13 호환)
- **Files modified:** `SettingsView.swift`, `DeviceRowView.swift`
- **Commit:** eba50cb, 83b1772

## Self-Check: PASSED

Files exist:
- SettingsController.swift: FOUND
- SettingsView.swift: FOUND
- AppDelegate.swift (modified): FOUND
- HeaderView.swift (modified): FOUND
- DeviceRowView.swift (modified): FOUND

Commits exist:
- eba50cb: FOUND
- 83b1772: FOUND

swift build: Build complete (0 errors)
