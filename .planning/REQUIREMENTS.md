# Requirements: BT Battery Monitor

**Defined:** 2026-03-27
**Core Value:** 블루투스 장치의 배터리 잔량을 메뉴바에서 아이콘과 퍼센트로 한눈에 확인할 수 있어야 한다.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Feasibility Validation

- [x] **FEAS-01**: `ioreg` 명령으로 연결된 블루투스 장치의 배터리 레벨 노출 여부를 확인할 수 있다
- [x] **FEAS-02**: App Sandbox 환경에서 IOKit을 통한 배터리 레벨 읽기가 가능한지 확인한다
- [x] **FEAS-03**: BLE GATT Battery Service (0x180F)를 통한 배터리 읽기 가능 여부를 확인한다

### Device Discovery

- [x] **DISC-01**: macOS에 연결된 모든 블루투스 장치 목록을 탐지하여 표시한다
- [x] **DISC-02**: 각 장치의 타입(키보드/마우스/헤드셋/기타)을 식별하여 적절한 아이콘으로 표시한다
- [x] **DISC-03**: 장치 연결/해제 상태 변화를 실시간으로 감지하여 UI에 반영한다

### Battery Reading

- [x] **BATT-01**: IOKit IORegistry를 통해 장치의 배터리 레벨(%)을 읽는다
- [x] **BATT-02**: CoreBluetooth BLE GATT Battery Service(0x180F)를 통해 배터리 레벨을 읽는다
- [x] **BATT-03**: 설정 가능한 주기(기본 5분)로 배터리 레벨을 자동 갱신한다
- [x] **BATT-04**: 배터리 정보를 노출하지 않는 장치는 "배터리 정보 없음"으로 명확히 표시한다

### Menu Bar UI

- [x] **UI-01**: macOS 메뉴바에 배터리 아이콘과 퍼센트(%)를 표시한다
- [ ] **UI-02**: 배터리 레벨에 따라 아이콘/텍스트 색상을 변경한다 (녹색: 70%+, 노랑: 30-70%, 빨강: 30% 미만)
- [x] **UI-03**: 메뉴바 클릭 시 전체 장치 배터리 상세 팝오버를 표시한다
- [x] **UI-04**: 팝오버에 각 장치의 이름, 타입 아이콘, 배터리 레벨, 연결 상태를 표시한다

### Device Management

- [ ] **MGMT-01**: 사용자가 모니터링할 장치를 선택/해제할 수 있다
- [x] **MGMT-02**: 장치 선택 설정이 앱 재시작 후에도 유지된다 (UserDefaults)
- [ ] **MGMT-03**: 사용자가 배터리 갱신 폴링 간격을 설정할 수 있다

### App Lifecycle

- [ ] **LIFE-01**: macOS 로그인 시 자동으로 앱이 실행된다 (SMAppService)
- [x] **LIFE-02**: Dock에 아이콘이 표시되지 않는 메뉴바 전용 앱으로 동작한다
- [ ] **LIFE-03**: macOS sleep/wake 시 블루투스 상태를 올바르게 복구한다

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Notifications

- **NOTF-01**: 배터리가 설정한 임계값 이하로 떨어지면 macOS 알림을 표시한다
- **NOTF-02**: 사용자가 알림 임계값을 설정할 수 있다

### Advanced Features

- **ADV-01**: 배터리 사용 히스토리/트렌드 차트를 표시한다
- **ADV-02**: 잔여 사용 시간을 추정하여 표시한다
- **ADV-03**: macOS 위젯(WidgetKit)으로 배터리 정보를 표시한다
- **ADV-04**: 장치에 사용자 별명을 부여할 수 있다
- **ADV-05**: 키보드 단축키로 배터리 상태를 빠르게 확인할 수 있다

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| 배터리 충전 제어 | 읽기 전용 모니터링만 -- 하드웨어 레벨 접근 위험 |
| Windows/Linux 지원 | macOS 네이티브 API(IOKit/CoreBluetooth) 전용 |
| 블루투스 연결 관리 | 별도 영역 (ToothFairy/AirBuddy 등 기존 앱 존재) |
| 오디오 라우팅/전환 | 배터리 모니터링과 무관 |
| 클라우드 동기화/계정 | 로컬 전용 유틸리티 |
| 분석/텔레메트리 | 프라이버시 -- 네트워크 호출 없음 |
| 구독 결제 모델 | 유틸리티 앱은 무료 또는 일회 구매 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FEAS-01 | Phase 1 | Complete |
| FEAS-02 | Phase 1 | Complete |
| FEAS-03 | Phase 1 | Complete |
| DISC-01 | Phase 2 | Complete |
| DISC-02 | Phase 2 | Complete |
| DISC-03 | Phase 2 | Complete |
| BATT-01 | Phase 2 | Complete |
| BATT-02 | Phase 3 | Complete |
| BATT-03 | Phase 3 | Complete |
| BATT-04 | Phase 2 | Complete |
| UI-01 | Phase 2 | Complete |
| UI-02 | Phase 4 | Pending |
| UI-03 | Phase 2 | Complete |
| UI-04 | Phase 2 | Complete |
| MGMT-01 | Phase 3 | Pending |
| MGMT-02 | Phase 3 | Complete |
| MGMT-03 | Phase 3 | Pending |
| LIFE-01 | Phase 4 | Pending |
| LIFE-02 | Phase 2 | Complete |
| LIFE-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-03-27 after roadmap creation*
