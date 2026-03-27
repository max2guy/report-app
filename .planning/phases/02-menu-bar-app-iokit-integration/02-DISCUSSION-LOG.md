# Phase 2: Menu Bar App + IOKit Integration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 02-menu-bar-app-iokit-integration
**Areas discussed:** 팝오버 레이아웃

---

## 팝오버 레이아웃

| Option | Description | Selected |
|--------|-------------|----------|
| 리스트형 | 스크롤 가능한 세로 목록. macOS 시스템 앱 스타일과 일치 | ✓ |
| 카드형 그리드 | 장치 하나당 카드 한 칸. 장치 많으면 팝오버 커짐 | |

**User's choice:** 리스트형

---

## 행 표시 정보

| Option | Description | Selected |
|--------|-------------|----------|
| 아이콘 + 이름 + 배터리% + 프로그레스바 | 시각적 명확성 | ✓ |
| 상태 아이콘 + 이름 + 배터리% | 더 간결 | |
| 이름 + 배터리%만 | 최소한의 정보 | |

**User's choice:** 아이콘 + 이름 + 배터리% + 프로그레스바

---

## 정렬 순서

| Option | Description | Selected |
|--------|-------------|----------|
| 배터리 낮은 순서 | 가장 주의 필요한 장치 상단. Core Value 일치 | ✓ |
| 이름 알파벳 순 | 일관된 순서 | |
| 연결 순서 (FIFO) | 예측 어려움 | |

**User's choice:** 배터리 낮은 순서 (오름차순)

---

## 배터리 정보 없는 장치 처리

| Option | Description | Selected |
|--------|-------------|----------|
| 리스트에 포함, '배터리 정보 없음' | 모든 BT 장치 표시. 투명성 | ✓ |
| 리스트에서 필터링 (숨김) | 배터리 노출 장치만 표시 | |

**User's choice:** 리스트에 포함, 회색 + '배터리 정보 없음'

---

## 팝오버 헤더

| Option | Description | Selected |
|--------|-------------|----------|
| 넣음 — 앱 이름 + 전체 요약 | 예: "BT Battery Monitor • 3개 장치" | ✓ |
| 없음 — 장치 리스트 바로 | 간결 | |
| 설정/종료 버튼만 | 하단에 버튼 배치 | |

**User's choice:** 앱 이름 + 전체 요약 헤더

---

## Claude's Discretion

- 메뉴바 아이콘 표시 방식
- 앱 프레임워크 (SwiftUI MenuBarExtra vs AppKit)
- 배터리 갱신 전략
- Xcode 프로젝트 구조
