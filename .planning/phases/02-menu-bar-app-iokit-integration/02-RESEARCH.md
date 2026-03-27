# Phase 2: Menu Bar App + IOKit Integration - Research

**Researched:** 2026-03-27
**Domain:** macOS AppKit menu bar app, IOKit battery service, IOBluetooth device discovery
**Confidence:** MEDIUM-HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 팝오버는 리스트형 — 스크롤 가능한 세로 목록
- **D-02:** 각 행: `[장치 타입 아이콘] [장치 이름] [배터리 프로그레스바] [배터리%]`
  - SF Symbols로 장치 타입 아이콘 표현 (마우스, 헤드폰, 키보드 등)
- **D-03:** 정렬 순서: 배터리 낮은 순서 (오름차순) — 가장 주의가 필요한 장치 상단
- **D-04:** 배터리 정보가 없는 장치: 리스트에 포함, 회색으로 표시 + "배터리 정보 없음" 텍스트, 리스트 하단 배치
- **D-05:** 팝오버 상단 헤더: "BT Battery Monitor  •  N개 장치"
- **D-06:** `bt-battery-probe/Sources/bt-battery-probe/IOKitProbe.swift`의 `probeIOKit()` 함수를 배터리 서비스 레이어로 재사용
- **D-07:** 배터리 읽기 전략은 IOKit 우선 (BLE GATT는 Phase 3으로 연기)
- **D-08:** App Sandbox + Hardened Runtime 유지 (Phase 1에서 IOKit이 Sandbox에서 동작 확인됨)

### Claude's Discretion

- 메뉴바 아이콘 표시 방식 (아이콘만 vs 배터리% 포함 텍스트) — Claude 결정
- 앱 프레임워크 선택 (SwiftUI MenuBarExtra vs AppKit NSStatusItem+NSPopover) — Claude 결정
- 배터리 갱신 주기/전략 (폴링 기본값, 앱 시작 시 즉시 읽기 등) — Claude 결정
- Xcode 프로젝트 구조 및 타깃 설정 — Claude 결정

### Deferred Ideas (OUT OF SCOPE)

- BLE GATT 배터리 읽기 (0x180F) → Phase 3
- 배터리 부족 알림 → v2
- 장치 선택/해제 설정 → Phase 3
- 배터리 갱신 주기 사용자 설정 → Phase 3
- Login Items (앱 자동 시작) → Phase 3/4
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DISC-01 | macOS에 연결된 모든 블루투스 장치 목록을 탐지하여 표시한다 | `IOBluetoothDevice.pairedDevices()` + `isConnected()` 필터링. `com.apple.security.device.bluetooth` entitlement 필수 |
| DISC-02 | 각 장치의 타입(키보드/마우스/헤드셋/기타)을 식별하여 적절한 아이콘으로 표시한다 | `IOBluetoothDevice.classOfDevice` + Bluetooth Class of Device (CoD) major class 비트마스크. SF Symbols 대응표 |
| DISC-03 | 장치 연결/해제 상태 변화를 실시간으로 감지하여 UI에 반영한다 | `IOBluetoothDevice.register(forConnectNotifications:selector:)` + 연결 후 `registerForDisconnectNotification` 등록 패턴 |
| BATT-01 | IOKit IORegistry를 통해 장치의 배터리 레벨(%)을 읽는다 | Phase 1 `IOKitProbe.swift` 직접 재사용. `probeIOKit()` 함수 이식 |
| BATT-04 | 배터리 정보를 노출하지 않는 장치는 "배터리 정보 없음"으로 명확히 표시한다 | `batteryPercent == nil` 분기 처리. 목록 하단 배치, 회색 표시 (D-04) |
| UI-01 | macOS 메뉴바에 배터리 아이콘과 퍼센트(%)를 표시한다 | `NSStatusBar.system.statusItem(withLength:)` + `NSStatusBarButton` title/image 설정 |
| UI-03 | 메뉴바 클릭 시 전체 장치 배터리 상세 팝오버를 표시한다 | `NSStatusBarButton` + `NSPopover` + SwiftUI contentView 패턴 |
| UI-04 | 팝오버에 각 장치의 이름, 타입 아이콘, 배터리 레벨, 연결 상태를 표시한다 | SwiftUI List/ForEach 뷰, SF Symbols 아이콘, ProgressView 또는 커스텀 progress bar |
| LIFE-02 | Dock에 아이콘이 표시되지 않는 메뉴바 전용 앱으로 동작한다 | `Info.plist`: `LSUIElement = YES` 또는 `NSApplication.shared.setActivationPolicy(.accessory)` |
</phase_requirements>

---

## Summary

Phase 2는 Phase 1의 IOKitProbe 코드를 서비스 레이어로 재사용하고, AppKit NSStatusItem + NSPopover 기반의 macOS 메뉴바 앱을 처음부터 빌드한다. 핵심 기술 질문은 세 가지다: (1) Xcode.app 없이 어떻게 .app 번들을 빌드하는가, (2) 어떤 메뉴바 프레임워크를 선택하는가 (AppKit vs SwiftUI), (3) 장치 타입 식별과 연결 상태 변화 감지를 어떻게 구현하는가.

**Critical constraint discovered:** 현재 환경에 Xcode.app이 설치되어 있지 않고 Homebrew도 없다. `xcodebuild`는 Xcode.app 없이 사용 불가능하다. 그러나 macOS .app 번들은 수동으로 디렉토리 구조를 생성하고 `swift build`로 컴파일한 바이너리를 배치하는 방법으로 Xcode 없이 빌드할 수 있다. 정식 codesign + notarization을 위해서는 Xcode.app이 필요하지만, 로컬 개발·테스트·launchd 기반 실행은 Xcode 없이도 가능하다.

**Framework decision (Claude's discretion):** AppKit NSStatusItem + NSPopover (with SwiftUI content view)를 권장한다. 이유: (1) SwiftUI MenuBarExtra는 macOS 13+에서만 사용 가능하고 `.window` 스타일 팝오버가 요구하는 커스텀 레이아웃 제어가 제한적이다. (2) NSStatusItem은 모든 기존 macOS 메뉴바 앱의 기반이며 안정성이 검증됐다. (3) NSPopover + SwiftUI contentView 조합으로 팝오버 내부는 SwiftUI로 선언적으로 구현하면서 AppKit의 제어권을 유지할 수 있다.

**Primary recommendation:** AppKit `NSStatusItem` + `NSPopover` (SwiftUI content) + `IOBluetoothDevice` 열거 + `IOKitProbe` 재사용. Xcode.app은 Wave 0에서 설치하거나, 수동 `.app` 번들 방식으로 CLT만으로 진행.

---

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| Swift | 6.3 (설치됨) | 언어 | 현재 환경 확인됨 |
| AppKit | System | NSStatusItem, NSPopover, NSApplication | macOS 메뉴바 앱의 표준 프레임워크 |
| SwiftUI | System (macOS 13+) | NSPopover contentView 구현 | 선언적 UI; AppKit 내부에 NSHostingView로 임베드 |
| IOKit | System | 배터리 읽기 (Phase 1 코드 재사용) | IORegistry BatteryPercent 접근 |
| IOBluetooth | System | 장치 열거, 타입 식별, 연결/해제 알림 | Classic BT 장치 탐색 표준 |
| Foundation | System | Timer 기반 폴링, UserDefaults | 기본 라이브러리 |

### Supporting

| Technology | Purpose | When to Use |
|------------|---------|-------------|
| Xcode.app | .app 번들 빌드, xcodebuild, codesign 완전 지원 | Xcode 프로젝트 기반 빌드 경로 선택 시 (권장) |
| XcodeGen | project.yml → .xcodeproj 자동 생성 | Xcode 설치 후 프로젝트 파일 관리 자동화 시 |
| Manual .app bundle | Xcode 없이 수동 번들 구조 생성 | CLT-only 환경에서 로컬 테스트 |

**Installation (verified versions):**
```bash
# 시스템 프레임워크 — 추가 설치 불필요
# IOKit, IOBluetooth, AppKit, SwiftUI, Foundation: macOS 13+ 기본 제공

# Xcode 설치 (권장 경로):
# https://developer.apple.com/download/more/ 에서 Xcode 다운로드
# 또는 App Store에서 설치

# XcodeGen (Xcode 설치 후 선택적):
# brew install xcodegen  (Homebrew 설치 필요)
```

---

## Architecture Patterns

### Recommended Project Structure

```
BTBatteryMonitor/                    # Xcode 프로젝트 루트
  BTBatteryMonitor.xcodeproj/        # Xcode 프로젝트 파일 (XcodeGen으로 생성 또는 수동)
  BTBatteryMonitor/
    App/
      AppDelegate.swift              # NSApplication delegate, NSStatusItem 초기화
      main.swift                     # NSApplicationMain 진입점
    MenuBar/
      StatusBarController.swift      # NSStatusItem + NSPopover 관리
    Services/
      BluetoothService.swift         # IOBluetoothDevice 열거, 연결/해제 알림
      BatteryService.swift           # IOKitProbe 래퍼 — Phase 1 코드 이식
    Models/
      BluetoothDevice.swift          # 디바이스 모델 (이름, 타입, 배터리, 연결상태)
      DeviceType.swift               # enum: mouse/headset/keyboard/other + SF Symbol 대응
    Views/
      PopoverView.swift              # SwiftUI 팝오버 루트 뷰
      DeviceRowView.swift            # 각 장치 행 (타입아이콘, 이름, 프로그레스바, %)
      HeaderView.swift               # "BT Battery Monitor  •  N개 장치"
    Resources/
      Info.plist                     # LSUIElement=YES, NSBluetoothAlwaysUsageDescription
      BTBatteryMonitor.entitlements  # app-sandbox + device.bluetooth
  BTBatteryMonitorTests/             # 단위 테스트 타깃
```

### Pattern 1: AppDelegate + NSStatusItem + NSPopover

**What:** AppKit AppDelegate에서 NSStatusItem을 생성하고, 클릭 시 NSPopover를 표시. Popover 내부는 SwiftUI NSHostingView.
**When to use:** Phase 2 전체 메뉴바 앱 구조

```swift
// Source: Apple AppKit documentation, verified pattern from polpiella.dev
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Dock 아이콘 숨기기 (LIFE-02)
        NSApp.setActivationPolicy(.accessory)

        // 2. 메뉴바 아이템 생성
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bluetooth", accessibilityDescription: "BT Battery")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // 3. Popover 생성 (SwiftUI content)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient    // 외부 클릭 시 자동 닫힘
        popover.contentViewController = NSHostingController(rootView: PopoverView())
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
```

### Pattern 2: IOBluetoothDevice 장치 열거 및 타입 식별 (DISC-01, DISC-02)

**What:** `IOBluetoothDevice.pairedDevices()`로 페어링된 장치 목록을 가져오고, `isConnected()`로 연결 상태 필터링. `classOfDevice`로 장치 타입 분류.
**When to use:** BluetoothService 초기 로드 및 폴링 갱신

```swift
// Source: Apple IOBluetooth documentation, gist.github.com/jamesmartin/9847466aba513de9a77507b56e712296
import IOBluetooth

// Bluetooth Class of Device — Major Device Class 비트마스크 (Bluetooth SIG 표준)
// classOfDevice >> 8 & 0x1F 로 major class 추출
enum DeviceType {
    case mouse          // Major: 0x05 (Peripheral), Minor: pointing device
    case keyboard       // Major: 0x05 (Peripheral), Minor: keyboard
    case headset        // Major: 0x04 (Audio/Video)
    case other

    // SF Symbols 매핑
    var symbolName: String {
        switch self {
        case .mouse:    return "computermouse"
        case .keyboard: return "keyboard"
        case .headset:  return "headphones"
        case .other:    return "dot.radiowaves.left.and.right"
        }
    }

    // IOBluetoothDevice.classOfDevice에서 타입 추출
    static func from(classOfDevice cod: BluetoothClassOfDevice) -> DeviceType {
        let majorClass = (cod >> 8) & 0x1F
        let minorClass = (cod >> 2) & 0x3F
        switch majorClass {
        case 0x04: return .headset   // Audio/Video
        case 0x05:                   // Peripheral (mouse, keyboard, trackpad)
            switch minorClass {
            case 0x02: return .keyboard
            case 0x05: return .mouse
            default: return .other
            }
        default: return .other
        }
    }
}

func fetchConnectedDevices() -> [BluetoothDevice] {
    guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
        return []
    }
    return paired
        .filter { $0.isConnected() }
        .map { device in
            BluetoothDevice(
                name: device.name ?? "Unknown",
                type: DeviceType.from(classOfDevice: device.classOfDevice),
                isConnected: true
            )
        }
}
```

### Pattern 3: 연결/해제 알림 등록 (DISC-03)

**What:** `IOBluetoothDevice.register(forConnectNotifications:selector:)` 로 새 연결 감지. 연결 시 해당 장치에 `registerForDisconnectNotification` 등록.
**When to use:** BluetoothService 초기화 시

```swift
// Source: Apple IOBluetooth documentation, Apple Developer Forums
import IOBluetooth

class BluetoothService: NSObject {
    private var connectNotification: IOBluetoothUserNotification?

    func startMonitoring() {
        // 새 BT 연결 감지
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
    }

    @objc func deviceConnected(_ notification: IOBluetoothUserNotification,
                                device: IOBluetoothDevice) {
        // 해제 알림 등록
        device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:device:))
        )
        // UI 갱신
        refreshDeviceList()
    }

    @objc func deviceDisconnected(_ notification: IOBluetoothUserNotification,
                                   device: IOBluetoothDevice) {
        refreshDeviceList()
    }

    private func refreshDeviceList() {
        // @MainActor 에서 UI 업데이트
        DispatchQueue.main.async {
            // ObservableObject 모델 갱신
        }
    }
}
```

### Pattern 4: BatteryService — Phase 1 IOKitProbe 이식 (BATT-01)

**What:** `bt-battery-probe/Sources/bt-battery-probe/IOKitProbe.swift`를 `BatteryService.swift`로 복사. `IOKitResult` 구조체와 `probeIOKit()` 함수를 그대로 사용.
**When to use:** 배터리 데이터 읽기 (초기 로드 + 폴링)

```swift
// IOKitProbe.swift 이식: 변경 없이 복사 후 BatteryService에서 래핑
struct BatteryService {
    // Phase 1 코드에서 직접 이식 — IOKitResult, probeIOKit() 그대로 사용
    func fetchBatteryLevels() -> [String: Int] {
        let results = probeIOKit()
        var map: [String: Int] = [:]
        for r in results {
            if let pct = r.batteryPercent {
                map[r.product] = pct
            }
        }
        return map  // product name → battery %
    }
}
```

### Pattern 5: LIFE-02 — Dock 아이콘 숨기기

**두 가지 방법 중 Info.plist가 더 신뢰성 있음:**

```xml
<!-- Info.plist 방법 (권장) -->
<key>LSUIElement</key>
<true/>
```

```swift
// 코드 방법 (보조적으로 사용 가능)
NSApp.setActivationPolicy(.accessory)
```

### Pattern 6: 수동 .app 번들 (Xcode 미설치 시 로컬 개발 경로)

**What:** Xcode 없이 `swift build`로 컴파일 후 수동으로 .app 디렉토리 구조 생성.
**When to use:** Xcode.app 설치 전 로컬 테스트 (권장 경로는 Xcode 설치)

```bash
# 빌드
swift build -c release

# 수동 .app 번들 구조 생성
mkdir -p BTBatteryMonitor.app/Contents/MacOS
mkdir -p BTBatteryMonitor.app/Contents/Resources
cp .build/release/BTBatteryMonitor BTBatteryMonitor.app/Contents/MacOS/
cp Info.plist BTBatteryMonitor.app/Contents/

# ad-hoc 서명
codesign --sign - --entitlements BTBatteryMonitor.entitlements \
  --options runtime BTBatteryMonitor.app

# 실행
open BTBatteryMonitor.app
```

**주의:** 이 방법은 로컬 테스트 전용. App Store 제출 또는 Notarization을 위해서는 Xcode.app의 xcodebuild가 필요.

### Anti-Patterns to Avoid

- **SwiftUI `MenuBarExtra` 단독 사용:** macOS 13+에서만 사용 가능하고, `.window` style popover에서 커스텀 레이아웃 제어가 어렵다. NSPopover가 더 안정적.
- **`IOBluetoothDevice.batteryPercent()` 직접 호출:** 비공개 ObjC 메서드. macOS 업데이트 시 깨질 수 있음. IOKit IORegistry를 통한 읽기가 표준.
- **메뉴바 버튼에 긴 텍스트 표시:** 메뉴바 공간을 많이 차지. 아이콘 + 최소 텍스트(예: 최저 배터리 %)가 적절.
- **Popover를 `.semitransient`로 설정:** 클릭 외부에서 자동으로 닫히지 않아 사용성 저하. `.transient` 사용.
- **NSPopover contentSize 고정값:** 장치 수가 변하면 팝오버 크기도 변해야 한다. 동적으로 계산하거나 ScrollView로 처리.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 장치 연결/해제 감지 | 폴링으로 매번 전체 목록 비교 | `IOBluetoothDevice.register(forConnectNotifications:)` | 이벤트 기반, 효율적 |
| BT 장치 타입 분류 | 장치 이름 문자열 파싱 | `classOfDevice` 비트마스크 | Bluetooth SIG 표준, 신뢰성 높음 |
| 팝오버 내부 UI | AppKit NSView 직접 구현 | SwiftUI + NSHostingController | 선언적 UI, macOS 13+ 표준 |
| 배터리 읽기 코드 | 새로 작성 | Phase 1 IOKitProbe.swift 그대로 이식 | 검증된 코드, 중복 방지 |
| Dock 아이콘 숨기기 | activation policy 런타임 변경 | `LSUIElement` in Info.plist | 앱 시작 전부터 적용됨, 신뢰성 높음 |

**Key insight:** IOBluetooth와 AppKit이 이미 메뉴바 앱에 필요한 모든 인프라를 제공한다. custom solutions은 불필요.

---

## Common Pitfalls

### Pitfall 1: Xcode.app 부재로 인한 빌드 경로 혼선

**What goes wrong:** `xcodebuild`는 Xcode.app 없이 사용 불가능. 현재 환경에서 `xcodebuild -version` 실행 시 오류 발생. Phase 2 개발 초기부터 빌드 경로를 결정하지 않으면 작업 중단.

**Why it happens:** `xcodebuild`는 CLT 포함이지만 실행 시 Xcode.app을 요구하도록 설계됨.

**How to avoid:** Wave 0에서 즉시 결정: (A) Xcode.app 설치 (권장 — 이후 Phase 3/4에서도 필요) 또는 (B) 수동 `.app` 번들 + `swift build` + `codesign`으로 CLT-only 개발. 옵션 A가 장기적으로 맞는 선택.

**Warning signs:** `xcode-select: error: tool 'xcodebuild' requires Xcode` 오류 메시지.

### Pitfall 2: IOBluetoothDevice.pairedDevices()가 빈 배열 반환

**What goes wrong:** `com.apple.security.device.bluetooth` entitlement 없이 실행하면 `pairedDevices()`가 빈 배열을 반환한다. 개발 빌드(unsigned)에서도 entitlements 없이 실행하면 같은 현상.

**Why it happens:** macOS TCC(투명성, 동의 및 제어)가 bluetooth 접근을 entitlement + NSBluetoothAlwaysUsageDescription으로 제한.

**How to avoid:** `BTBatteryMonitor.entitlements` 파일에 반드시 포함:
```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.device.bluetooth</key><true/>
```
Info.plist에도:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>블루투스 장치 배터리 모니터링에 사용됩니다.</string>
```

**Warning signs:** `IOBluetoothDevice.pairedDevices()` 결과가 0개이지만 macOS 시스템 설정에 페어링된 장치가 있을 때.

### Pitfall 3: 장치 이름이 "Unknown"으로 반환됨 (Phase 1에서 확인)

**What goes wrong:** Phase 1 findings.md에서 확인된 문제: IOKit은 일부 장치를 "Unknown" 이름으로 반환한다. IOBluetoothDevice에서 동일한 문제 발생 가능.

**Why it happens:** IOKit의 `Product` 키와 `kIOHIDProductKey` 모두 nil인 경우. 장치가 BT HID 프로파일의 제품명 디스크립터를 제공하지 않음.

**How to avoid:** 다중 소스에서 이름 해석:
1. `IOBluetoothDevice.name` (IOBluetooth)
2. IOKit의 `Product` 키
3. IOKit의 `kIOHIDProductKey` 키
4. 모두 nil이면 "알 수 없는 장치" 표시

**Warning signs:** 팝오버에 "Unknown" 또는 빈 이름이 표시되는 장치.

### Pitfall 4: NSPopover 기본 크기와 스크롤 처리

**What goes wrong:** NSPopover의 `contentSize`가 고정이면 장치가 많을 때 내용이 잘린다. SwiftUI `List`나 `ScrollView` 없이 뷰를 직접 배치하면 스크롤 불가.

**Why it happens:** NSPopover는 contentViewController의 뷰 크기를 그대로 따른다.

**How to avoid:** PopoverView에 `ScrollView` + `LazyVStack` 조합 사용. 최대 높이를 400-500pt로 설정하고 스크롤 가능하게:
```swift
ScrollView {
    LazyVStack(spacing: 0) {
        ForEach(devices) { device in
            DeviceRowView(device: device)
        }
    }
}
.frame(width: 300)
.frame(maxHeight: 450)
```

### Pitfall 5: 폴링 타이머와 메인 스레드 UI 업데이트

**What goes wrong:** `probeIOKit()` 호출이 메인 스레드를 블록할 수 있다. iOS/macOS 앱에서 UI 업데이트를 백그라운드 스레드에서 하면 크래시.

**Why it happens:** IOKit 쿼리는 동기적이며 완료까지 수십 ms 걸릴 수 있음.

**How to avoid:** Task/async-await 또는 DispatchQueue.global()에서 배터리 읽기, 결과는 `@MainActor`에서 반영:
```swift
Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
    Task {
        let results = await Task.detached { probeIOKit() }.value
        await MainActor.run { self.updateModel(results) }
    }
}
```

---

## Code Examples

### 메뉴바 아이콘 동적 업데이트 (UI-01)

```swift
// Source: Apple AppKit NSStatusBarButton documentation
// 최저 배터리 % 또는 "연결된 장치 없음" 상태를 반영
func updateStatusBarIcon(lowestBattery: Int?) {
    guard let button = statusItem.button else { return }
    if let pct = lowestBattery {
        // 배터리 % 텍스트 표시 (Claude's discretion: 아이콘 + 숫자)
        button.title = "\(pct)%"
        button.image = batteryIcon(forPercent: pct)
    } else {
        button.title = ""
        button.image = NSImage(systemSymbolName: "bluetooth", accessibilityDescription: "BT Battery")
    }
}

func batteryIcon(forPercent pct: Int) -> NSImage? {
    // 배터리 레벨에 따른 SF Symbol 선택
    let symbolName: String
    switch pct {
    case 70...: symbolName = "battery.100"
    case 30..<70: symbolName = "battery.50"
    default: symbolName = "battery.25"
    }
    return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
}
```

### 팝오버 장치 행 뷰 (UI-04, D-02)

```swift
// SwiftUI DeviceRowView
struct DeviceRowView: View {
    let device: BluetoothDevice

    var body: some View {
        HStack(spacing: 12) {
            // 장치 타입 아이콘 (D-02)
            Image(systemName: device.type.symbolName)
                .frame(width: 20)
                .foregroundColor(device.batteryPercent == nil ? .secondary : .primary)

            // 장치 이름
            Text(device.name)
                .lineLimit(1)
                .foregroundColor(device.batteryPercent == nil ? .secondary : .primary)

            Spacer()

            if let pct = device.batteryPercent {
                // 배터리 프로그레스바 + %
                ProgressView(value: Double(pct), total: 100)
                    .frame(width: 60)
                    .tint(progressColor(for: pct))
                Text("\(pct)%")
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            } else {
                // D-04: 배터리 정보 없음
                Text("배터리 정보 없음")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    func progressColor(for pct: Int) -> Color {
        switch pct {
        case 70...: return .green
        case 30..<70: return .yellow
        default: return .red
        }
    }
}
```

### 정렬 로직 (D-03, D-04)

```swift
// 배터리 오름차순 정렬, 배터리 없는 장치는 하단
func sortedDevices(_ devices: [BluetoothDevice]) -> [BluetoothDevice] {
    devices.sorted { a, b in
        switch (a.batteryPercent, b.batteryPercent) {
        case (nil, nil): return false
        case (nil, _): return false   // nil → 하단
        case (_, nil): return true    // nil → 하단
        case let (pa?, pb?): return pa < pb  // 낮은 순서 (D-03)
        }
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSStatusItem + NSMenu만 사용 | NSStatusItem + NSPopover + SwiftUI content | macOS 13 / SwiftUI mature | 팝오버 내부를 SwiftUI로 선언적 구현 가능 |
| SwiftUI `@ObservableObject` | `@Observable` macro | macOS 14 | macOS 13 최소 타겟 → `@ObservableObject` 사용 |
| `SMLoginItemSetEnabled` | `SMAppService.mainApp.register()` | macOS 13 | Phase 4에서 LIFE-01 구현 시 신규 API 사용 |
| `IOBluetooth` 직접 배터리 읽기 | IOKit IORegistry `BatteryPercent` | 항상 이렇게 해야 함 | IOBluetooth는 배터리 직접 노출 없음 |
| Xcode 프로젝트 수동 관리 | XcodeGen (project.yml → .xcodeproj) | 2017~ | 팀 협업 시 merge conflicts 감소 (Phase 2는 1인 개발이므로 선택적) |

**Deprecated/outdated:**
- SwiftUI `MenuBarExtra` 단독 팝오버: `.window` style 제약이 많아 NSStatusItem + NSPopover가 실무적으로 선호됨
- `@ObservableObject` / `@StateObject`: macOS 14+에서 `@Observable` macro가 대체하지만 macOS 13 타겟에서는 여전히 사용

---

## Open Questions

1. **Xcode.app 설치 경로 결정**
   - What we know: 현재 환경에 Xcode.app 미설치, Homebrew 없음. 수동 `.app` 번들 방식으로 CLT-only 개발 가능하지만 불편함.
   - What's unclear: 사용자가 Xcode.app 설치에 동의하는지, 아니면 CLT-only 개발을 원하는지
   - Recommendation: Wave 0 첫 번째 작업으로 Xcode.app 설치 또는 CLT-only 빌드 스크립트 중 선택. Xcode 설치 강력 권장 (Phase 3/4에서도 필요).

2. **메뉴바 아이콘 표시 방식 (Claude's discretion)**
   - What we know: 아이콘만 vs 배터리% 포함 텍스트 — 사용자가 Claude에게 위임
   - Recommendation: 블루투스 아이콘 + 최저 배터리 % 텍스트 조합. 연결된 장치 없을 때는 아이콘만. 예: "🔵 43%"
   - Rationale: 메뉴바 클릭 없이도 가장 위험한 장치 배터리를 한눈에 확인 가능 (Core Value 직결)

3. **IOKit과 IOBluetooth 간 장치 매핑**
   - What we know: Phase 1에서 IOKit이 "Unknown" 이름으로 장치를 반환함. IOBluetooth는 `device.name`을 별도로 제공.
   - What's unclear: IOKit의 `BatteryPercent`와 IOBluetooth의 장치 이름을 신뢰성 있게 연결하는 방법 (MAC 주소 기반?)
   - Recommendation: `IOBluetoothDevice.addressString`과 IOKit 결과를 매핑하는 로직 연구 필요. Phase 2 구현 중 확인.

4. **macOS 13/14에서 Sandbox+IOKit 동작 검증**
   - What we know: macOS 26 Tahoe에서 IOKit이 Sandbox에서 동작 확인. macOS 13/14 미확인.
   - Recommendation: Phase 2 통합 테스트 시 주의. App Store 제출 전 반드시 macOS 13/14에서 검증.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Swift CLT | 코드 컴파일 | ✓ | 6.3 | — |
| IOKit (system) | BATT-01 | ✓ | System | — |
| IOBluetooth (system) | DISC-01, DISC-02, DISC-03 | ✓ | System | — |
| AppKit (system) | UI-01, UI-03, LIFE-02 | ✓ | System (macOS 13+) | — |
| SwiftUI (system) | UI-04 (팝오버 내부) | ✓ | System (macOS 13+) | NSView 직접 구현 |
| codesign | Entitlements 서명 | ✓ | /usr/bin/codesign | — |
| Xcode.app | xcodebuild, xcodeproj 빌드 | ✗ | 미설치 | 수동 .app 번들 (로컬 테스트 전용) |
| xcodebuild | 프로젝트 빌드 | ✗ | Xcode.app 필요 | swift build + 수동 번들 |
| Homebrew | XcodeGen, 기타 도구 설치 | ✗ | 미설치 | 직접 다운로드 또는 App Store |

**Missing dependencies with no fallback (blocking for full distribution):**
- `Xcode.app`: App Store 제출 또는 Notarization을 위한 xcodebuild가 필요. Phase 2 개발·로컬 테스트는 수동 번들로 가능하지만, 배포를 위해서는 Xcode 설치 필요.

**Missing dependencies with fallback (non-blocking for development):**
- `xcodebuild`: `swift build` + 수동 `.app` 번들 구조로 로컬 실행 가능. 배포 제약 있음.
- `Homebrew`: XcodeGen을 Homebrew 없이 GitHub Releases에서 직접 다운로드 가능.

**Recommended Wave 0 action:** Xcode.app 설치 결정. 설치 시 표준 Xcode 프로젝트 경로로 진행. 미설치 시 수동 번들 빌드 스크립트를 Wave 0에서 작성.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode 내장) |
| Config file | BTBatteryMonitorTests 타깃 (Wave 0에서 생성) |
| Quick run command | `xcodebuild test -scheme BTBatteryMonitor -destination 'platform=macOS'` |
| Full suite command | `xcodebuild test -scheme BTBatteryMonitor -destination 'platform=macOS'` |

**CLT-only 대안 (Xcode 미설치 시):**
- 수동 유닛 테스트: `swift test` (SPM 패키지 구조인 경우)
- 연기: Xcode 설치 후 XCTest 타깃 추가

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DISC-01 | 연결된 BT 장치 목록이 비어있지 않다 (페어링 장치 있을 때) | integration (실기기 필요) | manual + 코드 확인 | ❌ Wave 0 |
| DISC-02 | Magic Mouse → mouse 타입, AirPods → headset 타입 분류 | unit | `swift test --filter DeviceTypeTests` | ❌ Wave 0 |
| DISC-03 | 장치 연결 시 목록이 갱신된다 | manual (실기기 + BT 토글) | manual | — |
| BATT-01 | IOKit 배터리 읽기 결과가 0~100 범위 | unit | `swift test --filter BatteryServiceTests` | ❌ Wave 0 |
| BATT-04 | batteryPercent가 nil인 장치는 "배터리 정보 없음" 표시 | unit (SwiftUI preview 또는 XCTest) | `swift test --filter DeviceRowViewTests` | ❌ Wave 0 |
| UI-01 | 메뉴바 아이콘이 표시된다 | smoke (앱 실행 확인) | manual (open BTBatteryMonitor.app) | — |
| UI-03 | 클릭 시 팝오버 표시 | smoke (manual) | manual | — |
| UI-04 | 팝오버에 이름/아이콘/배터리 표시 | snapshot 또는 manual | manual | — |
| LIFE-02 | Dock에 아이콘 없음 | smoke | manual (앱 실행 후 Dock 확인) | — |

### Sampling Rate

- Per task commit: `swift build` 성공 확인
- Per wave merge: 수동 연기 테스트 + unit test 통과 (`swift test`)
- Phase gate: 모든 Success Criteria 5개 수동 검증 완료

### Wave 0 Gaps

- [ ] Xcode.app 설치 또는 수동 빌드 스크립트 결정
- [ ] `BTBatteryMonitorTests/` 타깃 생성 (XCTest)
- [ ] `DeviceTypeTests.swift` — DISC-02 커버 (classOfDevice 비트마스크 분류 단위 테스트)
- [ ] `BatteryServiceTests.swift` — BATT-01 커버 (IOKitProbe 이식 코드 결과 검증)
- [ ] `SortingTests.swift` — D-03/D-04 정렬 로직 단위 테스트
- [ ] `Info.plist` — LSUIElement, NSBluetoothAlwaysUsageDescription 포함
- [ ] `BTBatteryMonitor.entitlements` — app-sandbox + device.bluetooth

---

## Sources

### Primary (HIGH confidence)
- `bt-battery-probe/Results/findings.md` — Phase 1 실증 결과 (IOKit sandbox, device enumeration)
- `bt-battery-probe/Sources/bt-battery-probe/IOKitProbe.swift` — 재사용할 배터리 읽기 코드 직접 확인
- Apple AppKit documentation (NSStatusItem, NSPopover, NSStatusBarButton) — 시스템 프레임워크
- Apple IOBluetooth documentation (IOBluetoothDevice.pairedDevices, classOfDevice, register(forConnectNotifications:)) — 시스템 프레임워크

### Secondary (MEDIUM confidence)
- [polpiella.dev — A menu bar only macOS app using AppKit](https://www.polpiella.dev/a-menu-bar-only-macos-app-using-appkit/) — NSStatusItem + AppDelegate 패턴
- [nilcoalescing.com — Build a macOS menu bar utility in SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) — MenuBarExtra + SwiftUI 비교
- [gist.github.com/jamesmartin](https://gist.github.com/jamesmartin/9847466aba513de9a77507b56e712296) — IOBluetoothDevice.pairedDevices() Swift 예제
- [Swift Forums: Building .app from SPM executable](https://forums.swift.org/t/building-an-app-from-a-swift-package-manager-executable-for-macos/64409) — 수동 번들 빌드 방법
- [tmewett.com — Making a Mac Application Bundle manually](https://tmewett.com/making-macos-bundle-info-plist/) — 수동 .app 구조

### Tertiary (LOW confidence — needs validation)
- classOfDevice 비트마스크 상수값 (0x04=Audio, 0x05=Peripheral): Bluetooth SIG Class of Device 표준에서 유래. Swift 코드에서 실제 enum 상수 확인 필요.
- macOS 13/14에서 IOKit + App Sandbox 동작: macOS 26 Tahoe에서만 실증 확인됨 (findings.md). 하위 버전에서 동작 여부 LOW confidence.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 시스템 프레임워크, Phase 1에서 IOKit 확인, Swift 6.3 설치 확인
- Architecture: HIGH — NSStatusItem + NSPopover 패턴은 수많은 macOS 메뉴바 앱에서 검증됨
- IOBluetooth device enumeration: MEDIUM — API 패턴 확인됨, classOfDevice 비트마스크는 런타임 확인 필요
- Pitfalls: HIGH — Phase 1 findings.md에서 "Unknown" 이름 문제 실증 확인, Sandbox entitlement 누락 시 빈 배열 문제 복수 소스 확인
- Build path (Xcode 없음): HIGH — `xcodebuild` 직접 시도 결과 오류 확인됨

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (안정적인 Apple 시스템 프레임워크; 빠른 변경 없음)
