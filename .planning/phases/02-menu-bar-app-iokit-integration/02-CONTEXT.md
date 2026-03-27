# Phase 2: Menu Bar App + IOKit Integration - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1의 IOKitProbe 코드를 재사용하여, 연결된 블루투스 장치의 배터리 레벨을 메뉴바 아이콘과 팝오버 리스트로 표시하는 macOS 네이티브 앱을 구현한다. 대상 장치는 IOKit을 통해 배터리를 노출하는 장치(마우스, 헤드셋, 트랙패드 등). 기계식 키보드는 D-05에 따라 이번 Phase 제외 (FN+B 전용 표시 방식).

설정 패널, 로그인 항목, BLE 갱신은 이 Phase 밖이다.

</domain>

<decisions>
## Implementation Decisions

### 팝오버 레이아웃
- **D-01:** 팝오버는 **리스트형** — 스크롤 가능한 세로 목록
- **D-02:** 각 행 정보: `[장치 타입 아이콘] [장치 이름] [배터리 프로그레스바] [배터리%]`
  - 예시: 🖱️ Magic Mouse ██████░░ 72%
  - SF Symbols로 장치 타입 아이콘 표현 (마우스, 헤드폰, 키보드 등)
- **D-03:** 정렬 순서: **배터리 낮은 순서 (오름차순)** — 가장 주의가 필요한 장치가 상단
- **D-04:** 배터리 정보가 없는 장치: 리스트에 **포함**, 회색으로 표시 + "배터리 정보 없음" 텍스트
  - 리스트 하단에 배치 (정렬 기준 후순위)
- **D-05:** 팝오버 상단 **헤더 포함**: 앱 이름 + 전체 장치 요약
  - 예시: "BT Battery Monitor  •  3개 장치"

### Phase 1 코드 재사용 (Prior D-03)
- **D-06:** `bt-battery-probe/Sources/bt-battery-probe/IOKitProbe.swift`의 `probeIOKit()` 함수를 앱 배터리 서비스 레이어로 추출하여 재사용
- **D-07:** Phase 1 결과 기준, 배터리 읽기 전략은 IOKit 우선 (BLE GATT는 Phase 3으로 연기)

### App Sandbox (Prior D-07)
- **D-08:** App Sandbox + Hardened Runtime 유지 — Phase 1에서 IOKit이 Sandbox에서 동작 확인됨

### Claude's Discretion
- 메뉴바 아이콘 표시 방식 (아이콘만 vs 배터리% 포함 텍스트) — Claude 결정
- 앱 프레임워크 선택 (SwiftUI MenuBarExtra vs AppKit NSStatusItem+NSPopover) — Claude 결정
  - macOS 13+ 대상이므로 SwiftUI MenuBarExtra 가능, 하지만 NSPopover가 더 안정적일 수 있음
- 배터리 갱신 주기/전략 (폴링 기본값, 앱 시작 시 즉시 읽기 등) — Claude 결정
- Xcode 프로젝트 구조 및 타깃 설정 — Claude 결정

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 결과
- `.planning/phases/01-feasibility-validation/01-CONTEXT.md` — D-01~D-10 결정사항 (배포 전략, Sandbox 결과 등)
- `.planning/phases/01-feasibility-validation/01-RESEARCH.md` — IOKit/BLE/HID API 리서치 결과
- `bt-battery-probe/Results/findings.md` — Phase 1 실증 결과 (FEAS-01/02/03, D-09 배포 결정)
- `bt-battery-probe/Sources/bt-battery-probe/IOKitProbe.swift` — 재사용할 IOKit 코드

### 요구사항
- `.planning/REQUIREMENTS.md` §Device Discovery — DISC-01, DISC-02, DISC-03
- `.planning/REQUIREMENTS.md` §Battery Reading — BATT-01, BATT-04
- `.planning/REQUIREMENTS.md` §Menu Bar UI — UI-01, UI-03, UI-04
- `.planning/REQUIREMENTS.md` §App Lifecycle — LIFE-02

### 프로젝트 컨텍스트
- `.planning/PROJECT.md` — Core Value, Constraints, Key Decisions

No external specs — Apple system frameworks (AppKit/SwiftUI/IOKit) only.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bt-battery-probe/Sources/bt-battery-probe/IOKitProbe.swift` — `probeIOKit()` 함수: IOKit IORegistry에서 BT 장치 배터리 데이터 읽기. Phase 2 배터리 서비스 레이어로 직접 이식 가능
- `bt-battery-probe/Sources/bt-battery-probe/BLEProbe.swift` — CoreBluetooth BLE probe (Phase 3에서 활용 예정)
- `bt-battery-probe/Package.swift` — SPM 설정 (IOKit/CoreBluetooth linker flags 포함)

### Established Patterns
- IOKit 결과 구조: `{ Product: String, BatteryPercent: Int? }` 배열
- Sandbox에서 IOKit 동작 확인됨 (macOS 26 Tahoe 기준, 13/14 재확인 필요)

### Integration Points
- Phase 2 앱이 Phase 1 CLI 코드에서 IOKitProbe 로직을 추출하여 서비스 레이어로 구성
- 메뉴바 앱은 별도 Xcode 프로젝트로 생성 (Phase 1 SPM 패키지와 분리)

</code_context>

<specifics>
## Specific Ideas

- 팝오버 레이아웃 참고: macOS 시스템 메뉴바 앱들(배터리 메뉴, Wi-Fi 메뉴)과 유사한 스타일
- 배터리 색상: 녹색(70%+), 노랑(30~70%), 빨강(30% 미만) — REQUIREMENTS.md UI-02 기준
- "BT Battery Monitor • 3개 장치" 헤더 포맷

</specifics>

<deferred>
## Deferred Ideas

- BLE GATT 배터리 읽기 (0x180F) → Phase 3
- 배터리 부족 알림 (macOS 알림 센터) → v2
- 장치 선택/해제 설정 → Phase 3
- 배터리 갱신 주기 사용자 설정 → Phase 3
- Login Items (앱 자동 시작) → Phase 3/4

</deferred>

---

*Phase: 02-menu-bar-app-iokit-integration*
*Context gathered: 2026-03-27 via /gsd:discuss-phase*
