#!/usr/bin/env bash
# ORCH_RULE 토글 전환(2026-07-26) 이후: 오케스트레이션 룰 본문은 더 이상
# 글로벌 CLAUDE.md에 정적으로 주입하지 않는다 — SessionStart 훅
# (hooks/orch-rule-injector.py)이 ORCH_RULE 환경변수를 보고 세션마다
# rules/global-orchestration-rule.md 본문을 동적으로 주입한다.
#
# 이 스크립트는 두 가지를 한다:
#   1. 과거에 주입된 <fable_orchestration_rule> 마커 블록이 글로벌
#      CLAUDE.md 2곳(WSL·Windows)에 남아있으면 제거한다(멱등).
#      마스터 텍스트 파일(rules/global-orchestration-rule.md)은 그대로
#      유지된다 — SessionStart 훅이 이 파일을 읽어서 주입하기 때문.
#   2. hooks/{orch-rule-injector.py,delegation-reminder.py}를 각 대상의
#      .claude/hooks/ 로 배포하고, settings.json의 SessionStart(orch)와
#      PreToolUse(delegation-reminder) 등록을 멱등하게 보장한다.
#      두 대상 모두 symlink로 배포한다. orch-rule-injector.py는 자기
#      위치 기준 상대경로(../rules/global-orchestration-rule.md)로
#      마스터 룰 파일을 찾으므로, 파일 복사로 배포하면 대상 쪽에
#      rules/ 디렉토리가 없어 ORCH_RULE=on이어도 빈 출력만 낸다(실측
#      확인됨). Claude Code가 WSL 프로세스로 python3를 실행하는 한
#      /mnt/c 하위 symlink도 repo 경로로 정상 resolve되므로 Windows도
#      symlink로 통일한다.
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

# --- hook 배포 + settings.json 등록 ---

deploy_hooks_wsl() {
    local claude_dir="$HOME/.claude"
    mkdir -p "$claude_dir/hooks"
    ln -sf "$SCRIPT_DIR/hooks/orch-rule-injector.py" "$claude_dir/hooks/orch-rule-injector.py"
    ln -sf "$SCRIPT_DIR/hooks/delegation-reminder.py" "$claude_dir/hooks/delegation-reminder.py"
    echo "linked (WSL): $claude_dir/hooks/{orch-rule-injector.py,delegation-reminder.py}"
}

deploy_hooks_windows() {
    local claude_dir="/mnt/c/Users/LG-PC/.claude"
    if [ ! -d "$claude_dir" ]; then
        echo "skip (missing dir): $claude_dir"
        return
    fi
    mkdir -p "$claude_dir/hooks"
    ln -sf "$SCRIPT_DIR/hooks/orch-rule-injector.py" "$claude_dir/hooks/orch-rule-injector.py"
    ln -sf "$SCRIPT_DIR/hooks/delegation-reminder.py" "$claude_dir/hooks/delegation-reminder.py"
    echo "linked (Windows): $claude_dir/hooks/{orch-rule-injector.py,delegation-reminder.py}"
}

register_settings() {
    local settings="$1"
    local hooks_dir="$2"
    if [ ! -f "$settings" ]; then
        echo "skip (missing): $settings"
        return
    fi
    python3 - "$settings" "$hooks_dir" <<'EOF'
import json, sys

settings_path, hooks_dir = sys.argv[1], sys.argv[2]
with open(settings_path, encoding="utf-8") as f:
    d = json.load(f)

hooks = d.setdefault("hooks", {})

def has_command(entries, needle):
    return any(
        needle in h.get("command", "")
        for e in entries
        for h in e.get("hooks", [])
    )

session_start = hooks.setdefault("SessionStart", [])
if not has_command(session_start, "orch-rule-injector.py"):
    session_start.append({
        "hooks": [{
            "type": "command",
            "command": f'python3 "{hooks_dir}/orch-rule-injector.py"',
            "timeout": 5,
        }]
    })
    print(f"registered SessionStart(orch-rule-injector): {settings_path}")
else:
    print(f"up-to-date SessionStart(orch-rule-injector): {settings_path}")

pre_tool_use = hooks.setdefault("PreToolUse", [])
if not has_command(pre_tool_use, "delegation-reminder.py"):
    pre_tool_use.append({
        "hooks": [{
            "type": "command",
            "command": f'python3 "{hooks_dir}/delegation-reminder.py"',
            "timeout": 5,
        }]
    })
    print(f"registered PreToolUse(delegation-reminder): {settings_path}")
else:
    print(f"up-to-date PreToolUse(delegation-reminder): {settings_path}")

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=4, ensure_ascii=False)
    f.write("\n")
EOF
}

deploy_hooks_wsl
deploy_hooks_windows
register_settings "$HOME/.claude/settings.json" "$HOME/.claude/hooks"
register_settings "/mnt/c/Users/LG-PC/.claude/settings.json" "/mnt/c/Users/LG-PC/.claude/hooks"
