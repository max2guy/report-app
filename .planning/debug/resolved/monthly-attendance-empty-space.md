---
status: resolved
<!-- attempt 2 -->
trigger: "연속결석 패널과 최근8주추이 패널이 나란히 배치될 때, 연속결석 패널 아래 빈 공간이 생긴다. 이 빈 공간에 '월별 평균 출석률' 섹션이 들어가야 한다."
created: 2026-03-26T00:00:00Z
updated: 2026-03-26T00:00:00Z
---

## Current Focus

hypothesis: grid-row: span 2 단독으로는 auto-placement가 card4를 col1 row3이 아닌 row4에 배치함
test: 각 카드에 grid-column + grid-row 명시적 좌표 지정
expecting: card2(col1,row2) + card3(col2,row2-3) + card4(col1,row3) + card5(col1/-1,row4) 레이아웃
next_action: 사용자 확인 대기 (commit cbd4b8f, v99)

## Symptoms

expected: 연속결석 패널이 최근8주추이 패널보다 짧을 때, 연속결석 패널 아래 남는 빈 공간에 "월별 평균 출석률" 섹션이 채워져야 한다
actual: 현재는 "월별 평균 출석률" 섹션이 두 패널(연속결석 + 최근8주추이) 모두 끝난 아래에 별도 행으로 배치되어 있어 빈 공간이 낭비됨
errors: 없음 (레이아웃 개선 요청)
reproduction: 앱을 열어 중고등부/청년부 탭 확인 - 연속결석 패널 아래 빈 공간과 그 아래 월별평균출석률 섹션이 보임
started: 현재 레이아웃에서 개선 필요

## Eliminated

- hypothesis: 월별평균출석률이 잘못된 위치에 렌더링됨
  evidence: JS 코드에서 카드 순서는 올바름 (1:요약, 2:연속결석, 3:최근8주추이, 4:월별평균출석률, 5:전체기록)
  timestamp: 2026-03-26T00:00:00Z

- hypothesis: nth-child(4) full-width 규칙 제거 + nth-child(3) grid-row:span 2로 해결 가능
  evidence: 수정 후에도 card4가 두 패널 아래에 배치됨 - CSS grid auto-placement가 span된 card3 옆 공백(col1 row3)을 채우지 않고 card4를 row4에 배치
  timestamp: 2026-03-26T01:00:00Z

## Evidence

- timestamp: 2026-03-26T00:00:00Z
  checked: viewer.html CSS @media (min-width: 768px) 규칙
  found: |
    .tab-panel.active > .card:nth-child(4) { grid-column: 1 / -1; }
    이 규칙이 월별평균출석률(4번 카드)을 전체폭으로 강제 배치
  implication: nth-child(4) 규칙을 제거하면 자연스럽게 좌측 열로 흐름

- timestamp: 2026-03-26T00:00:00Z
  checked: 카드 순서 (renderYouthPanel/renderYoungPanel 함수)
  found: |
    1: 요약 카드 (first-child → full-width)
    2: 연속결석 카드 (col1, row2)
    3: 최근8주추이 카드 (col2, row2)
    4: 월별평균출석률 카드 (현재 full-width → col1 row3으로 변경 필요)
    5: 전체주일기록 카드 (last-child → full-width)
  implication: 최근8주추이가 2열을 span하면 월별평균출석률이 1열 아래에 자연 배치됨

- timestamp: 2026-03-26T00:00:00Z
  checked: consec-large 예외처리
  found: |
    .tab-panel.active > .card.consec-large ~ .card:nth-child(4) { grid-column: auto; }
    연속결석 6명+일 때는 이미 월별분석을 auto로 설정
  implication: 6명+ 케이스 별도 처리 필요 없음 (기본 케이스에서 auto)

- timestamp: 2026-03-26T01:00:00Z
  checked: CSS grid auto-placement 동작 원리
  found: |
    grid-row: span 2를 card3에 적용해도 card4가 col1 row3 빈 공간을 채우지 않음.
    CSS grid auto-placement는 기본적으로 앞으로만 진행(forward-only)하며,
    span된 항목이 만든 빈 공간을 채우려면 grid-auto-flow:dense가 필요하거나
    각 항목에 명시적 grid-column/grid-row를 지정해야 함.
  implication: 각 카드에 명시적 좌표 지정이 유일하게 신뢰할 수 있는 해결책

## Resolution

root_cause: |
  CSS grid auto-placement는 span된 항목(card3, grid-row:span 2)이 만드는 빈 공간을
  후속 항목(card4)으로 채우지 않음. auto-placement는 forward-only로 동작하여
  card4를 col1 row3이 아닌 row4에 배치. 결과적으로 연속결석 아래 빈 공간이 그대로 남음.

fix: |
  각 카드에 명시적 grid-column + grid-row 지정:
  - card:nth-child(2): col 1, row 2
  - card:nth-child(3): col 2, row 2/4 (span rows 2-3)
  - card:nth-child(4): col 1, row 3 (연속결석 아래 빈 공간 명시적 채움)
  - card:last-child: col 1/-1, row 4
  consec-large 케이스도 별도 명시적 좌표로 처리.
  768px+ 및 600px landscape 두 미디어쿼리 모두 수정.

verification: |
  commit cbd4b8f (v99) 적용, 사용자 확인 완료 (2026-03-26).
files_changed:
  - viewer.html
