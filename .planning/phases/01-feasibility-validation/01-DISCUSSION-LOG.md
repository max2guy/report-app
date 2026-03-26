# Phase 1: Feasibility Validation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 01-feasibility-validation
**Areas discussed:** 검증 산출물, Go/No-Go 기준, Sandbox 전략, 배포 방식 결정

---

## 검증 산출물

| Option | Description | Selected |
|--------|-------------|----------|
| Swift CLI 툴 | 실제 동작하는 Swift 스크립트 + 결과 문서화. 코드가 Phase 2 기반이 됨 | ✓ |
| 문서만 | ioreg 출력 스크린샷 + BLE 스캔 결과 기록 문서 | |
| CLI + 문서 | Swift CLI 툴과 결과 보고서 둘 다 산출 | |

**User's choice:** Swift CLI 툴
**Notes:** CLI 범위 — 3가지 모두 (IOKit + BLE GATT + HID 방식 전체 테스트)

---

## Go/No-Go 기준

| Option | Description | Selected |
|--------|-------------|----------|
| 내 키보드 성공 (Strict) | 사용자의 실제 키보드에서 배터리를 읽어야 Phase 2 진행 | ✓ |
| 임의 BT 장치 성공 (Pragmatic) | 어떤 BT 장치라도 배터리를 읽으면 Phase 2 진행 | |
| API 존재 여부만 | IOKit/BLE API가 동작하면 통과, 데이터 유무는 Phase 2 이후 결정 | |

**User's choice:** 내 키보드 성공 (Strict)
**Notes:** 키보드가 배터리를 노출하지 않는 경우 → 프로젝트 중단 없이 범위 확장. 블루투스 마우스 등 배터리 인식되는 다른 무선 장치도 지원 대상에 추가하여 개발 계속 진행.

---

## Sandbox 전략

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 1에서 증명 (Recommended) | Swift CLI를 처음부터 Sandbox+Hardened Runtime으로 빌드 | ✓ |
| Phase 2 시작 시 테스트 | 먼저 배터리 동작 확인 후 Sandbox 제약 확인 | |

**User's choice:** Phase 1에서 증명
**Notes:** 조기 Sandbox 테스트로 배포 제약을 일찍 파악

---

## 배포 방식 결정

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 1 결과로 즉시 결정 (Recommended) | Sandbox OK → App Store, Sandbox 차단 → Notarization 직접 배포 | ✓ |
| Phase 4(완성)에서 결정 | 배포 방식은 마지막에 결정 | |

**User's choice:** Phase 1 결과로 즉시 결정
**Notes:** 결정을 Phase 1 완료 보고서에 포함

---

## Claude's Discretion

- CLI flag 설계, 출력 포맷
- 세 가지 API 테스트 순서 (IOKit → BLE GATT → HID)

## Deferred Ideas

- 블루투스 마우스 등 추가 장치 지원 상세 구현 → Phase 2 이후
- App Store 심사 전략 → Phase 1 Sandbox 결과 이후
