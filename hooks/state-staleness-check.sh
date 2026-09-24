#!/usr/bin/env bash
# SessionStart: vault 프로젝트 폴더에 STATE보다 새로운 커밋이 있으면 경고 한 줄씩 출력(컨텍스트 주입).
# 비교는 git 커밋 시각 기준 — 9p mtime 불신, 폴더 탐색 없이 index만 사용.
VAULT="${STATE_CHECK_VAULT:-/mnt/c/ObsidianVault}"
case "$PWD" in "$VAULT"*) ;; *) exit 0 ;; esac

now=$(date +%s)
git -C "$VAULT" ls-files -- '*/*-STATE.md' 2>/dev/null | while IFS= read -r f; do
  dir=${f%/*}
  state_ts=$(git -C "$VAULT" log -1 --format=%ct -- "$f" 2>/dev/null)
  dir_ts=$(git -C "$VAULT" log -1 --format=%ct -- "$dir" ":(exclude)$f" 2>/dev/null)
  [ -n "$state_ts" ] && [ -n "$dir_ts" ] || continue
  if [ "$dir_ts" -gt "$state_ts" ]; then
    echo "[STATE 경고] ${f##*/} 갱신 누락 의심 — 폴더 최신 커밋 $(( (now - dir_ts) / 86400 ))일 전, STATE 커밋 $(( (now - state_ts) / 86400 ))일 전. 이 프로젝트 착수 시 STATE부터 갱신."
  fi
done
exit 0
