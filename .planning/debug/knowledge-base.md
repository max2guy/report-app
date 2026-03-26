# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

---

## monthly-attendance-empty-space — 연속결석 패널 아래 빈 공간 / 월별 평균 출석률 배치 오류
- **Date:** 2026-03-26
- **Error patterns:** 빈 공간, empty space, grid auto-placement, span, 월별평균출석률, consec-large, nth-child, grid-row
- **Root cause:** CSS grid auto-placement는 forward-only로 동작하여 span된 항목(card3, grid-row:span 2)이 만드는 빈 공간을 후속 항목(card4)으로 자동 채우지 않음. 결과적으로 card4가 col1 row3이 아닌 row4에 배치되어 연속결석 패널 아래 빈 공간이 남음.
- **Fix:** 각 카드에 명시적 grid-column + grid-row 좌표 지정 (card2: col1/row2, card3: col2/row2-4, card4: col1/row3, last-child: col1/-1/row4). 768px+ 및 600px landscape 두 미디어쿼리 모두 수정.
- **Files changed:** viewer.html
---
