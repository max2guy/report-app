# BT Battery Monitor

## What This Is

macOS 메뉴바 네이티브 앱으로, 블루투스 장치의 배터리 잔량을 실시간으로 모니터링한다. macOS에서 배터리 레벨을 기본 제공하지 않는 블루투스 장치(예: 기계식 키보드)도 지원하는 것이 목표이다. 사용자가 모니터링할 장치를 선택할 수 있다.

## Core Value

블루투스 장치의 배터리 잔량을 메뉴바에서 아이콘과 퍼센트로 한눈에 확인할 수 있어야 한다.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] macOS 메뉴바에 배터리 아이콘과 퍼센트(%) 표시
- [ ] 연결된 블루투스 장치 목록 탐지 및 표시
- [ ] 사용자가 모니터링할 장치를 선택/해제
- [ ] 배터리 레벨을 지원하지 않는 장치의 배터리 정보 읽기 (IOKit/BLE GATT 등 리서치 필요)
- [ ] 배터리 잔량에 따른 아이콘 색상/상태 변화
- [ ] 메뉴바 클릭 시 전체 장치 배터리 상세 팝오버
- [ ] 앱 시작 시 자동 실행 (Login Items)
- [ ] 주기적 배터리 레벨 갱신

### Out of Scope

- 배터리 부족 알림 (macOS 알림 센터) — v2로 미룸
- Windows/Linux 지원 — macOS 전용
- 웹/PWA 버전 — 네이티브 앱으로 결정
- 배터리 충전 제어 — 읽기 전용 모니터링만

## Context

- 사용자의 블루투스 키보드는 RGB LED 모델로, FN+B로 배터리 확인 시:
  - 적색: 0~30%
  - 청색: 30~70%
  - 녹색: 70~100%
- macOS는 일부 블루투스 장치(AirPods, Magic Keyboard 등)의 배터리를 기본 표시하지만, 서드파티 기계식 키보드 등은 지원하지 않음
- 배터리 레벨 읽기 방식 리서치 필요: IOKit/IOBluetooth, BLE GATT Battery Service (0x180F), HID 프로토콜 등
- Swift/SwiftUI + AppKit으로 개발 (macOS 네이티브 메뉴바 앱)
- 기존 report-app과는 별개의 독립 프로젝트

## Constraints

- **Tech Stack**: Swift/SwiftUI — macOS 네이티브 메뉴바 앱
- **Platform**: macOS 13+ (Ventura 이상)
- **BT Protocol**: 장치가 배터리 레벨을 BLE/HID로 노출하지 않으면 읽기 불가능할 수 있음 — 리서치 후 확인
- **Sandboxing**: App Sandbox 환경에서 블루투스 접근 권한 필요

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| macOS 네이티브 앱 (Swift/SwiftUI) | 시스템 BT API 직접 접근, 메뉴바 통합 | — Pending |
| 배터리 읽기 방식 | IOKit/BLE GATT 등 리서치 후 결정 | — Pending |
| 알림 기능 v2 연기 | 우선 메뉴바 표시부터, 알림은 나중에 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-26 after initialization*
