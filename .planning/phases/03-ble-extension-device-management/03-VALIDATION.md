---
phase: 03-ble-extension-device-management
nyquist_compliant: true
wave_0_complete: false
updated: 2026-03-27
---

# Phase 3 Validation Architecture

## Test Framework

| Property | Value |
|----------|-------|
| Framework | swift build (컴파일 smoke test) |
| Quick run | `cd BTBatteryMonitor && swift build -c debug 2>&1 \| tail -5` |
| Full suite | `cd BTBatteryMonitor && bash build.sh 2>&1 \| tail -5` |
| Notes | 모든 요구사항이 실제 BT 하드웨어 또는 UI 상호작용 필요 → manual-only 보완 |

## Per-Task Verification Map

| Task ID | Requirement | Automated Command | Manual Verification |
|---------|-------------|-------------------|---------------------|
| 03-01-T1 | BATT-02, BATT-03, MGMT-02 | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && swift build -c debug 2>&1 \| tail -5` | — |
| 03-01-T2 | BATT-02, BATT-03, MGMT-01, MGMT-02 | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && swift build -c debug 2>&1 \| tail -5` | — |
| 03-02-T1 | MGMT-01, MGMT-03 | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && swift build -c debug 2>&1 \| tail -5` | — |
| 03-02-T2 | MGMT-01, MGMT-03 | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && swift build -c debug 2>&1 \| tail -5` | — |
| 03-03-T1 | all | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && bash build.sh 2>&1 \| tail -5` | — |
| 03-03-T2 | BATT-02, BATT-03, MGMT-01, MGMT-02, MGMT-03 | CHECKPOINT — human verification required | 앱 실행 후 수동 확인 |

## Manual-Only Verification

| Requirement | Why Manual | How to Verify |
|-------------|-----------|---------------|
| BATT-02 | 실제 BLE 장치(AirPods 등) 또는 Keychron K3 필요 | 앱 팝오버에서 배터리% 확인 |
| BATT-03 | 실제 시간 경과 필요 | 폴링 간격 1분 설정 후 1분 대기 → 값 갱신 확인 |
| MGMT-01 | UI 토글 상호작용 필요 | 장치 toggle → 앱 재시작 → 선택 유지 확인 |
| MGMT-02 | 앱 재시작 필요 | 설정 저장 후 `pkill BTBatteryMonitor && open BTBatteryMonitor.app` |
| MGMT-03 | Settings 창 UI 상호작용 필요 | 헤더 설정 버튼 클릭 → NSPanel 열림 → Picker로 간격 변경 |

## Sampling Rate Sign-off

- [x] Per-task: `swift build -c debug` — 5/6 auto 태스크 커버
- [x] Per-wave: Wave 1/2/3 각 종료 시 `swift build` 또는 `bash build.sh`
- [x] Phase gate: `open BTBatteryMonitor.app` 후 03-03-T2 human checkpoint
- [x] No 3 consecutive tasks without automated verify
- [x] Wave 0 gaps: N/A (신규 파일들은 Wave 1에서 생성됨)
