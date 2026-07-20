#!/usr/bin/env bash
# rules/global-orchestration-rule.md 마스터를 글로벌 CLAUDE.md 2곳(WSL·Windows)의
# <fable_orchestration_rule> 마커 블록에 주입한다. 마커가 없으면 파일 끝에 추가.
# 사용법: ./sync-global.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
MASTER="$SCRIPT_DIR/rules/global-orchestration-rule.md"

GLOBALS=(
    "$HOME/.claude/CLAUDE.md"
    "/mnt/c/Users/LG-PC/.claude/CLAUDE.md"
)

for target in "${GLOBALS[@]}"; do
    if [ ! -f "$target" ]; then
        echo "skip (missing): $target"
        continue
    fi
    python3 - "$target" "$MASTER" <<'EOF'
import re, sys
target, master = sys.argv[1], sys.argv[2]
block = open(master, encoding="utf-8").read().strip()
text = open(target, encoding="utf-8").read()
pat = re.compile(r"<fable_orchestration_rule>.*?</fable_orchestration_rule>", re.S)
if pat.search(text):
    new = pat.sub(lambda m: block, text, count=1)
else:
    new = text.rstrip() + "\n\n" + block + "\n"
if new != text:
    open(target, "w", encoding="utf-8").write(new)
    print(f"synced: {target}")
else:
    print(f"up-to-date: {target}")
EOF
done
