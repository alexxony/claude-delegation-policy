#!/usr/bin/env python3
"""PreToolUse hook: 위임 원칙 리마인더를 모델 컨텍스트에 직접 주입.

hookify warn(systemMessage)은 사용자 터미널에만 보이므로, 모델(Fable)에게
보이는 additionalContext 채널로 같은 리마인더를 주입한다.
세션당 룰별 5분 스로틀로 토큰 비용을 제한한다.
"""
import json
import os
import re
import sys
import time

THROTTLE_SEC = 300
STATE_DIR = "/tmp/claude-delegation-reminder"

BASH_PATTERN = re.compile(
    r"(python3?\s+\S+\.py|python3?\s+-\s*<|pytest|\bmake\b|gcc|g\+\+|cmake"
    r"|npm\s+(run|install)|pip3?\s+install|3D-ICE|\./[A-Za-z0-9_\-]+\s)"
)
FILE_PATTERN = re.compile(
    r"\.(py|c|cpp|cc|h|hpp|js|ts|tsx|rs|go|sh|json|yaml|yml|toml|ini|stk|flp|tcl)$"
)

MSG_BASH = (
    "⚠️ 위임 원칙 리마인더 (메인 세션 Fable 대상 — 서브에이전트는 무시하고 계속 진행): "
    "실행/빌드/테스트성 명령은 Sonnet 서브에이전트에 위임하는 것이 원칙. "
    "단발 확인용이면 진행해도 되지만, 실행→분석→수정 루프가 예상되면 지금 "
    "oh-my-claudecode:executor 또는 general-purpose(model: sonnet)로 루프 전체를 위임할 것."
)
MSG_FILE = (
    "⚠️ 위임 원칙 리마인더 (메인 세션 Fable 대상 — 서브에이전트는 무시하고 계속 진행): "
    "코드/설정 파일 구현은 Sonnet 서브에이전트 위임이 원칙(트리비얼 한 줄 수정만 직접 허용). "
    "편집이 2회 이상 이어질 작업이면 지금 즉시 oh-my-claudecode:executor 또는 "
    "general-purpose(model: sonnet)로 전환할 것."
)


def throttled(session_id: str, kind: str) -> bool:
    """True면 최근 THROTTLE_SEC 내 이미 주입됨 → 이번엔 침묵."""
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        path = os.path.join(STATE_DIR, f"{session_id}.{kind}")
        now = time.time()
        if os.path.exists(path) and now - os.path.getmtime(path) < THROTTLE_SEC:
            return True
        with open(path, "w") as f:
            f.write(str(now))
        return False
    except OSError:
        return False


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        print("{}")
        return

    tool = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}
    session = data.get("session_id", "unknown")

    message = None
    kind = None
    if tool == "Bash":
        if BASH_PATTERN.search(tool_input.get("command", "")):
            message, kind = MSG_BASH, "bash"
    elif tool in ("Edit", "Write", "MultiEdit"):
        if FILE_PATTERN.search(tool_input.get("file_path", "")):
            message, kind = MSG_FILE, "file"

    if message and not throttled(session, kind):
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": message,
            }
        }, ensure_ascii=False))
    else:
        print("{}")


if __name__ == "__main__":
    main()
