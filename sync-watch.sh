#!/usr/bin/env bash
# rules/global-orchestration-rule.md 변경 감지 -> sync-global.sh 자동 실행.
# inotify는 WSL2 커널 기능이라 WSL 파일시스템(ext4) 안에서만 동작한다.
# 감시 대상은 WSL 쪽 원본이므로 /mnt/c(9p) inotify 제약과 무관.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
WATCH_FILE="$SCRIPT_DIR/rules/global-orchestration-rule.md"
SYNC_SCRIPT="$SCRIPT_DIR/sync-global.sh"
LOG_FILE="$SCRIPT_DIR/sync-watch.log"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

log "watch daemon started (pid $$), watching: $WATCH_FILE"

inotifywait -m -e close_write,move_self,delete_self --format '%e' "$WATCH_FILE" 2>>"$LOG_FILE" |
while read -r event; do
    log "event: $event -> running sync-global.sh"
    if "$SYNC_SCRIPT" >>"$LOG_FILE" 2>&1; then
        log "sync ok"
    else
        log "sync FAILED (exit $?)"
    fi
done
