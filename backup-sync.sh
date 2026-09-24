#!/usr/bin/env bash
# WSL 노하우 백업 동기화 (2026-07-17 세팅, 사용자 승인 2026-07-15)
# 1) claude memory → vault _backup (vault git이 이력 커버)
# 2) delegation-policy repo → /mnt/c/backup bare repo (WSL·Windows 물리 분리)
# 수동 실행 또는 세션 마감 루틴에서 호출. GitHub 미사용(백업 전용).
set -e
# SessionEnd 훅에서 여러 세션이 동시에 끝날 수 있음 — 중복 실행 방지
exec 9>/tmp/backup-sync.lock
flock -n 9 || { echo "backup-sync 이미 실행 중, skip"; exit 0; }

VAULT=/mnt/c/ObsidianVault
rsync -a --delete \
  /home/kimsh/.claude/projects/-mnt-c-ObsidianVault/memory/ \
  "$VAULT/_backup/claude-memory/"
# 미러를 vault git에 기록해야 이력(삭제 복구)이 남음. _backup 경로만 커밋, push는 안 함.
# 다른 세션이 vault git 사용 중(index.lock)이면 건드리지 않고 다음 기회로.
if [ -e "$VAULT/.git/index.lock" ]; then
  echo "warn: vault index.lock 존재 — 미러 커밋 skip"
else
  git -C "$VAULT" add -A -- _backup/claude-memory
  if ! git -C "$VAULT" diff --cached --quiet -- _backup/claude-memory; then
    git -C "$VAULT" commit --quiet -m "메모리 미러 자동 갱신 $(date '+%F %T')" -- _backup/claude-memory \
      || echo "warn: vault 미러 커밋 실패"
  fi
fi
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
