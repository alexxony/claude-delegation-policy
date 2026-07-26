#!/usr/bin/env bash
# ORCH_RULE 토글 전환(2026-07-26) 이후: 오케스트레이션 룰 본문은 더 이상
# 글로벌 CLAUDE.md에 정적으로 주입하지 않는다 — SessionStart 훅
# (hooks/orch-rule-injector.py)이 ORCH_RULE 환경변수를 보고 세션마다
# rules/global-orchestration-rule.md 본문을 동적으로 주입한다.
# 이 스크립트는 과거에 주입된 <fable_orchestration_rule> 마커 블록이
# 글로벌 CLAUDE.md 2곳(WSL·Windows)에 남아있으면 제거만 한다(멱등).
# 마스터 텍스트 파일(rules/global-orchestration-rule.md)은 그대로 유지된다 —
# SessionStart 훅이 이 파일을 읽어서 주입하기 때문.
# 사용법: ./sync-global.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

GLOBALS=(
    "$HOME/.claude/CLAUDE.md"
    "/mnt/c/Users/LG-PC/.claude/CLAUDE.md"
)

for target in "${GLOBALS[@]}"; do
    if [ ! -f "$target" ]; then
        echo "skip (missing): $target"
        continue
    fi
    python3 - "$target" <<'EOF'
import re, sys
target = sys.argv[1]
text = open(target, encoding="utf-8").read()
pat = re.compile(r"\n*<fable_orchestration_rule>.*?</fable_orchestration_rule>\n*", re.S)
new = pat.sub("\n", text)
if new != text:
    open(target, "w", encoding="utf-8").write(new)
    print(f"stripped: {target}")
else:
    print(f"up-to-date (no marker block): {target}")
EOF
done
