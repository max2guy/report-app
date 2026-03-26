# Phase 1: Feasibility Validation - Research

**Researched:** 2026-03-27
**Domain:** macOS IOKit / CoreBluetooth / BLE GATT battery reading feasibility
**Confidence:** MEDIUM-HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Swift CLI 툴을 제작한다 — IOKit, BLE GATT (0x180F), HID 세 가지 방식을 모두 테스트하는 실행 가능한 커맨드라인 도구
- **D-02:** CLI 툴이 각 방식의 결과를 출력한다 (장치명, 배터리 %, API 경로)
- **D-03:** CLI 코드는 Phase 2에서 재사용할 기반이 된다
- **D-04:** Go 기준: 사용자의 실제 블루투스 키보드에서 배터리 레벨 읽기 성공 (Strict)
- **D-05:** 키보드에서 배터리 읽기 실패 시: 프로젝트 중단하지 않음. 대신 "블루투스 마우스 등 배터리를 노출하는 다른 무선 장치"를 주요 지원 대상으로 포함하여 범위 확장
- **D-06:** 키보드 미지원 판명 시 ROADMAP.md의 Phase 설명을 업데이트하여 지원 장치 범위를 명확히 한다
- **D-07:** Swift CLI를 처음부터 App Sandbox + Hardened Runtime 환경에서 빌드하여 테스트한다
- **D-08:** Sandbox에서 IOKit 접근이 차단되는지 Phase 1에서 확인한다
- **D-09:** Phase 1 결과로 즉시 결정: Sandbox에서 IOKit 동작 → Mac App Store 배포 가능 / Sandbox에서 IOKit 차단 → Notarization 직접 배포 (.dmg) 로 확정
- **D-10:** 배포 방식 결정을 Phase 1 완료 보고서에 포함한다

### Claude's Discretion

- CLI 구체적인 구현 방식(flag 설계, 출력 포맷) — Claude가 결정
- 세 가지 API 테스트 순서 — IOKit → BLE GATT → HID 순서로 Claude가 결정

### Deferred Ideas (OUT OF SCOPE)

- 블루투스 마우스 등 추가 장치 지원 상세 구현 — Phase 2 이후에서 결정
- App Store 심사 전략 — Phase 1 Sandbox 결과 이후에 결정
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FEAS-01 | `ioreg` 명령으로 연결된 블루투스 장치의 배터리 레벨 노출 여부를 확인할 수 있다 | IOKit IORegistry 패턴, `ioreg -r -d 1 -k BatteryPercent` 명령, `AppleDeviceManagementHIDEventService` 매칭 딕셔너리 |
| FEAS-02 | App Sandbox 환경에서 IOKit을 통한 배터리 레벨 읽기가 가능한지 확인한다 | 핵심 발견: IOKit은 App Sandbox와 호환되지 않음 (HIGH confidence) — D-09 분기 결정의 핵심 |
| FEAS-03 | BLE GATT Battery Service (0x180F)를 통한 배터리 읽기 가능 여부를 확인한다 | CoreBluetooth GATT 0x180F / 0x2A19 패턴, CBCentralManager + CBPeripheral 코드 예제 |
</phase_requirements>

---

## Summary

Phase 1의 핵심 질문은 두 가지다: (1) 사용자의 블루투스 키보드가 IOKit IORegistry에 `BatteryPercent`를 노출하는가, (2) App Sandbox 환경에서 IOKit 접근이 허용되는가. 이 두 질문에 대한 답이 Phase 2 아키텍처와 배포 방향을 완전히 결정한다.

**가장 중요한 발견:** IOKit은 App Sandbox와 호환되지 않는다는 것이 여러 소스에서 확인된다 (HIGH confidence). 즉, D-09 분기에서 "Sandbox에서 IOKit 차단 → Notarization 직접 배포"가 거의 확실한 결과다. CLI 프로토타입은 이를 실증적으로 검증해야 한다.

**두 번째 주요 발견:** 기계식 키보드가 HID Battery Usage Page를 구현하는지가 관건이다. BLE HID 프로파일 사양에 따르면 GATT HID 디바이스는 Battery Service(0x180F)를 포함해야 하지만, 실제 구현은 펌웨어에 따라 다르다. `ioreg -r -d 1 -k BatteryPercent` 가 키보드를 반환하면 IOKit만으로 충분하다.

**Primary recommendation:** Swift Package Manager executable 타겟을 `swift build`로 빌드하는 CLI 툴. IOKit → CoreBluetooth 순으로 테스트. Sandbox 테스트는 `codesign --options runtime` + 별도 entitlements 파일로 실시. Xcode가 없어도 Command Line Tools로 전체 검증 가능.

---

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| Swift | 6.3 (설치됨) | CLI 언어 | 현재 머신에 설치. CLAUDE.md 지정 |
| Swift Package Manager | Built-in | 프로젝트 구조, 빌드 | Zero configuration CLI executable, Xcode 불필요 |
| IOKit (framework) | System | IORegistry 배터리 읽기 (Layer 1) | macOS가 내부적으로 사용하는 동일한 레지스트리 |
| CoreBluetooth (framework) | System | BLE GATT 0x180F 배터리 읽기 (Layer 2) | 표준 Bluetooth SIG Battery Service 접근 |
| IOBluetooth (framework) | System | 페어링된 디바이스 열거 | Classic BT 디바이스 탐색 |

**Xcode 설치 상태:** Xcode.app 미설치. Command Line Tools만 설치됨 (Swift 6.3, codesign, notarytool, ioreg 모두 사용 가능). `swift build`로 CLI 빌드 가능. Sandbox 테스트를 위한 entitlements 기반 codesign도 가능.

### Supporting

| Technology | Purpose | When to Use |
|------------|---------|-------------|
| `swift-argument-parser` | CLI flag 파싱 | Claude 재량 — 명확한 출력 포맷을 위해 권장 |
| `ioreg` (CLI) | 수동 사전 검증 | CLI 툴 작성 전 첫 번째 검증 단계 |
| `system_profiler SPBluetoothDataType` | 장치 정보 확인 | 디바이스가 macOS에 어떻게 표시되는지 확인 |

**Installation:**
```bash
# No installation needed — system frameworks only
# swift-argument-parser (optional, for CLI flags):
# Package.swift에 dependency로 추가
.package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
```

**Version verification:** Swift 6.3 confirmed installed (`/Library/Developer/CommandLineTools/usr/bin/swift`).

---

## Architecture Patterns

### Recommended Project Structure

```
bt-battery-probe/           # swift package init --type executable
  Package.swift             # executable target + framework linker settings
  Sources/
    bt-battery-probe/
      main.swift            # entry point, orchestrates 3 layers
      IOKitProbe.swift      # Layer 1: IORegistry BatteryPercent scan
      BLEProbe.swift        # Layer 2: CoreBluetooth GATT 0x180F scan
      SandboxProbe.swift    # Sandbox 제약 확인 로직
  Results/
    findings.md             # 실행 결과 기록 (수동)
```

### Pattern 1: Swift Package Manager Executable with System Frameworks

**What:** `swift package init --type executable` 으로 생성한 CLI 프로젝트에 IOKit/IOBluetooth/CoreBluetooth를 linkerSettings로 링크

**When to use:** Phase 1 CLI 툴 전체

**Example:**
```swift
// Package.swift
// Source: Apple PackageDescription docs + verified via WebSearch
let package = Package(
    name: "bt-battery-probe",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "bt-battery-probe",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("CoreBluetooth")
            ]
        )
    ]
)
```

### Pattern 2: IOKit IORegistry Battery Read

**What:** `IOServiceMatching("AppleDeviceManagementHIDEventService")` 로 HID 서비스 이터레이션, `BatteryPercent` 프로퍼티 읽기

**When to use:** FEAS-01 검증 (IOKit 레이어)

**Example:**
```swift
// Source: STACK.md (pre-existing research) + cross-verified with WebSearch
import IOKit

func probeIOKit() -> [(product: String, battery: Int)] {
    var results: [(String, Int)] = []
    var iterator: io_iterator_t = 0

    let matching = IOServiceMatching("AppleDeviceManagementHIDEventService")
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
        print("[IOKit] IOServiceGetMatchingServices failed")
        return results
    }
    defer { IOObjectRelease(iterator) }

    var service: io_object_t = IOIteratorNext(iterator)
    while service != 0 {
        defer {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { continue }

        if let battery = dict["BatteryPercent"] as? Int,
           let product = dict["Product"] as? String {
            results.append((product, battery))
        }
    }
    return results
}
```

**Alternative matching key:** `IOBluetoothDevice` (broader, covers Classic BT devices)
```swift
// Also try:
let matching2 = IOServiceMatching("IOBluetoothDevice")
```

### Pattern 3: CoreBluetooth GATT Battery Service (0x180F)

**What:** CBCentralManager로 Battery Service 광고하는 BLE 디바이스 스캔 후 0x2A19 특성 읽기

**When to use:** FEAS-03 검증 (BLE GATT 레이어)

**Example:**
```swift
// Source: STACK.md (pre-existing research), Bluetooth SIG Battery Service spec
import CoreBluetooth

class BLEProbe: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    let batteryServiceUUID = CBUUID(string: "180F")
    let batteryLevelUUID   = CBUUID(string: "2A19")
    var central: CBCentralManager!
    var found: [(name: String, battery: Int)] = []

    func start() {
        // CBCentralManager init triggers Bluetooth permission prompt
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            print("[BLE] Bluetooth not available: \(central.state)")
            return
        }
        central.scanForPeripherals(withServices: [batteryServiceUUID], options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
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
        if let data = characteristic.value, let level = data.first {
            found.append((peripheral.name ?? "Unknown", Int(level)))
        }
    }
}
```

### Pattern 4: Sandbox Entitlements Test Build

**What:** codesign으로 Hardened Runtime + 최소 entitlements + sandbox 활성화한 빌드 생성. FEAS-02 검증용.

**When to use:** IOKit/BLE 기능 확인 후, Sandbox 환경에서 재실행 테스트

**Example:**
```bash
# 1. Release 빌드
swift build -c release

# 2. entitlements 파일 생성 (sandbox + bluetooth)
cat > sandbox.entitlements << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.device.bluetooth</key>
    <true/>
</dict>
</plist>
EOF

# 3. Hardened Runtime + Sandbox로 서명
codesign --sign - --entitlements sandbox.entitlements \
  --options runtime \
  .build/release/bt-battery-probe

# 4. 실행 — sandbox 환경에서 IOKit이 차단되는지 확인
.build/release/bt-battery-probe --iokit
```

**참고:** `--sign -` 는 임시 서명 (ad-hoc). 실제 Developer ID 없이도 sandbox 동작 테스트 가능.

### Anti-Patterns to Avoid

- **IOBluetoothDevice.batteryPercent() 직접 호출:** 비공개 ObjC 메서드, macOS 업데이트마다 깨질 수 있음. IORegistry 키-값 읽기가 더 안정적
- **BLE 스캔 무한 실행:** CBCentralManager 스캔은 타임아웃(10초) 후 반드시 중단. CLI 툴이 멈춰서 돌지 않도록 RunLoop 제어 필요
- **Sandbox 테스트 건너뛰기:** 개발 빌드에서 작동해도 Sandbox에서 다름. D-07/D-08 지시에 따라 처음부터 Sandbox 테스트

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CLI argument parsing | 직접 `CommandLine.arguments` 파싱 | `swift-argument-parser` | 복잡한 flag/validation 처리, Apple 공식 라이브러리 |
| Bluetooth permission UI | 직접 alert 구현 | `CBCentralManager.authorization` 상태 확인 | CBCentralManager가 이미 시스템 팝업 트리거 |
| IORegistry iteration | 재귀 탐색 코드 | `IOServiceGetMatchingServices` + `IOIteratorNext` | macOS 공식 패턴. 재귀 불필요 |
| BLE async 결과 수집 | 직접 스레딩 | RunLoop + `sleep`/`DispatchSemaphore` | CLI에서 CBCentral 콜백을 기다리는 표준 패턴 |

**Key insight:** Phase 1은 프로토타입이므로 프로덕션 아키텍처는 불필요. 가장 빠르게 실증 결과를 얻는 코드가 최선.

---

## Common Pitfalls

### Pitfall 1: IOKit이 Sandbox에서 완전 차단됨 (HIGH confidence)

**What goes wrong:** IOKit은 App Sandbox와 호환되지 않는다. 복수의 출처에서 확인: "IOKit is not compatible with App Sandbox and is not suitable for the App Store." 개발 빌드(unsigned)에서는 정상 동작하다가, Sandbox 서명 후 IORegistry 접근이 실패한다.

**Why it happens:** App Sandbox는 IOKit의 임의적인 IORegistry 접근을 의도적으로 차단한다. `com.apple.security.device.bluetooth` entitlement는 CoreBluetooth에만 적용되며, IOKit raw access를 허용하지 않는다.

**How to avoid:** D-09에 따라, 이 결과가 확인되면 즉시 "Notarization 직접 배포 (.dmg)" 결정. 이는 Phase 1에서 기대되는 결과. Sandbox 없는 빌드와 Sandbox 빌드 두 개를 모두 실행하여 차이를 문서화한다.

**Warning signs:** `IOServiceGetMatchingServices` 가 `KERN_SUCCESS` 를 반환하지만 iterator가 비어있거나, 0개 디바이스를 반환하면 sandbox가 차단 중.

### Pitfall 2: CLI에서 CoreBluetooth 비동기 결과 대기

**What goes wrong:** `CBCentralManager` 딜리게이트 콜백은 비동기다. `main()` 이 즉시 반환되면 스캔 결과를 받기 전에 프로그램이 종료된다.

**Why it happens:** CLI는 기본 RunLoop가 없다 (AppKit 앱과 달리).

**How to avoid:**
```swift
// CLI에서 BLE 스캔 결과 기다리기
let probe = BLEProbe()
probe.start()

// RunLoop으로 콜백 대기 (최대 15초)
let deadline = Date(timeIntervalSinceNow: 15)
while Date() < deadline && !probe.isDone {
    RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
}
```

**Warning signs:** 프로그램이 즉시 종료되고 BLE 결과가 0개이면 이 문제.

### Pitfall 3: 기계식 키보드의 BatteryPercent 미노출

**What goes wrong:** RGB LED로 배터리를 표시하는 기계식 키보드 (FN+B로 색상 표시)는 배터리 레벨을 HID Battery Usage Page나 BLE GATT에 노출하지 않을 수 있다. 펌웨어 구현 여부에 따라 다르다.

**Why it happens:** 배터리 HID 리포팅은 옵션이다. 많은 키보드 제조사가 LED 방식으로만 구현한다.

**How to avoid:** `ioreg -r -d 1 -k BatteryPercent` 를 CLI 툴 작성 전에 먼저 실행한다. 결과가 비어있으면 D-05에 따라 범위 확장 (마우스 등 다른 장치 포함) 결정.

**Warning signs:** `ioreg -r -d 1 -k BatteryPercent` 출력에 키보드 항목 없음.

### Pitfall 4: BLE 스캔이 이미 연결된 디바이스를 발견하지 못함

**What goes wrong:** `scanForPeripherals(withServices:)` 는 광고 중인 디바이스만 발견한다. 이미 macOS에 연결된 Bluetooth 디바이스는 적극적으로 광고하지 않을 수 있다.

**Why it happens:** 연결된 디바이스는 광고를 중단한다.

**How to avoid:** `central.retrieveConnectedPeripherals(withServices: [batteryServiceUUID])` 를 사용하면 이미 연결된 BLE 디바이스를 가져올 수 있다. 스캔과 병행 사용 권장.

```swift
// 이미 연결된 BLE 디바이스도 포함
let connected = central.retrieveConnectedPeripherals(withServices: [batteryServiceUUID])
for peripheral in connected {
    central.connect(peripheral, options: nil)
}
```

---

## Code Examples

### 수동 검증 명령 (CLI 툴 작성 전 첫 번째 테스트)

```bash
# Source: PITFALLS.md + cross-verified with gist.github.com/miyagawa/ed22215692e1937ab4bc

# 1. 전체 BT 디바이스 배터리 키 검색
ioreg -r -d 1 -k BatteryPercent | egrep '("BatteryPercent"|"Product")'

# 2. 모든 BT 디바이스 정보 확인
system_profiler SPBluetoothDataType

# 3. 특정 디바이스 상세 확인
ioreg -r -c IOBluetoothDevice | grep -A 20 "YourKeyboardName"

# 4. HID 서비스 확인 (IOKit Swift 코드와 동일한 경로)
ioreg -r -n AppleDeviceManagementHIDEventService | grep -i battery
```

### CLI 툴 빌드 및 실행

```bash
# 프로젝트 초기화
swift package init --type executable --name bt-battery-probe
cd bt-battery-probe

# 빌드
swift build

# 실행 (sandbox 없음)
.build/debug/bt-battery-probe

# Release 빌드
swift build -c release
```

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Swift | CLI 빌드 | ✓ | 6.3 (swiftlang-6.3.0.123.5) | — |
| Command Line Tools | 컴파일러, codesign | ✓ | xcode-select 2416 | — |
| IOKit (system) | FEAS-01, FEAS-02 | ✓ | System | — |
| CoreBluetooth (system) | FEAS-03 | ✓ | System | — |
| IOBluetooth (system) | 디바이스 열거 | ✓ | System | — |
| codesign | Sandbox 테스트 (D-07) | ✓ | /usr/bin/codesign | — |
| notarytool | 배포 검증 | ✓ | CLT 제공 | — |
| ioreg | 수동 검증 | ✓ | /usr/sbin/ioreg | — |
| Xcode.app | — | ✗ | 미설치 | Command Line Tools로 충분 (swift build, codesign 사용 가능) |

**Missing dependencies with no fallback:** 없음

**Missing dependencies with fallback:**
- Xcode.app: `swift build` + `codesign` (CLT)로 CLI 툴 빌드 및 Sandbox 테스트 가능. Xcode 없이도 Phase 1 목표 달성 가능.

**중요:** Xcode.app이 없어도 Phase 1은 완전히 진행 가능. GUI가 없는 CLI 툴이므로 Interface Builder 불필요.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | 없음 — Phase 1은 실험적 프로토타입, XCTest 불필요 |
| Config file | 없음 (Wave 0 gap) |
| Quick run command | `.build/debug/bt-battery-probe` |
| Full suite command | `.build/debug/bt-battery-probe --iokit && .build/debug/bt-battery-probe --ble && .build/debug/bt-battery-probe --sandbox` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FEAS-01 | `ioreg` 및 IOKit Swift 코드가 BT 디바이스 배터리를 반환한다 | smoke (CLI 실행 결과 확인) | `ioreg -r -d 1 -k BatteryPercent` (수동 선행), `.build/debug/bt-battery-probe --iokit` | ❌ Wave 0 |
| FEAS-02 | Sandbox 환경에서 IOKit 접근이 차단되거나 허용된다는 결과를 출력한다 | smoke (Sandbox signed 빌드 실행) | `codesign` 후 `.build/release/bt-battery-probe --sandbox` | ❌ Wave 0 |
| FEAS-03 | BLE GATT 0x180F Battery Service 스캔 결과를 출력한다 | smoke (CLI 실행 결과 확인) | `.build/debug/bt-battery-probe --ble` | ❌ Wave 0 |

**Sampling Rate:**
- Per task commit: `swift build` (컴파일 성공 확인)
- Per wave merge: 세 가지 모드 모두 실행 후 결과 findings.md에 기록
- Phase gate: 모든 세 요구사항에 대한 결과 (Success/Failure/N/A) 문서화 완료

### Wave 0 Gaps

- [ ] `Sources/bt-battery-probe/main.swift` — CLI entry point, --iokit/--ble/--sandbox flag 분기
- [ ] `Sources/bt-battery-probe/IOKitProbe.swift` — FEAS-01, FEAS-02 커버
- [ ] `Sources/bt-battery-probe/BLEProbe.swift` — FEAS-03 커버
- [ ] `Package.swift` — IOKit/IOBluetooth/CoreBluetooth linkerSettings, swift-argument-parser dep
- [ ] `sandbox.entitlements` — Sandbox 테스트용 entitlements 파일

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `SMLoginItemSetEnabled` | `SMAppService.mainApp.register()` | macOS 13 | Login items API 변경. Phase 1 무관 |
| NSStatusItem 직접 사용 | `MenuBarExtra` (SwiftUI) | macOS 13 WWDC 2022 | Phase 2 이후 관련 |
| IOBluetooth for battery | IOKit IORegistry `BatteryPercent` | 항상 이렇게 해야 함 | IOBluetooth는 배터리를 직접 노출하지 않음 |
| `ObservableObject` | `@Observable` macro | macOS 14 | Phase 1 CLI에서는 무관 |

**Deprecated/outdated:**
- `IOBluetooth.framework` 직접 배터리 읽기: 배터리 정보 없음. 디바이스 열거만 가능
- `LSSharedFileListItemSetHidden`: macOS 13에서 deprecated. `SMAppService` 사용

---

## Open Questions

1. **사용자 키보드가 `BatteryPercent`를 노출하는가?**
   - What we know: RGB LED (FN+B) 방식 사용. 이 방식은 HID 표준 Battery Usage Page 미구현 가능성 높음
   - What's unclear: 해당 키보드의 펌웨어가 HID battery reporting을 구현했는지
   - Recommendation: `ioreg -r -d 1 -k BatteryPercent` 를 CLI 툴 작성 전 첫 번째 태스크로 실행. 결과가 비면 D-05 발동 (범위 확장)

2. **BLE GATT 0x180F 스캔 타임아웃 설정**
   - What we know: 이미 연결된 디바이스는 광고 중단. `retrieveConnectedPeripherals` 필요
   - What's unclear: CLI RunLoop 종료 조건 최적 설계
   - Recommendation: 스캔 10초 + `retrieveConnectedPeripherals` 즉시 호출 조합

3. **IOKit Sandbox 차단 메커니즘 정확한 동작**
   - What we know: "IOKit is not compatible with App Sandbox" (confirmed, multiple sources)
   - What's unclear: 정확히 어떤 에러/결과가 반환되는가 (nil? kern error? empty iterator?)
   - Recommendation: 두 빌드(unsigned vs sandboxed) 결과를 stdout에 상세 출력하여 findings.md에 기록

---

## Sources

### Primary (HIGH confidence)
- `.planning/research/STACK.md` — IOKit/CoreBluetooth/MenuBarExtra 스택 권장사항 (pre-existing research)
- `.planning/research/ARCHITECTURE.md` — 3-layer 아키텍처 패턴 및 Swift 코드 예제
- `.planning/research/PITFALLS.md` — Sandbox/IOKit 함정, BLE async 함정

### Secondary (MEDIUM confidence)
- [gist.github.com/miyagawa](https://gist.github.com/miyagawa/ed22215692e1937ab4bc) — `ioreg -r -d 1 -k BatteryPercent` 명령 확인
- [gist.github.com/AndrewWCarson](https://gist.github.com/AndrewWCarson/28fa0d86be7c8c841b2c31d0ec6ddf57) — "IOKit is not compatible with App Sandbox" 확인
- [scriptingosx.com — Notarized SPM executable](https://scriptingosx.com/2023/08/build-a-notarized-package-with-a-swift-package-manager-executable/) — Notarization 워크플로우, `codesign --options runtime` 패턴
- [Apple PackageDescription docs — LinkerSetting](https://developer.apple.com/documentation/packagedescription/linkersetting) — `linkedFramework("IOKit")` 패턴

### Tertiary (LOW confidence — needs validation)
- WebSearch 결과: "BLE HID spec requires Battery Service 0x180F" — 표준 사양이지만 키보드 펌웨어 구현 여부는 런타임에 확인 필요

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Swift 6.3 설치 확인, system frameworks 존재 확인, linkerSettings 패턴 공식 문서 검증
- Architecture: HIGH — pre-existing research에서 검증된 패턴. IOKit C API + Swift 래퍼 패턴 확인
- Pitfalls: HIGH — IOKit/Sandbox 비호환성은 복수 출처에서 확인. BLE async 패턴은 CoreBluetooth 표준 동작
- Go/No-Go 결과 예측: MEDIUM — IOKit Sandbox 차단 가능성 HIGH (D-09 "Notarization 직접 배포" 결과 예상), 키보드 BatteryPercent 노출 여부는 실행 전 불명확

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable Apple system frameworks; IOKit sandbox behavior may vary with macOS updates)
