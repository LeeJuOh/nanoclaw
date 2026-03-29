# Express Patterns — Vault Utilization

## Express Types

| Type | Trigger | Description |
|------|---------|-------------|
| **Pull** (명시적) | "vault에서 찾아줘", "~에 대해 알려줘" | 사용자가 vault 검색 의도를 명시할 때 |
| **Ambient** (암묵적) | SessionStart 훅 자동 | 모든 대화에서 에이전트가 자연스럽게 vault 참조 |
| **Push** (능동) | 스케줄 태스크 (Phase 1d) | 에이전트가 능동적으로 관련 노트 추천 |

## Phase 1a: Pull 전략 (grep 기반)

### Vault Search

1. 사용자 질문에서 키워드 추출
2. `grep -ril "keyword" $VAULT/` 로 관련 노트 검색
3. 매칭된 노트 읽기 (최대 5개)
4. 답변 합성 + 출처 명시

### Search Strategies

- Keyword: `grep -ril "keyword" $VAULT/`
- By tag: `grep -rl "tags:.*keyword" $VAULT/`
- By context: `grep -rl "contexts:.*projects/linkdive" $VAULT/`
- By date: `grep -rl "captured: 2026-03" $VAULT/inbox/`
- By related: `grep -rl "related:" $VAULT/ | xargs grep "keyword"`

### 답변 구성

볼트에 관련 노트가 있으면:
> 볼트에서 관련 자료를 찾았어요:
> 1. {title} ({path}) — {match reason}
> 2. {title} ({path}) — {match reason}
>
> 볼트 기반 답변: {answer synthesized from vault notes}

볼트에 관련 노트가 없으면:
> 볼트에 관련 자료가 없어서 일반 지식으로 답변합니다.
> {general knowledge answer}

혼합 시:
> {vault 기반 내용} (볼트: {note title})
> {일반 지식 보완 내용} (일반 지식)

## Phase 1d: Push 전략 (QMD 통합 후)

Phase 1d 시점에 구체화. 현재는 참고용.

- 주간 리뷰에서 최근 캡처 ↔ 기존 노트 연관성 보고
- QMD MCP 서버의 시맨틱 검색 활용
- inbox > 10개 시 자동 알림
