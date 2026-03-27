# Phase 3: BLE Extension + Device Management - Research

**Researched:** 2026-03-27
**Domain:** CoreBluetooth BLE GATT battery service, UserDefaults device persistence, SwiftUI settings UI, polling interval management
**Confidence:** HIGH (CoreBluetooth patterns), MEDIUM (settings window approach), HIGH (UserDefaults)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BATT-02 | CoreBluetooth BLE GATT Battery Service (0x180F)를 통해 배터리 레벨을 읽는다 | `CBCentralManager.retrieveConnectedPeripherals(withServices: [batteryServiceUUID])` + `peripheral.readValue(for:)` pattern. Phase 1 `BLEProbe.swift` 재사용 가능. `CoreBluetooth` framework 링크 필요 (이미 Phase 1에서 동작 확인됨) |
| BATT-03 | 설정 가능한 주기(기본 5분)로 배터리 레벨을 자동 갱신한다 | `Timer.scheduledTimer` 기반 폴링. 기본값 300초(5분). 현재 `BluetoothService.schedulePolling()`의 60초를 `PollingInterval` enum으로 교체 |
| MGMT-01 | 사용자가 모니터링할 장치를 선택/해제할 수 있다 | `UserDefaults`에 활성 장치 identifier Set 저장. `BluetoothDevice` 모델에 `isMonitored: Bool` 추가 |
| MGMT-02 | 장치 선택 설정이 앱 재시작 후에도 유지된다 (UserDefaults) | `UserDefaults.standard.set([String], forKey: "monitoredDeviceIDs")`. CBPeripheral.identifier UUID는 paired device에 대해 세션 간 stable |
| MGMT-03 | 사용자가 배터리 갱신 폴링 간격을 설정할 수 있다 | SwiftUI settings view in a separate `NSPanel` (not `SettingsLink` — unreliable in non-MenuBarExtra apps). `Picker` with `PollingInterval` enum values backed by `UserDefaults` |
</phase_requirements>

---

## Summary

Phase 3는 두 가지 독립적인 확장을 구현한다: (1) CoreBluetooth BLE GATT Battery Service(0x180F)를 통한 배터리 읽기 — Phase 1에서 API 기능은 확인됐으나 테스트 장치에서 노출 장치가 0개였다. (2) UserDefaults 기반 장치 선택/해제와 폴링 간격 설정을 제공하는 settings UI.

BLE 확장의 핵심 패턴은 Phase 1 `BLEProbe.swift`에 이미 구현되어 있다: `retrieveConnectedPeripherals(withServices: [batteryServiceUUID])` → `connect()` → `discoverServices()` → `readValue(for:)`. 앱 수준 `BLEService` 클래스로 추출하여 `BluetoothService`가 IOKit 배터리 맵과 병합하면 된다.

Settings UI의 핵심 함정은 `SettingsLink`가 non-MenuBarExtra 메뉴바 앱(NSStatusItem+NSPopover 기반)에서 신뢰할 수 없다는 것이다. 대신 `NSPanel` 또는 `NSWindow`를 직접 생성하고 `NSApp.activate(ignoringOtherApps: true)`로 포커스를 강제하는 패턴이 권장된다.

UserDefaults 장치 식별자 저장의 핵심 결정: `CBPeripheral.identifier`(Apple-assigned UUID)는 paired device에 대해 세션 간 stable하다. `IOBluetoothDevice`의 주소 문자열도 stable하다. 두 소스의 장치를 함께 관리할 때는 `deviceID` 문자열 키로 통합 식별이 필요하다.

**Primary recommendation:** BLEService를 `CBCentralManagerDelegate + CBPeripheralDelegate` 클래스로 구현하고 `@MainActor` `BluetoothService`가 오케스트레이션. UserDefaults에 `[String]`(device name 또는 identifier)으로 활성 장치 목록 저장. Settings는 별도 `NSPanel`로 열기.

---

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| CoreBluetooth | System (macOS 13+) | BLE GATT Battery Service 읽기 | Apple 표준 BLE 프레임워크. Phase 1에서 API 기능 확인 |
| Foundation | System | Timer 폴링, UserDefaults 저장 | macOS 기본 라이브러리 |
| AppKit | System | NSPanel/NSWindow 기반 settings window | SettingsLink 우회 패턴에 필요 |
| SwiftUI | System (macOS 13+) | Settings view UI (NSHostingController로 임베드) | 선언적 UI 구현 |

### Supporting

| Technology | Purpose | When to Use |
|------------|---------|-------------|
| Combine | BluetoothService @Published 속성 연결 | 이미 Phase 2에서 사용 중 |
| UserDefaults.standard | 장치 선택 + 폴링 간격 영속 | App Sandbox에서 sandbox-scoped storage로 동작 확인 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSPanel for settings | SwiftUI `Settings` scene + `SettingsLink` | SettingsLink는 LSUIElement 앱에서 신뢰 불가. NSPanel이 더 안전 |
| `[String]` device names in UserDefaults | `[UUID]` CBPeripheral identifiers | UUID는 완전히 stable하지만 IOKit-only 장치는 UUID가 없음. Name이 더 단순하고 범용적 |
| Timer polling | CBCharacteristic NOTIFY subscription | NOTIFY는 BLE 장치에만 작동. IOKit은 push 없음. Polling이 두 소스를 통합 |

**Package.swift 업데이트:**
```swift
// CoreBluetooth 링크 추가 (Phase 1 BLEProbe에서 이미 사용됨 — 앱에는 미링크 상태)
.linkedFramework("CoreBluetooth"),
```

---

## Architecture Patterns

### Recommended Project Structure

Phase 3 추가 파일:

```
BTBatteryMonitor/Sources/BTBatteryMonitor/
├── Services/
│   ├── BluetoothService.swift     (기존 — BLEService 오케스트레이션 추가)
│   ├── BatteryService.swift       (기존 — 변경 없음)
│   └── BLEService.swift           (신규 — CBCentralManagerDelegate + CBPeripheralDelegate)
├── Models/
│   ├── BluetoothDevice.swift      (기존 — isMonitored 필드 추가)
│   ├── DeviceType.swift           (기존 — 변경 없음)
│   └── PollingInterval.swift      (신규 — enum 5종: 1/2/5/10/30분)
├── Settings/
│   ├── SettingsController.swift   (신규 — NSPanel 생성 + show/hide)
│   ├── SettingsView.swift         (신규 — SwiftUI settings UI)
│   └── DevicePreferences.swift    (신규 — UserDefaults read/write wrapper)
└── Views/
    ├── PopoverView.swift           (기존 — 장치 행에 toggle 추가)
    ├── DeviceRowView.swift         (기존 — isMonitored toggle 추가)
    └── HeaderView.swift            (기존 — "설정" 버튼 추가)
```

### Pattern 1: BLE Battery Read via retrieveConnectedPeripherals

BLE 배터리 읽기의 핵심 패턴. 이미 Phase 1 `BLEProbe.swift`에서 검증됨.

**핵심:** `retrieveConnectedPeripherals(withServices:)`는 시스템에 이미 연결된 BLE 장치를 서비스 UUID로 필터링하여 반환한다. 새로운 페어링이나 active scan 없이 즉시 사용 가능.

```swift
// Source: Phase 1 BLEProbe.swift (verified functional)
// BLEService.swift 패턴

import CoreBluetooth

private let batteryServiceUUID = CBUUID(string: "180F")
private let batteryLevelUUID   = CBUUID(string: "2A19")

final class BLEService: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager?
    private var pendingPeripherals: Set<CBPeripheral> = []
    private var results: [String: Int] = [:]   // peripheral.name -> battery%
    private var completion: (([String: Int]) -> Void)?

    func fetchBatteryLevels(completion: @escaping ([String: Int]) -> Void) {
        self.completion = completion
        self.results = [:]
        // CBCentralManager init triggers Bluetooth permission check if needed
        central = CBCentralManager(delegate: self, queue: .global(qos: .userInitiated))
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            completion?([:]); completion = nil; return
        }
        // Key API: no scanning needed — returns already-connected peripherals
        let connected = central.retrieveConnectedPeripherals(withServices: [batteryServiceUUID])
        guard !connected.isEmpty else {
            completion?([:]); completion = nil; return
        }
        for p in connected {
            pendingPeripherals.insert(p)
            p.delegate = self
            central.connect(p, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([batteryServiceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for svc in peripheral.services ?? [] where svc.uuid == batteryServiceUUID {
            peripheral.discoverCharacteristics([batteryLevelUUID], for: svc)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics ?? [] where char.uuid == batteryLevelUUID {
            peripheral.readValue(for: char)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        defer { finishPeripheral(peripheral) }
        guard error == nil,
              let data = characteristic.value,
              let level = data.first else { return }
        let name = peripheral.name ?? peripheral.identifier.uuidString
        results[name] = Int(level)
    }

    private func finishPeripheral(_ p: CBPeripheral) {
        pendingPeripherals.remove(p)
        if pendingPeripherals.isEmpty {
            completion?(results); completion = nil
        }
    }
}
```

### Pattern 2: BluetoothService BLE + IOKit 병합

```swift
// BluetoothService.swift 확장 패턴
func refresh() {
    Task.detached(priority: .userInitiated) { [weak self] in
        guard let self else { return }
        // Layer 1: IOKit
        let ioMap = self.battery.fetchBatteryLevels()
        // Layer 2: BLE (async callback pattern)
        let bleMap = await withCheckedContinuation { cont in
            self.bleService.fetchBatteryLevels { map in cont.resume(returning: map) }
        }
        // Merge: IOKit takes priority; BLE fills gaps
        let merged = ioMap.merging(bleMap) { iokit, _ in iokit }
        await MainActor.run {
            self.devices = self.buildDeviceList(batteryMap: merged)
        }
    }
}
```

### Pattern 3: UserDefaults 장치 선택 저장

```swift
// DevicePreferences.swift
final class DevicePreferences {
    static let shared = DevicePreferences()
    private let monitoredKey = "com.btbatterymonitor.monitoredDevices"

    /// 모니터링 활성화된 장치 이름 Set
    var monitoredDeviceNames: Set<String> {
        get {
            let arr = UserDefaults.standard.stringArray(forKey: monitoredKey) ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: monitoredKey)
        }
    }

    /// 최초 설치 시 기본값: 모든 장치 모니터링 활성
    func isMonitored(_ deviceName: String) -> Bool {
        // nil (key not set) = true (default all-on)
        guard UserDefaults.standard.object(forKey: monitoredKey) != nil else { return true }
        return monitoredDeviceNames.contains(deviceName)
    }
}
```

### Pattern 4: PollingInterval enum

```swift
// PollingInterval.swift
enum PollingInterval: Int, CaseIterable, Identifiable {
    case oneMin    = 60
    case twoMin    = 120
    case fiveMin   = 300    // default
    case tenMin    = 600
    case thirtyMin = 1800

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .oneMin:    return "1분"
        case .twoMin:    return "2분"
        case .fiveMin:   return "5분"
        case .tenMin:    return "10분"
        case .thirtyMin: return "30분"
        }
    }

    static var `default`: PollingInterval { .fiveMin }

    static func from(userDefaults: UserDefaults) -> PollingInterval {
        let raw = userDefaults.integer(forKey: "pollingInterval")
        return PollingInterval(rawValue: raw) ?? .default
    }
}
```

### Pattern 5: Settings Window (NSPanel 기반)

`SettingsLink`는 `LSUIElement` 앱에서 신뢰할 수 없다 (공식 Apple 문서에 없는 제한이지만 실증된 문제). 대신 `NSPanel`을 직접 생성.

```swift
// SettingsController.swift
@MainActor
final class SettingsController {
    private var panel: NSPanel?

    func showSettings() {
        if let panel, panel.isVisible {
            panel.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView())
        let p = NSPanel(contentViewController: hosting)
        p.title = "BT Battery Monitor 설정"
        p.styleMask = [.titled, .closable, .resizable]
        p.isReleasedWhenClosed = false
        p.setContentSize(NSSize(width: 320, height: 240))
        p.center()
        self.panel = p
        // CRITICAL: must activate app to bring window to front
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    func settingsClosed() {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

**주의:** `setActivationPolicy(.regular)` → `.accessory` 전환 시 Dock 아이콘이 일시적으로 나타났다 사라진다. 이 flicker는 현재 Apple API의 한계로 알려져 있다.

### Anti-Patterns to Avoid

- **SettingsLink 사용:** LSUIElement 앱에서 작동 보장 없음. NSPanel 직접 사용.
- **CBCentralManager에 CBCentralManagerOptionRestoreIdentifierKey 사용:** macOS에서 지원 안 됨 (iOS 전용).
- **BLE scan을 polling할 때마다 새로 시작:** `scanForPeripherals`는 불필요. `retrieveConnectedPeripherals`가 충분하고 더 빠름.
- **`scanForPeripherals(withServices: nil)` 호출:** App Sandbox + Bluetooth entitlement로도 nil services scan은 경고 유발 가능. 항상 서비스 UUID 지정.
- **UserDefaults에 UUID 배열 저장할 때 UUID 타입 직접 저장:** `@AppStorage`는 UUID를 지원하지 않음. `String`으로 변환 후 저장.
- **BLEService를 @MainActor에서 동기적으로 호출:** CBCentralManager 콜백은 초기화 시 지정한 queue에서 실행됨. `.global(qos:)` 큐 지정 + `Task.detached` 패턴 유지.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BLE GATT 배터리 읽기 | 커스텀 BLE 프로토콜 파서 | CoreBluetooth `readValue(for:)` + GATT UUID 표준 | Battery Level characteristic(0x2A19)은 단일 UInt8 바이트. 표준화된 읽기 패턴 사용 |
| 장치 설정 저장 | 커스텀 파일/데이터베이스 | UserDefaults.standard | 간단한 키-값 저장에 충분. Sandbox-scoped. 앱 삭제 시 자동 정리 |
| 폴링 타이머 | 커스텀 타이머 클래스 | Foundation `Timer.scheduledTimer` | 이미 Phase 2 `BluetoothService`에서 사용 중. 인터벌만 교체 |
| Settings 창 | 커스텀 윈도우 관리자 | NSPanel + NSHostingController | AppKit 표준. SettingsLink 우회에 최소한의 코드 |

**Key insight:** BLE GATT Battery Service의 배터리 레벨 데이터는 GATT spec에 따라 첫 번째 바이트(UInt8)가 0-100% 값으로 정의됨. `data.first`로 읽으면 완료.

---

## Common Pitfalls

### Pitfall 1: BLE 장치가 retrieveConnectedPeripherals에서 반환되지 않음

**What goes wrong:** BLE 장치가 시스템에 연결(페어링)되어 있어도 `retrieveConnectedPeripherals(withServices: [batteryServiceUUID])`가 빈 배열 반환.

**Why it happens:** 이 메서드는 서비스 UUID가 시스템 레벨에서 이미 _발견된_ peripherals만 반환한다. 장치가 연결되어 있지만 아직 서비스를 advertise하지 않은 경우 또는 BLE Battery Service(0x180F)를 지원하지 않는 장치(예: Keychron K3)는 반환되지 않는다.

**How to avoid:** 빈 배열은 에러가 아닌 "이 장치들은 BLE Battery Service를 지원하지 않음"으로 처리. IOKit 배터리 맵과 병합 시 BLE 결과가 없으면 IOKit 결과만 사용.

**Warning signs:** Phase 1 FEAS-03 결과: 테스트 기계에서 0개 반환. 이는 BLEService 로직이 잘못된 게 아닌 장치 지원 부재.

### Pitfall 2: TCC Bluetooth 권한 프롬프트 타이밍

**What goes wrong:** CBCentralManager 초기화 시 시스템 Bluetooth 권한 프롬프트가 표시됨. 앱 시작 직후 프롬프트가 나오면 사용자 혼란.

**Why it happens:** CBCentralManager(delegate:queue:)를 호출하면 TCC 프롬프트 트리거.

**How to avoid:** BLEService 초기화를 `startMonitoring()` 후 첫 번째 `refresh()` 시점으로 지연. `NSBluetoothAlwaysUsageDescription`이 Info.plist에 이미 있음(Phase 2에서 추가됨). 권한은 앱 최초 실행 시 1회만 필요.

### Pitfall 3: Settings 창이 다른 창 뒤로 숨음

**What goes wrong:** `NSPanel.makeKeyAndOrderFront(nil)` 호출해도 창이 다른 앱 뒤에 표시됨.

**Why it happens:** `LSUIElement = YES` 앱은 `.accessory` activation policy로 실행됨. 창을 foreground로 가져오려면 앱 자체가 `.regular` policy로 잠시 전환해야 함.

**How to avoid:** 창 표시 직전 `NSApp.setActivationPolicy(.regular)` → `NSApp.activate(ignoringOtherApps: true)` → `panel.makeKeyAndOrderFront(nil)`. 창 닫힌 후 `setActivationPolicy(.accessory)` 복원.

**Warning signs:** 창이 열리지만 클릭해야만 활성화되거나, 다른 앱 뒤에 숨어 있음.

### Pitfall 4: UserDefaults 장치 식별자의 불안정성

**What goes wrong:** `CBPeripheral.identifier` UUID를 저장했는데 앱 재시작 후 UUID가 달라져 모든 저장된 선택이 초기화됨.

**Why it happens:** `CBPeripheral.identifier`는 paired device에 대해 stable하다. 그러나 BLE 장치가 unpaired + random address를 사용하는 경우 UUID가 변경될 수 있음. 또한 IOKit으로만 식별되는 Classic BT 장치는 CBPeripheral.identifier가 없음.

**How to avoid:** **장치 이름(name)을 primary key로 사용.** 이름은 IOKit과 CoreBluetooth 모두에서 가져올 수 있고 사용자에게도 의미 있음. 이름 중복 가능성은 실제 사용 환경에서 극히 드물다. `DevicePreferences.monitoredDeviceNames: Set<String>` 패턴 사용.

### Pitfall 5: BLEService 콜백이 MainActor에서 호출되지 않음

**What goes wrong:** `BLEService.fetchBatteryLevels` completion이 백그라운드 큐에서 호출되는데 `BluetoothService`가 이를 MainActor에서 처리하려 할 때 크래시 또는 경고.

**Why it happens:** CBCentralManager에 `queue: .global(qos: .userInitiated)` 지정 시 모든 delegate 콜백이 해당 큐에서 실행됨.

**How to avoid:** `BluetoothService.refresh()`가 `Task.detached`에서 `withCheckedContinuation`으로 BLEService를 호출 → completion을 받아서 → `await MainActor.run { ... }`으로 UI 업데이트. 이 패턴은 Phase 2 IOKit 호출에서 이미 확립됨.

### Pitfall 6: 폴링 타이머가 BLE 연결 지속 중 중복 실행

**What goes wrong:** `schedulePolling()` 호출 시 기존 타이머가 무효화되지 않아 중복 타이머가 쌓임.

**Why it happens:** `BluetoothService.schedulePolling()`을 폴링 간격 변경 시 재호출하면 기존 타이머가 살아있음.

**How to avoid:** `schedulePolling(interval:)` 내에서 `pollingTimer?.invalidate()` 먼저 호출 후 새 타이머 생성.

### Pitfall 7: Keychron K3 및 유사 키보드의 BLE Battery Service 부재

**What goes wrong:** BLEService가 Keychron K3에서 배터리 데이터를 반환하지 않아 사용자가 버그로 오해.

**Why it happens:** Phase 1 FEAS-03에서 실증: Keychron K3는 표준 BLE GATT Battery Service(0x180F)를 구현하지 않음. 독점 FN+B LED 방식 사용. IOKit HID battery도 미지원. **이 키보드는 현재 어떤 API로도 배터리 데이터 없음**.

**How to avoid:** BATT-04(Phase 2 구현됨): 배터리 데이터 없는 장치는 "배터리 정보 없음"으로 표시. 이는 이미 처리됨. Phase 3에서 추가 조치 불필요. BLE Layer 2는 AirPods, Bluetooth 마우스/헤드폰 등 0x180F를 지원하는 장치에 유효.

---

## Code Examples

### BLE Battery Read — Completion Pattern

```swift
// Source: Phase 1 bt-battery-probe/Sources/bt-battery-probe/BLEProbe.swift (verified)
// 핵심 API 시퀀스:

// Step 1: CBCentralManager 초기화 (Bluetooth 권한 프롬프트 트리거)
central = CBCentralManager(delegate: self, queue: .global(qos: .userInitiated))

// Step 2: state .poweredOn 콜백에서 이미-연결된 BLE 장치 조회
let connected = central.retrieveConnectedPeripherals(withServices: [batteryServiceUUID])

// Step 3: 각 peripheral에 연결 요청 (이미 연결된 장치이므로 빠름)
central.connect(peripheral, options: nil)

// Step 4: 서비스 발견
peripheral.discoverServices([batteryServiceUUID])

// Step 5: 특성(characteristic) 발견
peripheral.discoverCharacteristics([batteryLevelUUID], for: service)

// Step 6: 값 읽기
peripheral.readValue(for: characteristic)

// Step 7: 값 수신
// didUpdateValueFor: data.first = UInt8 (0-100%)
```

### UserDefaults 폴링 간격 저장

```swift
// 저장
UserDefaults.standard.set(PollingInterval.fiveMin.rawValue, forKey: "pollingInterval")

// 읽기
let raw = UserDefaults.standard.integer(forKey: "pollingInterval")  // 0 if not set
let interval = PollingInterval(rawValue: raw) ?? .fiveMin  // 기본값 fallback
```

### BluetoothDevice 모델 확장 (MGMT-01)

```swift
// BluetoothDevice.swift 수정 패턴
struct BluetoothDevice: Identifiable {
    let id: UUID
    let name: String
    let type: DeviceType
    let batteryPercent: Int?
    let isConnected: Bool
    var isMonitored: Bool    // 신규 필드 — MGMT-01
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `scanForPeripherals` for known devices | `retrieveConnectedPeripherals(withServices:)` | CoreBluetooth first release | 페어링된 장치 재-scan 불필요. 더 빠르고 배터리 효율적 |
| `CBCentralManagerOptionRestoreIdentifierKey` for persistence | Not applicable on macOS | macOS CoreBluetooth | macOS는 앱이 iOS처럼 terminate되지 않으므로 state restoration 불필요 |
| `SettingsLink` in menu bar apps | NSPanel/NSWindow direct | macOS 13+ (Sonoma에서 더 심화) | SettingsLink는 MenuBarExtra에서만 안정적. NSStatusItem 기반 앱에서는 NSPanel |

**Deprecated/outdated:**
- `CBCentralManagerOptionRestoreIdentifierKey` on macOS: 미지원. iOS 전용.
- Private selector `showSettingsWindow:`: Sonoma에서 작동 중단 (steipete.me 확인).

---

## Open Questions

1. **BLEService timeout 전략**
   - What we know: `retrieveConnectedPeripherals`는 즉시 반환. 문제는 `connect()` → `discoverServices()` → `readValue()` 체인에서 개별 peripheral이 응답 없으면 pending 상태로 남음.
   - What's unclear: BLE peripheral이 응답하지 않을 때 얼마나 기다려야 하는가? Phase 1은 15초 타임아웃 사용.
   - Recommendation: BLEService에 5초 per-peripheral 타임아웃 구현. `DispatchQueue.main.asyncAfter`로 timeout 처리.

2. **Settings 창 NSWindowDelegate — 창 닫힐 때 activation policy 복원**
   - What we know: 창 닫힌 후 `.accessory`로 복원해야 함. `windowWillClose` 또는 `NSWindowWillCloseNotification` 사용.
   - What's unclear: NSPanel의 `isReleasedWhenClosed = false` 상태에서 delegate 수명 관리.
   - Recommendation: `SettingsController`가 `NSWindowDelegate`를 구현하고 `windowWillClose`에서 `setActivationPolicy(.accessory)` 호출.

3. **모니터링 비활성 장치의 BLE 연결 처리**
   - What we know: 사용자가 장치를 비활성화해도 시스템 레벨 BLE 연결은 유지됨. BLEService는 `retrieveConnectedPeripherals`로 모든 BLE 배터리 장치를 가져옴.
   - What's unclear: 비활성 장치를 BLE 연결 자체에서 필터링할지 vs UI 레이어에서만 필터링할지.
   - Recommendation: BLE 연결 자체는 그대로 유지 (시스템 제어 영역). `BluetoothService.buildDeviceList`에서 `isMonitored` 플래그 적용. 비활성 장치는 popover에 표시 안 함.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Swift CLT / `swift build` | 빌드 | ✓ | 6.3 (arm64-apple-macosx26.0) | — |
| CoreBluetooth.framework | BLE GATT 읽기 | ✓ | System (macOS 13+) | — |
| Foundation.framework | UserDefaults, Timer | ✓ | System | — |
| AppKit.framework | NSPanel | ✓ | System | — |
| codesign | .app 번들 서명 | ✓ | Xcode CLT | — |

BLE 배터리 데이터를 노출하는 실제 장치 (AirPods, BT 마우스 등) 없이는 BATT-02 통합 테스트 제한적. Phase 1 결과(테스트 기기에서 0개 BLE Battery Service 장치)와 동일한 조건.

---

## Validation Architecture

Config에서 `nyquist_validation: true`로 설정됨.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | 없음 (현재 프로젝트에 XCTest 인프라 없음) |
| Config file | — |
| Quick run command | `cd BTBatteryMonitor && swift build -c debug 2>&1` (컴파일 확인) |
| Full suite command | `cd BTBatteryMonitor && bash build.sh` (릴리즈 빌드 + 서명) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BATT-02 | BLE GATT 배터리 읽기 로직 컴파일 | build smoke | `swift build -c debug` | ❌ Wave 0 (BLEService.swift 신규) |
| BATT-03 | 폴링 타이머가 설정된 interval로 실행 | manual-only | — 실제 장치 필요 | ❌ Wave 0 (PollingInterval.swift 신규) |
| MGMT-01 | 장치 toggle UI 표시 | build smoke | `swift build -c debug` | ❌ Wave 0 (DeviceRowView 수정) |
| MGMT-02 | UserDefaults 저장/복원 | manual-only | — 앱 재시작 필요 | ❌ Wave 0 (DevicePreferences.swift 신규) |
| MGMT-03 | Settings 창 표시 + 폴링 간격 변경 | manual-only | — UI 상호작용 필요 | ❌ Wave 0 (SettingsView.swift 신규) |

**Manual-only 이유:** 모든 요구사항이 실제 Bluetooth 하드웨어 또는 UI 상호작용을 필요로 함. 현재 프로젝트에 XCTest 타깃 없음.

### Sampling Rate

- **Per task commit:** `cd /path/to/BTBatteryMonitor && swift build -c debug` — 컴파일 오류 없음 확인
- **Per wave merge:** `bash build.sh` — 릴리즈 빌드 + ad-hoc signing 성공 확인
- **Phase gate:** `open BTBatteryMonitor.app` 후 수동 확인 (`/gsd:verify-work` 전)

### Wave 0 Gaps

- [ ] `BTBatteryMonitor/Sources/BTBatteryMonitor/Services/BLEService.swift` — BATT-02
- [ ] `BTBatteryMonitor/Sources/BTBatteryMonitor/Models/PollingInterval.swift` — BATT-03, MGMT-03
- [ ] `BTBatteryMonitor/Sources/BTBatteryMonitor/Settings/DevicePreferences.swift` — MGMT-01, MGMT-02
- [ ] `BTBatteryMonitor/Sources/BTBatteryMonitor/Settings/SettingsController.swift` — MGMT-03
- [ ] `BTBatteryMonitor/Sources/BTBatteryMonitor/Settings/SettingsView.swift` — MGMT-03
- [ ] `Package.swift` — CoreBluetooth framework 링크 추가 필요

---

## Project Constraints (from CLAUDE.md)

- **Tech Stack**: Swift/SwiftUI — macOS 네이티브. 외부 패키지 추가 금지 (시스템 프레임워크만).
- **Platform**: macOS 13+ (Ventura 이상). `Package.swift`의 `.macOS(.v13)` 유지.
- **BT Protocol**: 장치가 0x180F를 구현하지 않으면 배터리 읽기 불가 — Phase 1에서 확인됨.
- **Sandboxing**: App Sandbox 유지. CoreBluetooth는 `com.apple.security.device.bluetooth` entitlement로 커버됨 — 추가 entitlement 불필요.
- **GSD Workflow**: 모든 파일 변경은 GSD workflow를 통해 진행. 직접 repo 편집 금지.

---

## Sources

### Primary (HIGH confidence)

- Phase 1 `bt-battery-probe/Sources/bt-battery-probe/BLEProbe.swift` — CoreBluetooth `retrieveConnectedPeripherals` + `readValue` 패턴 실증
- Phase 1 `bt-battery-probe/Results/findings.md` — FEAS-03 결과: BLE API 기능 확인, Keychron K3 0x180F 미지원 확인
- `BTBatteryMonitor/Sources/BTBatteryMonitor/Services/BluetoothService.swift` — 기존 폴링/IOKit 패턴 확인
- `BTBatteryMonitor/Sources/BTBatteryMonitor/Resources/BTBatteryMonitor.entitlements` — `com.apple.security.device.bluetooth` 이미 존재

### Secondary (MEDIUM confidence)

- [Apple Developer Documentation: retrieveConnectedPeripherals(withServices:)](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/retrieveconnectedperipherals(withservices:)) — 메서드 동작 확인
- [Peter Steinberger: Showing Settings from macOS Menu Bar Items (2025)](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) — SettingsLink 함정 + NSPanel 해결책
- [Apple Best Practices for Interacting with Remote Peripheral](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/BestPracticesForInteractingWithARemotePeripheralDevice/BestPracticesForInteractingWithARemotePeripheralDevice.html) — paired device reconnect 패턴
- [QuickBird Studios: How to Read BLE Characteristics in Swift](https://quickbirdstudios.com/blog/read-ble-characteristics-swift/) — GATT 0x2A19 읽기 패턴

### Tertiary (LOW confidence)

- [keychron-battery-level GitHub project](https://github.com/rxrdev/keychron-battery-level) — CoreBluetooth + HID 듀얼 전략 참고 (Keychron용 workaround, Phase 3 범위 밖)
- [pmortensen.eu: QMK-based Keychron battery state (2024)](https://pmortensen.eu/world2/2024/11/04/the-battery-state-of-a-keychron-qmk-based-keyboard-can-be-displayed-in-the-operating-system/) — QMK 기반 Keychron Pro 시리즈는 배터리 노출 가능 (K3 비해당)

---

## Metadata

**Confidence breakdown:**
- CoreBluetooth BLE read patterns: HIGH — Phase 1에서 실증된 코드 존재
- UserDefaults persistence: HIGH — 표준 Apple 패턴, 문서화 충분
- Settings window (NSPanel): MEDIUM — steipete.me 2025 글 확인, 공식 Apple 문서에 명시적 가이드 없음
- Keychron K3 battery limitation: HIGH — Phase 1 FEAS-03에서 실증

**Research date:** 2026-03-27
**Valid until:** 2026-06-27 (CoreBluetooth API stable; Settings window pattern은 macOS 버전에 따라 변동 가능)
