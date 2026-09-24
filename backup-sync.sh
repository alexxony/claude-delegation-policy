#!/usr/bin/env bash
# WSL 노하우 백업 동기화 (2026-07-17 세팅, 사용자 승인 2026-07-15)
# 1) claude memory → vault _backup (vault git이 이력 커버)
# 2) delegation-policy repo → /mnt/c/backup bare repo (WSL·Windows 물리 분리)
# 수동 실행 또는 세션 마감 루틴에서 호출. GitHub 미사용(백업 전용).
set -e
rsync -a --delete \
  /home/kimsh/.claude/projects/-mnt-c-ObsidianVault/memory/ \
  /mnt/c/ObsidianVault/_backup/claude-memory/
git -C /home/kimsh/workspace/claude-delegation-policy push backup --all --quiet 2>/dev/null || \
  echo "warn: delegation-policy push 실패 (bare repo 확인 필요)"

# 3) claude-smart 학습 DB → /mnt/c/backup/reflexio (git 아님: 32MB 바이너리)
# WAL 모드라 cp 금지 — sqlite3 backup API로 온라인 스냅샷. drvfs 락 회피 위해 로컬 tmp 경유.
REFLEXIO_DB=/home/kimsh/.reflexio/data/reflexio.db
REFLEXIO_DEST=/mnt/c/backup/reflexio
if [ -f "$REFLEXIO_DB" ]; then
  mkdir -p "$REFLEXIO_DEST"
  tmp=$(mktemp --suffix=.db)
  if python3 -c "import sqlite3,sys; s=sqlite3.connect(sys.argv[1]); d=sqlite3.connect(sys.argv[2]); s.backup(d); d.close(); s.close()" "$REFLEXIO_DB" "$tmp" \
     && python3 -c "import sqlite3,sys; r=sqlite3.connect(sys.argv[1]).execute('PRAGMA integrity_check').fetchone()[0]; sys.exit(r!='ok')" "$tmp"; then
    cp "$tmp" "$REFLEXIO_DEST/reflexio-$(date +%F).db"
    cp /home/kimsh/.reflexio/.env "$REFLEXIO_DEST/reflexio.env" 2>/dev/null || true
    ls -1t "$REFLEXIO_DEST"/reflexio-*.db | tail -n +8 | xargs -r rm -f
  else
    echo "warn: reflexio DB 백업 실패 (integrity_check 불통과 또는 backup 오류)"
  fi
  rm -f "$tmp"
fi

echo "backup-sync OK $(date '+%F %T')"
