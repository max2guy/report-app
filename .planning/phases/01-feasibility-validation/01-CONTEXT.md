# Phase 1: Feasibility Validation - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

블루투스 키보드(및 기타 BT 장치)에서 배터리 데이터를 macOS API로 읽을 수 있는지 검증하는 기술 스파이크. UI 없음. 코드와 문서가 결과물. 이 Phase의 결과가 Phase 2 구현 방향과 배포 전략을 결정한다.

</domain>

<decisions>
## Implementation Decisions

### 산출물 형태
- **D-01:** Swift CLI 툴을 제작한다 — IOKit, BLE GATT (0x180F), HID 세 가지 방식을 모두 테스트하는 실행 가능한 커맨드라인 도구
- **D-02:** CLI 툴이 각 방식의 결과를 출력한다 (장치명, 배터리 %, API 경로)
- **D-03:** CLI 코드는 Phase 2에서 재사용할 기반이 된다

### Go/No-Go 기준
- **D-04:** Go 기준: 사용자의 실제 블루투스 키보드에서 배터리 레벨 읽기 성공 (Strict)
- **D-05:** 키보드에서 배터리 읽기 실패 시: 프로젝트 중단하지 않음. 대신 "블루투스 마우스 등 배터리를 노출하는 다른 무선 장치"를 주요 지원 대상으로 포함하여 범위 확장
- **D-06:** 키보드 미지원 판명 시 ROADMAP.md의 Phase 설명을 업데이트하여 지원 장치 범위를 명확히 한다

### App Sandbox 전략
- **D-07:** Swift CLI를 처음부터 App Sandbox + Hardened Runtime 환경에서 빌드하여 테스트한다
- **D-08:** Sandbox에서 IOKit 접근이 차단되는지 Phase 1에서 확인한다

### 배포 방식 결정
- **D-09:** Phase 1 결과로 즉시 결정:
  - Sandbox에서 IOKit 동작 → Mac App Store 배포 가능
  - Sandbox에서 IOKit 차단 → Notarization 직접 배포 (.dmg) 로 확정
- **D-10:** 배포 방식 결정을 Phase 1 완료 보고서에 포함한다

### Claude's Discretion
- CLI 구체적인 구현 방식(flag 설계, 출력 포맷) — Claude가 결정
- 세 가지 API 테스트 순서 — IOKit → BLE GATT → HID 순서로 Claude가 결정

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — 프로젝트 비전, 제약사항, 결정 사항
- `.planning/REQUIREMENTS.md` §Feasibility Validation — FEAS-01, FEAS-02, FEAS-03 요구사항

### Research
- `.planning/research/STACK.md` — Swift/IOKit/CoreBluetooth 스택 권장사항
- `.planning/research/ARCHITECTURE.md` — 3-layer BT 전략 (IOKit → BLE GATT → IOBluetooth)
- `.planning/research/PITFALLS.md` — App Sandbox+IOKit 함정, BT 배터리 읽기 주의사항

No external specs beyond Apple system frameworks — no third-party libraries needed.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- 없음 — 완전히 새로운 Swift 프로젝트 (기존 report-app은 별개)

### Established Patterns
- 없음 — 새 Xcode 프로젝트에서 시작

### Integration Points
- Phase 1 CLI 코드 → Phase 2 앱에서 배터리 읽기 서비스 레이어로 재사용

</code_context>

<specifics>
## Specific Ideas

- 사용자의 키보드: RGB LED 모델, FN+B로 배터리 확인 시 적(0~30%), 청(30~70%), 녹(70~100%) — 이 키보드가 IOKit/BLE에 배터리를 노출하는지 테스트해야 함
- `ioreg -r -c IOBluetoothDevice | grep -i battery` 가 Phase 1의 첫 번째 수동 테스트

</specifics>

<deferred>
## Deferred Ideas

- 블루투스 마우스 등 추가 장치 지원 상세 구현 — Phase 2 이후에서 결정
- App Store 심사 전략 — Phase 1 Sandbox 결과 이후에 결정

</deferred>

---

*Phase: 01-feasibility-validation*
*Context gathered: 2026-03-27*
