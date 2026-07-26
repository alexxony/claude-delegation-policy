#!/usr/bin/env python3
"""SessionStart hook: 오케스트레이션 룰 본문을 세션 컨텍스트에 동적 주입.

ORCH_RULE 환경변수로 on/off 토글한다 (unset이면 on, 기존 동작 유지):
  - ORCH_RULE=off        -> 아무 것도 출력하지 않음 (룰 비활성)
  - ORCH_RULE=on / unset -> rules/global-orchestration-rule.md 본문을 stdout에 출력

기존 CLAUDE.md 정적 주입(<fable_orchestration_rule> 블록) 방식은 폐기.
모델은 쉘 환경변수를 볼 수 없으므로 조건문 텍스트를 CLAUDE.md에 박아두는 방식은
on/off 무관하게 항상 동일하게 주입돼 "off" arm이 오염된다 — 그래서 SessionStart
훅에서 실행 시점에 프로세스 환경을 읽어 주입 여부 자체를 결정한다
(cbm-session-reminder, caveman-activate.js와 동일한 패턴: SessionStart 훅의
stdout 텍스트가 그대로 세션 additionalContext로 주입됨).
"""
import os
import sys

RULE_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "rules", "global-orchestration-rule.md"
)


def main() -> None:
    if os.environ.get("ORCH_RULE", "on") == "off":
        return

    try:
        with open(RULE_FILE, encoding="utf-8") as f:
            body = f.read().strip()
    except OSError:
        return

    if body:
        sys.stdout.write(body)


if __name__ == "__main__":
    main()
