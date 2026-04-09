#!/bin/bash
# Auto sync: local → GitHub
# 변경사항이 있을 때만 커밋 & 푸시

cd /Users/kimwoojung/report-app

# .claude 디렉토리 제외 설정
if [ ! -f .gitignore ] || ! grep -q ".claude" .gitignore; then
  echo ".claude/" >> .gitignore
fi

# 원격 선행 커밋 먼저 반영
git pull --rebase origin main 2>/dev/null || true

# 변경사항 확인 (.claude 제외)
git add -A -- ':!.claude/'

# 스테이징된 변경사항이 있을 때만 커밋
if ! git diff --cached --quiet; then
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
  git commit -m "auto: $TIMESTAMP"
  if git push origin main 2>/dev/null; then
    echo "[$TIMESTAMP] 동기화 완료"
  else
    echo "[$TIMESTAMP] push 실패 — 다음 주기에 재시도"
  fi
else
  if git push origin main 2>/dev/null; then
    echo "[$(date '+%H:%M')] 변경사항 없음"
  else
    echo "[$(date '+%H:%M')] 변경사항 없음 (push 실패)"
  fi
fi
