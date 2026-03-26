#!/bin/bash
# Auto sync: local → GitHub
# 변경사항이 있을 때만 커밋 & 푸시

cd /Users/kimwoojung/report-app

# .claude 디렉토리 제외 설정
if [ ! -f .gitignore ] || ! grep -q ".claude" .gitignore; then
  echo ".claude/" >> .gitignore
fi

# 변경사항 확인 (.claude 제외)
git add -A -- ':!.claude/'

# 스테이징된 변경사항이 있을 때만 커밋
if ! git diff --cached --quiet; then
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
  git commit -m "auto: $TIMESTAMP"
  git pull --rebase origin main 2>/dev/null || true
  git push origin main
  echo "[$TIMESTAMP] 동기화 완료"
else
  # 변경사항 없어도 push 밀린 커밋 있으면 push
  git pull --rebase origin main 2>/dev/null || true
  git push origin main 2>/dev/null || true
  echo "[$(date '+%H:%M')] 변경사항 없음"
fi
