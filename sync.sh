#!/usr/bin/env bash
# hookify-rules/*.local.md 를 대상 프로젝트들의 .claude/ 디렉토리로 배포한다.
# 사용법: ./sync.sh [대상_디렉토리 ...]
#   인자 없으면 targets.txt의 각 줄을 대상으로 사용한다.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
RULES_DIR="$SCRIPT_DIR/hookify-rules"
TARGETS_FILE="$SCRIPT_DIR/targets.txt"

if [ "$#" -gt 0 ]; then
    targets=("$@")
else
    targets=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        targets+=("$line")
    done < "$TARGETS_FILE"
fi

for target in "${targets[@]}"; do
    if [ ! -d "$target" ]; then
        echo "skip (missing): $target"
        continue
    fi
    mkdir -p "$target/.claude"
    cp "$RULES_DIR"/*.local.md "$target/.claude/"
    echo "synced: $target"
done
