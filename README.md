# claude-delegation-policy

## 목적

Claude Code 세션에서 "Fable(메인 세션)은 오케스트레이션·검증 전담, 구현은 Sonnet 서브에이전트 위임" 원칙을 훅 기반으로 강제하기 위한 자산 모음이다. 특정 프로젝트에 종속되지 않는 독립 저장소로 분리해, 여러 프로젝트(Obsidian vault, Compiler_Thermal, compiler_thermal, hbm_build, gpu_solver_test 등)에서 동일한 정책을 공유한다.

## 구조 — 2중 강제 장치

위임 원칙 위반을 막는 장치는 두 층으로 구성된다.

### 1. hookify warn 룰 (`hookify-rules/`)

- `hookify.delegate-file-edits.local.md` — 코드/설정 확장자(.py, .c, .sh, .json 등)에 대한 Edit/Write/MultiEdit 시 경고. `.md` 노트 등 문서 편집은 대상 아님.
- `hookify.delegate-heavy-bash.local.md` — 실행/빌드/테스트성 Bash 명령(python 스크립트 실행, pytest, make, gcc, pip install 등) 시 경고.

터미널 UI에 표시되어 **사용자가 실시간으로 감시**할 수 있게 하는 용도다.

**주의:** hookify 플러그인은 세션 시작 시점의 cwd 기준 `.claude/` 디렉토리만 읽는다. 고정된 전역 경로를 읽지 않기 때문에, 이 저장소의 룰 파일을 프로젝트마다 직접 배포해야 실제로 작동한다. 배포 방법은 아래 "새 프로젝트 추가" 참조.

### 2. delegation-reminder.py 훅 (`hooks/`)

- PreToolUse 훅으로 동작하며, `hookSpecificOutput.additionalContext`를 통해 **모델의 컨텍스트 윈도우에 직접 리마인더를 주입**한다.
- hookify warn과 달리 이쪽은 모델이 실제로 "보는" 채널이다 (hookify warn의 `systemMessage`는 터미널에만 뜨고 모델 컨텍스트에는 들어가지 않는다).
- `~/.claude/settings.json`에 **글로벌로 등록**되어 있어 모든 프로젝트에서 공통 작동한다.
- 세션당 룰 종류별로 5분 스로틀이 걸려 있어, 같은 세션에서 반복 호출 시 토큰을 낭비하지 않는다.

이 저장소에서는 `hooks/delegation-reminder.py`가 원본이고, `~/.claude/hooks/delegation-reminder.py`는 이 파일로의 심링크다. `settings.json`이 `python3 ~/.claude/hooks/delegation-reminder.py` 경로를 참조하므로 이 경로 자체는 바꾸지 않는다.

## 왜 block이 아니라 warn/리마인더인가

PreToolUse 훅은 메인 세션의 툴콜뿐 아니라 **서브에이전트의 툴콜에도 동일하게 발동**한다. 만약 Edit/Write를 `block`으로 막으면, 위임받은 executor 서브에이전트조차 파일을 편집할 수 없게 되어 위임 패턴 자체가 무너진다.

그래서 두 장치 모두 차단이 아닌 경고/리마인더로 설계했고, 리마인더 메시지에는 "서브에이전트라면 이 경고 무시하고 계속 진행"이 명시되어 있다. 판단은 메인 세션(Fable)의 몫으로 남긴다 — 트리비얼한 한 줄 수정은 직접 허용, 그 이상은 위임으로 전환하라는 신호만 준다.

## 새 프로젝트에 정책 추가하는 방법

1. `targets.txt`에 프로젝트 절대경로를 한 줄 추가.
2. `./sync.sh` 실행 — `targets.txt`의 모든 대상에 `hookify-rules/*.local.md`를 배포한다.
   - 특정 디렉토리만 동기화하려면 `./sync.sh <경로1> <경로2> ...`처럼 인자로 직접 지정.
   - 대상 디렉토리가 없으면 `skip (missing): <경로>`를 출력하고 다음 대상으로 계속 진행한다.
3. `delegation-reminder.py`는 이미 전역 등록되어 있으므로 프로젝트별 추가 작업이 필요 없다.

## settings.json 등록 스니펫 (참고용)

`delegation-reminder.py`는 아래처럼 `~/.claude/settings.json`의 `PreToolUse` 훅에 등록되어 있다 (이미 설정됨, 참고용으로만 기록):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/delegation-reminder.py",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```
