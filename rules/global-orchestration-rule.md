<orchestration_rule>
## 오케스트레이션 룰 — ⚗️ 파일럿(미확정) 2026-09-24~10-01: Sonnet main + Opus advisor

<!-- 마스터: ~/workspace/claude-delegation-policy/rules/global-orchestration-rule.md
     주입: SessionStart 훅 hooks/orch-rule-injector.py (ORCH_RULE=on일 때만).
     개정 절차: 이 마스터 수정 → 커밋. 새 세션부터 반영. -->

**구성**: main = Sonnet(직접 실행) / advisor = Opus(`/advisor opus`, 검토 전용) / 서브에이전트 = 격상·병렬·격리용.
구 체계(Fable main 오케스트레이션 전담, 2026-07-12~)는 파일럿 기간 **보류**(폐기 아님) — main이 서브에이전트와 같은 급이면 "직접 작업 금지"는 비용 이득 없이 조율 턴만 늘림.
- **평가 기준** (파일럿 전후 1주 비교): 모델별 토큰 비중 / 재작업·사고 건수(JOURNAL) / advisor 호출 횟수·누락 사례.
- **롤백**: 구 룰 = policy repo 커밋 6868899의 이 파일 + hookify delegate-file-edits·heavy-bash `enabled: true` + delegation-reminder.py Bash/Edit 분기 복원(git revert 1회).

### main 직접 실행 원칙
- 구현·실행·검증은 main이 직접. 위임은 아래 3가지일 때만:
  1. **병렬화** — 독립 작업 2개 이상 → 서브에이전트 병렬 스폰
  2. **컨텍스트 격리** — 대량 출력 탐색, 10분+ 장기 작업, 원격 빌드 감시 → 서브에이전트(sonnet) / monitor
  3. **모델 격상** — 아래 사다리

### advisor 호출 시점 (고정, 생략 금지)
- **착수 전** 1회 — 방향 설정 직후, 첫 편집·커밋·결론 전
- **완료 선언 전** 1회 — 산출물을 디스크/커밋으로 확정한 뒤
- **같은 작업에서 2회 실패** 시점 — 3번째 직접 시도 금지
- advisor와 이미 확보한 증거가 충돌하면 조용히 전환하지 말고 advisor 1회 더 호출해 조정

### 격상 사다리
1. main(sonnet) 실행
2. advisor(opus) 검토
3. **opus 서브에이전트** — advisor 조언 후에도 막힘, 또는 고난도 구현·디버깅. spawn 프롬프트에 사유 1줄
4. **fable 서브에이전트** — 다음 중 하나일 때만:
   - (a) advisor와 opus 서브에이전트 둘 다 막힘
   - (b) 아키텍처·비가역 결정의 독립 2차 의견 (opus끼리 맹점 공유 회피). 결론 사전 주입 없이 사실·맥락만 전달
- advisor unavailable 시: 동일 목적 opus 서브에이전트로 대체(생략 금지)

**프로젝트별 게이트 예외 — FA/CUTLASS(CuTe DSL) 트랙(2026-09-26)**: FlashAttention_00·
CUTLASS_00은 검증생략 조급증 반복 실측(GPU순환논리 양방향 오판, v1 보안설계
자체검증 누락 — 상세: vault 메모리 `gpu-session-before-code-verification-impulse`).
이 두 프로젝트에 한해 사다리 4단계(fable)를 다음 2개 게이트에서 **advisor
호출과 별개로 필수화**:
  1. **유료 GPU 세션 승인 직전** — 하드웨어 최소사양(디스패치 코드 근거)과
     비용을 fable이 사실관계만 가지고 독립 재확인.
  2. **공개 PR 제출 직전** — 특히 보안/allowlist류 설계는 gadget 거부
     round-trip 테스트 존재 여부를 fable이 확인.
일상적 코드 읽기·STATE 갱신은 기존대로 main(sonnet) 직접 실행 — 이 두
게이트 외 fable 상시 위임 아님(구 체계 부활 아님).

### spawn 표준
- **model 항상 명시** — 기본 `sonnet`, 격상 시 사다리 단계와 사유 기록. 정의 파일 기본값 의존 금지.
- `fork`는 main 상속(sonnet) — 컨텍스트 공유가 필요한 병렬 작업엔 사용 가능.
- 마일스톤·이상 시에만 SendMessage, 조용한 유휴 금지. 백그라운드 착수 시 "pid N으로 X 시작, 다음 보고 Y" 형식.
- 장기 감시(10분+)는 monitor 에이전트(sonnet). main 직접 폴링 금지, ScheduleWakeup은 30분+ 안전망만.
- executor는 대화 보고와 별개로 디스크 상태 파일(`*_status.md`) 갱신.
- 위임 1단계만 — 서브에이전트의 재위임 금지.

### 통신·수명 규약
- **임무당 신규 스폰 + 착수 확인** — 완결 보고한 에이전트에 후속 임무 재하달 금지(완료 편향 씹힘 3회 실측). spawn 프롬프트 필수: ① 착수 1줄 회신 ② 실패 프로토콜(에러→기록→재시도 1회→보고, 무음 정지 금지) ③ 블로커 즉시 보고.
- **회수 시 stand-down 확인 전 대체 스폰 금지** — 미응답 시 디스크 포렌식(mtime·파일 구조)으로 무활동 확인 후 대체.
- **유휴 통지 ≠ 에이전트 사망** — ① 디스크 산출물 ② 외부 프로세스 생존(StartTime 24h 포맷 대조) 확인 후 판정.

### 검증 게이트 요약 (G1~G6, 상세: policy repo docs/verification-gates.md)
- **G1 주장→문서**: 핵심 주장은 1회 독립 재현 후 문서화, 증거(diff/sha256/원시 경로) 동반.
- **G2 통계·판정**: selfcheck에 음성 케이스 필수, 원시 데이터 스팟 대조, 다중 기준은 개별 검증.
- **G3 판정·폐기**: "동일/무효/폐기"는 차이 필드 직접 열람 후. 비가역 결정 전 독립 포렌식 1회.
- **G4 진단**: 예외 삼키는 래퍼는 네이티브 오류 회수 계측 먼저. 과거 성공 이력 있으면 "환경 변화" 가설 우선.
- **G5 위임·통신**: 워커 진실은 보고가 아니라 디스크. 위임 프롬프트에 완료 조건 4항(테스트 숫자·커밋 해시·산출물 경로·최종 보고).
- **G6 기록**: 프로젝트 상태는 `<폴더명>-STATE.md`(≤50줄 덮어쓰기), 이력 정본 = git log, 실패 진단 = 코드 repo JOURNAL.md, 실행 기록 = `ledger/*.jsonl`.

### 참조
- 사고 사례: `~/workspace/claude-delegation-policy/docs/incident-casebook.md`, `verification-gates.md`, `orchestration-cost-model.md`
- 구 체계 이력: vault 메모리 `fable-orchestration-only.md`
</orchestration_rule>
