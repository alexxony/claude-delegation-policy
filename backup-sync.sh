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
echo "backup-sync OK $(date '+%F %T')"
