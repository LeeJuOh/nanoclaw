# Second Brain CODE Redesign — Design Spec

> **Date**: 2026-03-22
> **Status**: Draft — 접근 C 선택, 분류 분리 결정 (2026-03-24), Express 3분할+훅 구조·검수 반영 (2026-03-27)
> **Context**: PRD 검수 + 참조 프로젝트 8개 코드 분석 + NotebookLM(BASB 원전) 검증

---

## 1. PRD 검수 결과

### 1.1 유지할 강점

| 강점 | 근거 |
|------|------|
| Git-backed markdown vault | 참조 프로젝트 중 유일하게 가볍고 이식성 높음 (khoj=PostgreSQL, course=MongoDB, notabase=Supabase) |
| PARA 분류 | arscontexta(Zettelkasten), khoj(분류 없음) 대비 가장 실용적 조직 모델 |
| 메시징 캡처 (텔레그램) | 제로 프릭션. khoj만 비슷한 모바일 접근 제공 |
| 플랫폼별 크롤링 전략 | Twitter/Threads/Medium 분기는 어느 프로젝트에도 없는 실전 노하우 |
| SKILL.md 구조 | obsidian-skills, arscontexta와 동일 포맷. 이미 best practice |
| NanoClaw 메모리 시스템 | SDK 세션 연속성 + Auto-Memory + Per-Group CLAUDE.md + 대화 아카이브 |

### 1.1a PRD-구현 불일치 (정정 필요)

PRD(line 231)에서는 "git add + commit + push (push 실패 시 다음 기회에 재시도)"라고 기술하지만, 실제 구현(SKILL.md line 324, CLAUDE.md)에서는 "commit only, never push — push는 10분 간격 스케줄 태스크가 담당"으로 운영 중. 컨테이너 타임아웃 안전성을 위해 **현재 구현(스케줄러 push)이 정답**이며, PRD를 수정해야 함.

### 1.2 핵심 갭 — CODE 관점

현재 스킬은 CODE의 **C(Capture) 중심**이고 나머지 3단계가 빠지거나 약함:

| CODE 단계 | 현재 상태 | 빠진 것 |
|-----------|----------|---------|
| **Capture** | 구현 완료. 플랫폼 감지, 크롤링, AI 요약 | - |
| **Organize** | PARA 분류가 캡처 스킬 안에 묻혀 있음 | 독립 워크플로우 없음. 주간 리뷰도 캡처에 종속 |
| **Distill** | 캡처 시 1회 deep analysis만 | Progressive Summarization 없음 (Layer 2→3→4 정제 워크플로우 전무) |
| **Express** | vault 검색→답변이 전부 | 능동적 활용 없음. 사용자가 물어봐야만 vault 사용 |

### 1.3 참조 프로젝트 대비 갭

| 갭 | 참조 근거 |
|----|----------|
| 검색이 grep 한정 | khoj: bi-encoder+cross-encoder 2단계, Smart2Brain: BM25+HNSW hybrid, course: MongoDB Atlas hybrid |
| Reflect/Reweave 없음 | arscontexta 6Rs: 새 캡처→기존 노트 역연결. LinkDive는 캡처→분류 일방향 |
| 품질 필터 없음 | course: Quality Scoring Agent (0.0~1.0) — 노이즈 사전 필터링 |
| Match 설명 없음 | Smart2Brain: 왜 이 노트가 검색됐는지 배지 표시 (title/alias/tag/path/heading/content/semantic/recent 8종) |
| 범용 접근 불가 | 현재 텔레그램→NanoClaw 전용. Claude Code 등 외부 도구에서 vault 활용 불가 |

---

## 2. 참조 프로젝트 종합 분석

### 2.1 khoj (33k+ stars) — AI Second Brain

- **아키텍처**: Django + FastAPI + PostgreSQL/pgvector
- **검색**: 2-stage (bi-encoder → cross-encoder reranking), confidence threshold 0.18
- **콘텐츠**: 8개 포맷 (markdown, PDF, 이미지, Notion, GitHub, org-mode, DOCX, plaintext)
- **메모리**: UserMemory 테이블 (7일 슬라이딩 윈도우, 벡터 검색)
- **자동화**: APScheduler + leader election, cron 기반 자동화
- **청킹**: RecursiveCharacterTextSplitter, 256토큰, heading ancestry 보존
- **중복**: hash 기반 dedup (MD5 of raw content), corpus_id로 청크 그룹핑
- **LinkDive 시사점**: 2-stage 검색 패턴, corpus_id 그룹핑, hash dedup 채택 가능. 인프라는 과도하게 무거움

### 2.2 claudian — Obsidian + Claude Code Plugin

- **아키텍처**: Obsidian 플러그인, Claude Agent SDK, MCP, 158개 TS 파일
- **세션**: 포크/리와인드 지원, 탭 기반 멀티 대화
- **에이전트**: Built-in → Plugin → Vault → Global 우선순위 로딩
- **보안**: Permission Mode (YOLO/Safe/Plan), BashPathValidator
- **스토리지**: 분산 저장 패턴 (CC settings + Claudian settings 분리)
- **LinkDive 시사점**: VaultFileAdapter 추상화, MessageChannel 비동기 큐 패턴 참고 가능. 에디터 중심이라 직접 적용은 제한적

### 2.3 obsidian-skills — 선언적 스킬 라이브러리

- **구조**: YAML frontmatter + markdown, 코드 없음 (순수 선언적)
- **스킬**: obsidian-markdown, obsidian-bases, obsidian-cli, json-canvas, defuddle
- **멀티 플랫폼**: Claude Code, Codex CLI, OpenCode 호환
- **LinkDive 시사점**: references/ 서브디렉토리 패턴, 워크플로우 중심 구조. LinkDive 스킬이 이미 이 패턴 따름

### 2.4 second-brain-skills — 콘텐츠 생성 스킬

- **성격**: 지식 조직이 아니라 산출물 생성 (프레젠테이션, SOP, 브랜드 보이스)
- **Progressive disclosure**: 메타데이터 ~100 단어, SKILL.md <5k 단어, 리소스 on-demand
- **MCP 클라이언트**: Zapier, Sequential Thinking, GitHub 통합
- **LinkDive 시사점**: Progressive disclosure 원칙, 인터랙티브 온보딩 패턴 참고. 직접적 세컨드 브레인 전략은 아님

### 2.5 arscontexta — 에이전트 네이티브 세컨드 브레인

- **아키텍처**: 3-space (self/notes/ops), kernel.yaml (15개 불변 원칙)
- **파이프라인**: 6Rs — Record → Reduce → Reflect → Reweave → Verify → Rethink
- **서브에이전트**: /ralph — 큐 기반 태스크, 단계별 fresh context (서브에이전트 스폰으로 컨텍스트 오염 방지)
- **프리셋**: Research (atomicity 0.8), Personal (0.5), Experimental (사용자 정의)
- **훅**: SessionStart (workspace tree 주입), PostToolUse (스키마 검증), Stop (세션 캡처)
- **설정 도출**: 대화에서 8개 차원 추출 (atomicity, organization, linking, processing, session, maintenance, search, automation)
- **LinkDive 시사점**: Reweave(역연결), Verify(스키마 검증), 조건 기반 유지보수 트리거 채택 가치 높음. 전체 도입은 오버엔지니어링

### 2.6 notabase — 웹 노트 앱

- **아키텍처**: Next.js + Supabase, Slate.js WYSIWYG, JSONB 콘텐츠
- **양방향 링크**: linked + unlinked mentions (제목 퍼지 매칭)
- **시각화**: D3 force-directed 그래프 (캔버스 렌더링)
- **검색**: Fuse.js 클라이언트 사이드 퍼지 매칭 (AI 없음)
- **LinkDive 시사점**: 양방향 링크 탐지 (unlinked mentions), force graph 시각화. 현 단계에서는 미적용

### 2.7 obsidian-Smart2Brain — 로컬 RAG 플러그인

- **검색**: MiniSearch(BM25) + HNSW(벡터) hybrid, recent boost (base=2.5, decay=1.25 지수 감쇠)
- **Match 배지**: title/alias/tag/path/heading/content/semantic/recent (8종) — 왜 검색됐는지 설명
- **LLM**: OpenAI, Anthropic, Ollama, OpenRouter 멀티 프로바이더
- **에이전트**: LangGraph ReactAgent, searchNotes/readContent/manageNotes 도구
- **벡터 저장**: IndexedDB(런타임) + MessagePack(디스크) 이중 구조
- **LinkDive 시사점**: hybrid 검색 + match 배지 + recent boost. QMD 통합 시 참고할 최적 모델

### 2.8 second-brain-ai-assistant-course — ML 파이프라인

- **파이프라인**: ZenML 오케스트레이션, MongoDB Atlas 벡터 검색
- **품질 필터**: QualityScoreAgent (gpt-4o-mini, 0.0~1.0 스코어링)
- **RAG**: Parent Retrieval (빠름) vs Contextual/Hybrid (정확) 선택
- **평가**: Opik — Hallucination, AnswerRelevance, Moderation, SummaryDensity
- **크롤링**: Crawl4AI 비동기 (~80% 성공률), 메모리 모니터링
- **LinkDive 시사점**: Quality Scoring 패턴, 비용 투명성, 평가 프레임워크. 인프라(ZenML, MongoDB)는 과도

---

## 3. NotebookLM 검증 — BASB CODE 방법론

### 3.1 CODE 각 단계 핵심 원칙 (BASB 원전)

**Capture**: 평가/판단 없이 직관적으로 빠르게 수집. 속도가 핵심. 분류를 강요하면 마찰 증가.

**Organize**: 정보가 "어느 프로젝트에 쓰일지" 실행 가능성을 고민하며 맥락 부여. Capture와 인지적 목적이 완전히 다르므로 분리가 원칙.

**Distill**: Progressive Summarization 4단계:
- Layer 1 (토양): 원본 전체 수집
- Layer 2 (기름): 중요 문장 볼드
- Layer 3 (금): 핵심 키워드/구절 하이라이트
- Layer 4 (보석): 내 언어로 한 줄 Executive Summary

AI가 Layer 2~4를 자동화하고 사용자는 제목/요약만 다듬는 방식이 효율적.

> **트레이드오프 선언**: BASB 원전의 Progressive Summarization은 시간차를 두고 반복 접근하며 정제하는 것이 핵심. 우리는 이를 **"시간차 정제"가 아닌 "깊이별 자동 추출"로 재해석**한다. 캡처 시점에 AI가 Layer 1~4를 일괄 생성하는 것은 "one-shot summarization"이지 원전의 "progressive"는 아님. 이 트레이드오프를 수용하는 이유: (1) NotebookLM BASB 검증에서 AI 자동화가 효율적이라는 근거, (2) 개인 도구에서 시간차 수동 정제의 현실적 마찰이 높음, (3) 수동 재정제(`para-brain`의 Distill)로 시간차 정제 경로는 열어둠.
>
> **`distill_layer` 활용으로 "자연 선택" 보완**: one-shot 생성의 약점(사용자가 읽지 않은 노트에도 Layer 4 존재)을 `distill_layer: 0`(미확인) 필드로 보완한다. 주간 리뷰에서 "이번 주 캡처 N개 중 미확인 M개" 리포트를 제공하고, 사용자가 분류/열람하면 distill_layer를 갱신. 이를 통해 BASB의 "반복 접근하면서 진짜 쓸모있는 것만 살아남는" 자연 선택 효과를 간접적으로 구현.

**Express**: 중간 작업물(Intermediate Packets)을 재조합해 새로운 결과물 생성. AI가 현재 작업 맥락을 파악해 과거 노트를 **능동적으로 추천(Push)**하는 것은 BASB 철학과 완벽히 일치.

### 3.2 검색 우선순위 — BASB vs 참조 프로젝트

| 관점 | 검색 우선순위 | 논리 |
|------|-------------|------|
| **BASB 원전** | 나중 (V2.0) | 데이터 축적이 먼저. 초기에는 PARA 폴더 탐색(Browse)과 serendipity로 충분 |
| **참조 프로젝트** | 지금 (검색 없이 H3' 불공정) | 에이전트는 폴더를 브라우징할 수 없음. grep이 유일한 접근 |

**해소**: 이 둘은 모순이 아님.
- **사람용 검색**: PARA 폴더 탐색 + 키워드 grep으로 충분 (BASB 말대로 나중)
- **에이전트용 검색**: grep으로 현재도 작동 (vault ~300개까지). Express(능동적 추천) 구현 시점에 QMD 통합

### 3.3 스킬 설계 — BASB 권장

> "백엔드는 통합하되, UX에서는 독립 단계처럼 느끼게 설계"

- Capture + Distill: 자동 통합 (링크 넣으면 AI가 요약까지 백그라운드 처리)
- Organize: 의도적 분리 (AI가 준비한 요약을 보고 사용자가 가볍게 분류)
- Express: 능동적 통합 (작업 시작 시 관련 과거 노트를 레고 블록처럼 제시)

---

## 4. 스킬 설계 — 3가지 접근 방식

### 4.1 접근 A: 단일 스킬, 내부 CODE 분기

현재 `second-brain` 스킬 하나를 유지하되, 메시지 라우팅 테이블에 CODE 단계 분기를 추가.

```
container/skills/second-brain/
  SKILL.md              ← 통합 스킬 (CODE 전체)
  references/
    note-template.md
    para.md
    schema.md
    platform-strategies.md
    distill-layers.md   ← 신규: Progressive Summarization 가이드
    express-patterns.md ← 신규: 능동적 활용 패턴
```

**메시지 라우팅 (확장):**

| 메시지 유형 | CODE 단계 | 동작 |
|------------|----------|------|
| URL / "캡처해" + 텍스트 | Capture + Distill | 크롤링 → 요약 → Layer 4 자동 생성 → inbox 저장 |
| "분류해줘" / "프로젝트 목록" / "아카이브해" | Organize | PARA 분류/관리 |
| "이 노트 다시 정리해줘" / "핵심만 뽑아줘" | Distill | Progressive Summarization 재실행 |
| 일반 질문 / "~에 대해 알려줘" | Express | vault 검색 → 관련 노트 제시 → 답변 합성 |
| "주간 리뷰" | Organize | inbox 정리 + 분류 추천 |
| 주기적 능동 추천 (스케줄) | Express | 최근 캡처 기반 관련 노트 Push |

**Distill 워크플로우 (Capture에 자동 연결):**

1. 캡처 시 AI가 Deep Analysis 수행 (현재와 동일 = Layer 1 + Layer 4)
2. Layer 2 (볼드): 본문에서 핵심 문장을 `**볼드**`로 마킹
3. Layer 3 (하이라이트): 볼드 중 최핵심을 `==하이라이트==`로 마킹
4. Layer 4 (Executive Summary): 노트 상단에 한 줄 요약 (현재 ai_summary 확장)
5. 사용자가 "다시 정리해줘"로 수동 트리거 가능

**Express 워크플로우 (신규):**

1. 사용자가 질문하면 vault grep → 관련 노트 읽기 → 답변 합성 (현재)
2. 능동적 Push (스케줄 태스크): 최근 7일 캡처 분석 → 기존 vault에서 연관 노트 발견 → "이런 연결을 발견했어요" 메시지
3. 프로젝트 시작 지원: "프로젝트 X 시작할 건데" → vault에서 관련 Intermediate Packets 조립

**장점:**
- 구현 간단 (현재 스킬 확장)
- 컨텍스트 공유 자연스러움 (한 세션에서 Capture→Distill→Organize 연쇄)
- NanoClaw 그룹 하나로 관리

**단점:**
- SKILL.md가 비대해짐 (현재 340줄 → 예상 600줄+)
- 각 단계의 독립적 개선/테스트 어려움
- Capture 트리거 키워드에 Distill/Express까지 섞이면 의도 분류 복잡

---

### 4.2 접근 B: CODE 단계별 물리 분리

4개 독립 스킬로 분리. 각 스킬은 자체 트리거, 자체 로직.

```
container/skills/
  para-capture/
    SKILL.md              ← Capture + 자동 Distill(Layer 1-4)
    references/
      note-template.md
      platform-strategies.md
      schema.md
  para-organize/
    SKILL.md              ← Organize + 주간 리뷰
    references/
      para.md
  para-distill/
    SKILL.md              ← 수동 Distill (재정제)
    references/
      distill-layers.md
  para-express/
    SKILL.md              ← Express (검색 + 능동 추천)
    references/
      express-patterns.md
```

**스킬 트리거 분리:**

| 스킬 | 트리거 |
|------|--------|
| `para-capture` | URL 감지, "캡처해", "저장해", "save" |
| `para-organize` | "분류해줘", "프로젝트 만들어", "아카이브해", "주간 리뷰", "미분류 목록" |
| `para-distill` | "정리해줘", "요약 다시", "핵심만", "레이어 올려줘" |
| `para-express` | 일반 질문, "~에 대해", "관련 노트", "프로젝트 시작" |

**스킬 간 상태 공유 방법:**

- 공유 vault 경로: 모든 스킬이 같은 `$VAULT` 마운트 사용
- frontmatter 기반 상태: `status`, `distill_layer`, `contexts` 필드
- `_settings.yaml`: 공유 설정 (auto_classify, auto_distill 등)
- 스킬 간 직접 호출 없음 — vault 파일이 인터페이스

**Capture 스킬 (para-capture):**

```
URL 수신
  → 플랫폼 감지 → 크롤링 → AI 분석
  → Progressive Summarization 자동 실행:
     Layer 1: 원본 본문 저장
     Layer 2: 핵심 문장 볼드
     Layer 3: 최핵심 하이라이트
     Layer 4: Executive Summary 생성
  → frontmatter: distill_layer: 4, status: pending_review
  → inbox/ 저장 + git commit
  → 분류 추천 메시지 (Organize 트리거 유도)
```

**Organize 스킬 (para-organize):**

```
분류 요청 수신
  → inbox/ 스캔 → PARA 의사결정 트리
  → 추천: "resources/ddd (기존)" + 연결 contexts
  → 사용자 승인 → git mv + frontmatter 업데이트
  → Reweave: 관련 기존 노트 검색 → 기존 노트 frontmatter에 related: 추가

주간 리뷰
  → inbox/ 미분류 목록 + 분류 추천
  → 조건 기반 트리거 (inbox > 10개 시 자동 알림)
```

**Distill 스킬 (para-distill):**

```
수동 정제 요청
  → 노트 읽기 → 현재 distill_layer 확인
  → 다음 레이어로 정제:
     Layer 2→3: 볼드 중 최핵심 하이라이트
     Layer 3→4: Executive Summary 갱신
  → frontmatter: distill_layer 업데이트
  → git commit

자동 트리거 (optional):
  → 관련 새 캡처 추가 시 기존 노트 distill_layer 재평가
```

**Express 스킬 (para-express):**

```
질문 수신
  → vault grep/검색 → 관련 노트 읽기
  → Match 설명: "이 노트가 관련된 이유: [tag:ddd, context:projects/linkdive]"
  → 답변 합성 + 출처 명시

능동 추천 (스케줄)
  → 최근 7일 캡처 분석
  → 기존 vault에서 연관 노트 발견
  → "이번 주 캡처와 연결되는 기존 노트를 발견했어요" Push

프로젝트 시작 지원
  → "프로젝트 X 관련 자료 모아줘"
  → vault 전체 검색 → Intermediate Packets 조립
  → 요약 + 출처 목록 제공
```

**장점:**
- 각 스킬이 작고 명확 (~150줄)
- 독립적 개선/테스트/eval 가능
- 트리거 키워드 충돌 최소
- 새 단계 추가 용이 (para-reflect 등)

**단점:**
- NanoClaw 그룹 설정에서 4개 스킬 모두 로드 필요
- 스킬 간 상태 공유가 vault 파일 의존 (실시간 공유 불가)
- Capture→Distill 자동 연쇄가 "두 스킬 순차 실행"이 아니라 Capture 내부에서 Distill 로직 포함 → Distill 스킬과 중복. **해소 패턴**: Capture는 "초기 Distill"(Layer 1~4 일괄 생성)을 수행하고, para-distill은 "재정제"(기존 노트의 Layer 재실행/수동 조정)만 담당. 공유 레퍼런스 `distill-layers.md`를 두 스킬이 참조하되, 트리거와 목적이 다르므로 중복이 아닌 분업
- 사용자가 4개 스킬의 존재를 인식해야 함 (인지 부하)
- NanoClaw는 `container/skills/`의 모든 스킬을 모든 그룹에 동기화함. para-* 4개 스킬이 second-brain 외 그룹에도 로드됨 (기능상 문제 없으나 불필요한 컨텍스트 증가)

---

### 4.3 접근 C: 2분할 (자동 파이프라인 / 사용자 인터랙션)

NotebookLM이 제안한 패턴을 반영. **자동으로 돌아가는 것**과 **사용자가 개입하는 것**으로 분리.

```
container/skills/
  para-pipeline/
    SKILL.md              ← Capture + Distill (자동 파이프라인)
    scripts/
      vault-context.sh    ← SessionStart 훅: vault 인지 컨텍스트 주입
    references/
      note-template.md
      platform-strategies.md
      schema.md
      distill-layers.md
  para-brain/
    SKILL.md              ← Organize + Express Pull (사용자 인터랙션)
    references/
      para.md
      express-patterns.md
```

**분리 원칙:** "사용자 개입 필요 여부" + Express 3분할

| | para-pipeline (자동) | para-brain (인터랙션) | SessionStart 훅 (ambient) |
|--|---------------------|----------------------|---------------------------|
| **트리거** | URL 감지, "캡처해" | "분류해줘", "주간 리뷰", "vault 검색", "정리해줘" 등 명시적 키워드 | 매 세션 시작 시 자동 |
| **성격** | 빠르게 처리하고 결과만 보고 | 대화형, 사용자 판단 필요 | 에이전트 기본 행동에 vault 인지 주입 |
| **CODE** | Capture + Distill | Organize + Express Pull | Express Ambient |
| **사용자 개입** | 없음 (결과 알림만) | 분류 승인, 질문 답변 | 없음 (에이전트가 알아서 vault 참조) |

**Express 3분할:**

| Express 유형 | 처리 위치 | 설명 |
|---|---|---|
| **Pull** (명시적 질문) | para-brain | 사용자가 "vault에서 찾아줘", "~에 대해 알려줘" 등 vault 검색 의도가 명확할 때 |
| **Ambient** (암묵적 활용) | SessionStart 훅 (`vault-context.sh`) | 모든 대화에서 에이전트가 자연스럽게 vault grep. 스킬 트리거 불필요 |
| **Push** (능동 추천) | 스케줄 태스크 → para-brain | task-scheduler가 프롬프트 전달 → 에이전트가 para-brain 사용 |

`vault-context.sh`는 para-pipeline 스킬 폴더 안에 포함되어 플러그인 배포 시 함께 동기화됨. NanoClaw, 독립 Claude Code 플러그인 양쪽에서 작동.

**para-pipeline (자동):**

```
URL/메모 수신
  → 플랫폼 감지 → 크롤링 → AI 분석
  → Progressive Summarization (Layer 1~4 자동)
  → Vault Connection 탐색 (기존 노트와 연결점)
  → inbox/ 저장 + git commit (파일은 항상 inbox에 유지)
  → 분류 추천 포함한 결과 메시지 전송 (추천만, 이동 없음)
     "*캡처 완료: {title}*
      *핵심*: {Layer 4 요약}
      *연결*: {관련 기존 노트 2-3개}
      배치 추천: resources/ddd (기존)
      (답장으로 분류하거나 나중에 일괄 분류)"
```

사용자 입장: URL 보내면 → 잠시 후 완성된 노트 + 분류 추천이 옴. **파일은 항상 inbox에 저장**되고, 실제 분류(이동)는 para-brain이 담당. BASB 원칙: "Capture에서 분류를 강요하면 마찰 증가".

**para-brain (인터랙션):**

```
수동 분류 (기본)
  → 캡처 추천에 답장 → 단건 분류
  → "분류해줘" → inbox 전체 배치 분류 + 추천
  → 사용자 승인/변경 → git mv + frontmatter 업데이트
  → Reweave: 관련 기존 노트에 역연결 추가

자동분류 (별도 기능, 기본 꺼짐)
  → _settings.yaml에서 auto_classify.enabled: true 설정 시 활성화
  → trigger: on_capture | scheduled | manual_only
  → 높은 확신도만 자동 이동, 낮은 확신도는 inbox 유지 + 추천

PARA 관리
  → 프로젝트/영역/리소스 생성, 아카이브, 목록

Express Pull — 명시적 vault 검색 (Phase 1b+)
  → "vault에서 DDD 관련 노트 찾아줘" → vault 검색 → Match 설명 + 답변 합성
  → 볼트에 없으면: "볼트에 관련 자료가 없습니다" 명시 후 일반 지식으로 답변
  → 볼트 결과 + 일반 지식을 명확히 구분해서 제시
  → ※ 일반 질문("DDD aggregate가 뭐야?")은 SessionStart 훅(Express Ambient)이 처리

주간 리뷰 + 능동 추천 (스케줄)
  → 주간 리뷰: inbox 현황 보고 + 분류 추천 (이동 없음)
    + distill_layer: 0 노트 현황 ("이번 주 캡처 12개 중 미확인 9개")
  → 연결 발견: "이번 주 캡처와 관련된 기존 노트" (Phase 1d, Express Push)
  → 조건 트리거: inbox > 10개 시 자동 알림

수동 Distill
  → "이 노트 다시 정리해줘" → Layer 재실행

프로젝트 지원
  → "프로젝트 X 시작" → 관련 Intermediate Packets 조립
```

**SessionStart 훅 (`vault-context.sh`):**

```bash
#!/bin/bash
# para-pipeline/scripts/vault-context.sh
# SessionStart 훅으로 등록 — 매 세션 시작 시 실행
VAULT="${VAULT:-/workspace/extra/vault}"
if [ -d "$VAULT" ]; then
  cat <<'CONTEXT'
[Vault Awareness] 이 그룹에 지식 저장소(vault)가 있습니다.
경로: $VAULT
질문에 답할 때 `grep -ril "키워드" $VAULT/`로 관련 노트를 먼저 찾아보세요.
관련 노트가 있으면 인용해서 답변하고, 없으면 일반 지식으로 답변하세요.
vault 결과와 일반 지식을 명확히 구분해서 제시하세요.
CONTEXT
fi
```

이 훅은 스킬 트리거 없이 모든 대화에서 에이전트가 vault를 자연스럽게 참조하게 만듦. Express의 "ambient" 부분을 담당.

**분류 분리 원칙:** 캡처(para-pipeline)는 절대 파일을 inbox 밖으로 이동하지 않음. 분류(para-brain)만이 파일을 이동할 수 있음. 자동분류도 para-brain의 독립 기능으로, 캡처 파이프라인에 결합되지 않음. BASB: "Capture와 Organize는 인지적 목적이 다르므로 분리가 원칙".

**장점:**
- BASB 권장 패턴 반영 (Capture+Distill 자동, Organize 의도적 분리)
- 스킬 2개 + 훅 1개로 관리 단순하면서도 Express 커버리지 완전
- 자동/인터랙션 경계가 명확 → 사용자 인지 부하 낮음
- para-pipeline은 비간섭 처리에 집중, para-brain은 분류 전문가로 집중
- Express Ambient(훅)가 모든 대화에 vault 인지를 주입 → 스킬 트리거 없이도 vault 활용
- 훅 스크립트가 스킬 폴더 안에 포함되어 플러그인 배포 시 함께 동기화 (NanoClaw + 독립 Claude Code 양쪽 호환)

**단점:**
- para-pipeline에 Capture+Distill이 합쳐져 스킬이 다소 큼
- Distill 수동 트리거가 para-brain에 있어서 Distill 로직이 양쪽에 분산. **해소**: para-pipeline은 "자동 Distill"(캡처 시 Layer 1~4), para-brain은 "수동 재정제"(사용자 요청 시). 공유 레퍼런스 `distill-layers.md`로 일관성 유지
- 접근 B보다 각 단계의 독립 테스트가 어려움
- SessionStart 훅의 컨텍스트 주입이 vault 없는 그룹에서도 실행됨. **해소**: `vault-context.sh`가 vault 경로 존재 여부를 체크하고, 없으면 아무것도 출력하지 않음

---

### 4.4 결정: 접근 C + Phase별 para-brain 확장

**접근 C를 선택한다.** 단, para-brain의 범위를 Phase별로 제한.

**왜 A/B가 아닌가:**

- **A (단일 스킬)**: 현재 340줄이 Capture만으로 이미 이 크기. O+D+E를 넣으면 600줄+. 컨테이너 에이전트의 스킬 컨텍스트가 비대해지면 각 단계의 수행 품질이 저하됨. "URL이 왔을 때"와 "질문이 왔을 때"는 인지적으로 완전히 다른 모드인데 하나의 스킬에 우겨넣으면 트리거 분별이 흐려짐.
- **B (4분할)**: 개인 도구에 스킬 4개는 과잉. `container/skills/` 전 그룹 로드 문제도 있고, `para-distill`은 독립 스킬로 존재할 만큼 호출 빈도가 높지 않음. 분리의 이론적 장점(독립 테스트)이 실전 비용(4개 eval, 4개 트리거 관리)을 정당화하지 못함.

**왜 C인가:**

"자동으로 흘러가는 것"과 "사용자가 개입하는 것"은 본질적으로 다른 모드. 이것이 가장 자연스러운 분리축:

- `para-pipeline`: URL 오면 조용히 처리하고 결과만 보고 → 속도, 비간섭
- `para-brain`: 사용자가 말 걸면 대화 → 품질, 맥락 이해

**Phase별 확장:**

| Phase | para-pipeline | para-brain | SessionStart 훅 | 전환 기준 |
|-------|--------------|------------|-----------------|----------|
| **1a (현재)** | Capture + auto Distill (항상 inbox 저장, 추천만) | Organize (수동 분류 + 주간 리뷰 + Reweave) + Auto-Classification (별도 기능) ~150줄 | vault-context.sh (Express Ambient) | — |
| **1b** | 동일 | + Express Pull (명시적 vault 검색 + match 설명) | 동일 | para-pipeline eval 90%+, para-brain Organize eval 85%+, inbox 운영 2주+ |
| **1d** | 동일 | + Express Push (QMD 통합 후 능동 추천) | 동일 | vault 300개 도달 or Express Pull 검색 품질 불만 or Express Push 구현 시작 |

> **Phase 1c 부재 설명**: Phase 1c는 오픈소스 컨트리뷰션 PR (linkdive_research.md §실행 계획 참조)로, 스킬 아키텍처와 독립적이므로 이 스펙 범위 밖.

이렇게 하면:
- Phase 1a에서 para-brain은 ~150줄로 시작 가능 (Organize + Reweave만)
- Express Ambient는 훅이 담당하므로 para-brain이 스킬 트리거 없는 일반 질문까지 처리할 필요 없음
- Express Push의 feasibility 문제를 Phase 1d로 미루면서도 구조는 확보
- 기존 second-brain eval의 Capture 케이스는 para-pipeline으로 거의 그대로 이관

**예상 최종 크기** (Phase 1d 기준):
- para-pipeline: ~350줄 (현재 second-brain Capture + Distill 자동화 추가)
- para-brain: ~250줄 (Organize ~150줄 + Express Pull ~60줄 + Express Push ~40줄) — Express Ambient가 훅으로 빠져서 기존 예상(~300줄)보다 축소
- vault-context.sh: ~15줄 (SessionStart 훅)
- 합계 ~600줄이지만, 스킬 분리 + 훅으로 에이전트는 한 세션에 필요한 컨텍스트만 소비

### 4.5 NanoClaw 스킬 메커니즘 — 설계 근거

접근 C가 NanoClaw 아키텍처에서 작동하는 방식:

1. **스킬 자동 로드**: `container-runner.ts:149-159`에서 매 컨테이너 세션마다 `container/skills/`의 모든 스킬을 `~/.claude/skills/`로 sync. Claude Code SDK가 자동 발견.
2. **에이전트 기반 선택**: NanoClaw는 스킬을 pre-select하지 않음. 모든 스킬이 로드된 상태에서 에이전트가 프롬프트/컨텍스트 기반으로 어떤 스킬을 사용할지 결정.
3. **한 세션 복수 스킬**: 에이전트는 한 세션에서 여러 스킬을 자유롭게 사용 가능.
4. **스케줄 태스크**: `task-scheduler.ts`에서 due task의 `prompt` 필드를 컨테이너에 전달 → 에이전트가 프롬프트를 보고 적절한 스킬 사용.

따라서 `para-pipeline`과 `para-brain` 2개 스킬이 같은 그룹에 로드되어도, 에이전트가 메시지 유형에 따라 자연스럽게 올바른 스킬을 선택함. 스킬 간 명시적 호출 메커니즘은 불필요 — vault 파일이 인터페이스.

**제약 및 대응**: `container/skills/`의 모든 스킬은 모든 그룹에 로드됨. para-* 2개가 second-brain 외 그룹에도 로드되어 두 가지 문제 발생:

1. **오발동 위험**: 다른 그룹에서 URL을 보내면 para-pipeline이 트리거될 수 있음
2. **불필요한 컨텍스트 증가**: 에이전트의 스킬 목록이 길어짐

**대응 방안**: 스킬 description에 vault 경로 존재 여부 확인 가드를 포함. para-pipeline/para-brain 모두 `$VAULT` 경로가 마운트되지 않은 그룹에서는 스킬 사용을 건너뜀. 예: "Only use this skill when the vault path ($VAULT or /workspace/extra/vault) exists."

---

## 5. 검색 전략 — 단계적 강화

### Phase 1a (현재): grep 기반

```bash
grep -ril "keyword" $VAULT/
```

- vault ~300개까지 충분
- 에이전트가 vault를 활용하기엔 최소한 작동
- H3' 초기 검증에는 사용 가능

### Phase 1d (Express 본격화 시): QMD 통합

```
QMD persistent HTTP 서버
  → BM25 (전문 검색) + sqlite-vec (벡터 검색) + LLM 리랭킹
  → MCP 서버 모드로 노출
  → Claude Code, 다른 에이전트도 접근 가능
```

QMD 도입 시점 판단 기준 (**어느 하나라도 해당되면 도입 검토**):
- vault 노트 수 300개 초과 → grep 성능/정확도 한계
- Phase 1d Express Push 구현 시작 → grep만으로 연관 분석 품질 부족
- 사용자가 검색 품질에 불만 표시

**Express와 QMD의 관계**: Phase 1b Express Pull은 grep으로 시작. grep 기반 검색 품질이 충분하면 QMD 없이도 Express Pull 운영 가능. Phase 1d Express Push는 vault 전체 연관 분석이 필요하므로 QMD 전제로 설계. 즉, Express Pull → grep OK, Express Push → QMD 필요.

**참고 프로젝트 검색 비교** (§2 외 추가):
- `references/memsearch`: BM25+벡터 하이브리드. QMD와 동일 방향이지만 Python 기반이고 MCP 서버 모드 미지원. QMD가 NanoClaw(Node.js) 스택과 더 호환되므로 QMD 선택.
- `references/PageIndex`: 벡터 없이 추론 기반 검색 (Vectorless RAG). 임베딩 인프라 없이 LLM 추론만으로 검색하는 대안적 접근. vault 300개 이하에서는 grep으로 충분하고, 300개 초과 시 QMD의 hybrid 검색이 정확도/성능 균형이 나으므로 현 단계에서는 미채택. Phase 2+ 고급 검색에서 재검토 가능.

### Phase 2+: 고급 검색

- Match 배지 (Smart2Brain 패턴): 왜 이 노트가 검색됐는지 설명
- Recent boost: 최근 캡처/접근 노트 가중치
- Cross-reference: Reweave로 추가된 연결 활용

---

## 6. Express 능동적 활용 — 구현 전략

### 6.1 Push 추천 (스케줄 기반)

| 트리거 | 동작 |
|--------|------|
| 주간 리뷰 (일요일 09:00) | inbox 미분류 목록 + 분류 추천 + 이번 주 캡처 수 |
| 연결 발견 (매일 or 캡처 5개마다) | 최근 캡처 ↔ 기존 노트 연관성 분석 → "이런 연결을 발견했어요" |
| inbox 임계값 (inbox > 10) | "inbox에 미분류 노트가 {N}개 쌓였어요" |

**Express Push 알고리즘 방향 (Phase 1d 시점에 구체화):**

QMD의 `query` MCP 도구를 활용한 연관 분석 스케치:
1. 최근 7일 캡처 노트의 `tags` + `ai_summary`를 수집
2. 각 캡처에 대해 `mcp__qmd__query(type: "vec", query: ai_summary)` 실행 → 시맨틱 유사 기존 노트 검색
3. QMD의 BM25 probe strong signal 패턴 활용 (topScore ≥ 0.85 AND gap ≥ 0.15이면 확신도 높은 연결)
4. 연결 threshold: RRF blended score 상위 3개만 추천 (노이즈 방지)
5. 이미 `related:` 에 있는 연결은 제외 (중복 추천 방지)

이 방향은 QMD 코드(`store.ts:3585-3598`)의 strong signal 감지 패턴에 기반하며, 구체적 threshold와 결과 포맷은 Phase 1d 설계 시 확정.

### 6.2 Pull 강화 (질문 시)

```
사용자: "DDD에서 aggregate 설계 어떻게 해?"
  → vault 검색 → 관련 노트 3개 발견
  → "볼트에서 관련 자료를 찾았어요:
     1. aggregate-design-patterns.md (resources/ddd) — tag:aggregate, semantic match
     2. app-redesign-sprint2.md (projects/app-redesign) — context:projects/app-redesign
     볼트 기반 답변: ..."
```

### 6.3 프로젝트 시작 지원

```
사용자: "앱 리디자인 프로젝트 시작할 건데 관련 자료 모아줘"
  → vault 전체 검색: contexts에 projects/app-redesign 포함 + 태그 겹침
  → Intermediate Packets 조립:
     "관련 노트 7개 발견:
      - UX 리서치 방법론 가이드 (resources/research-methods)
      - React 컴포넌트 패턴 (resources/react)
      - 스프린트 1 회고 (projects/app-redesign)
      ..."
```

### 6.4 Claude Code 등 외부 접근

QMD를 MCP 서버로 운영하면:
- Claude Code에서 `mcp__qmd__search` 도구로 vault 검색
- 개발 중 "이 패턴에 대해 내 vault에 뭐가 있지?" 질의 가능
- NanoClaw 의존 없이 vault 활용

---

## 7. 공통 요소 — 접근 방식 무관

어떤 접근이든 아래는 공통 구현:

### 7.1 Progressive Summarization 자동화

캡처 시 AI가 Layer 1~4를 한 번에 생성:

```markdown
---
title: "Aggregate Design in DDD"
ai_distill_depth: 4
distill_layer: 0
ai_summary: "Aggregate는 트랜잭션 경계를 정의하는 클러스터로, DDD에서 일관성 경계와 동시성 제어의 핵심 단위. 작게 잡을수록 동시성 충돌이 줄어든다는 실증 데이터 기반 설계 원칙을 제시."
---

> **Executive Summary**: Aggregate는 트랜잭션 경계를 정의하는 클러스터...

## Core Claims

- **Aggregate는 일관성 경계다** — 하나의 트랜잭션에서...
- DDD에서 가장 흔한 실수는 ==Aggregate를 너무 크게 잡는 것==

## Key Arguments

- 작은 Aggregate가 **동시성 충돌을 줄인다**는 실증 데이터...
```

볼드(`**`)가 Layer 2, `==하이라이트==`가 Layer 3, 상단 Executive Summary가 Layer 4. `ai_distill_depth: 4`는 AI가 4단계까지 생성했음을 표시하고, `distill_layer: 0`은 사용자가 아직 확인하지 않았음을 의미.

**Layer 3 마커 선택지:**
- `==highlight==`: Obsidian에서만 렌더링됨. GitHub, iOS 앱에서는 무시됨
- `<mark>highlight</mark>`: GitHub에서 렌더링되지만 Obsidian에서는 플러그인 필요
- frontmatter `highlights: []` 배열: 렌더링 무관하게 데이터로 보존

**결정**: Phase 1a에서는 `==highlight==` 사용. 주 소비자는 에이전트(grep/읽기에 마커 포맷 무관)와 Obsidian(렌더링 지원)이며, 에이전트는 어떤 포맷이든 파싱 가능하므로 사람이 직접 읽을 때의 렌더링 품질로 결정. Phase 1b(iOS 앱) 시점에 재검토. AI가 마킹하므로 나중에 포맷 일괄 변환 가능.

### 7.2 Reweave (역연결)

캡처/분류 시 관련 기존 노트 검색 → 역연결 추가.

**Phase 1a 품질 기준 (보수적)**: grep 기반에서는 연결 노이즈가 발생하기 쉬우므로 보수적으로 운영:
- **threshold**: 같은 PARA 경로 + 태그 2개 이상 겹침일 때만 `related:` 추가
- 같은 PARA 경로만 공유하고 태그 겹침이 1개 이하이면 역연결하지 않음 (예: `resources/ddd/` 안의 모든 노트가 기계적으로 연결되는 것 방지)
- Phase 1d(QMD 도입) 이후 시맨틱 유사도 score 기반으로 threshold 전환 가능

**Write-path 충돌 해소**: PRD의 write-path 모델에서 `classified` 노트는 사용자만 수정 가능. Reweave가 기존 노트를 직접 수정하면 규칙 위반. 따라서 `related:` 추가는 **write-path 예외로 명시**: frontmatter의 `related:` 필드만 에이전트가 추가 가능, 나머지 필드와 본문은 기존 규칙 유지.

```yaml
# 기존 노트 (related: 필드만 에이전트 수정 허용)
---
title: "DDD Bounded Context 정의"
related:
  - path: "resources/ddd/20260322-aggregate-design.md"
    reason: "동일 도메인, 태그 겹침: aggregate, ddd"
    added: 2026-03-22
---
```

### 7.3 frontmatter 확장

```yaml
---
title: "Note title"
source: "https://..."
source_type: web           # web | memo | youtube | twitter | threads | github | reddit | medium
captured: 2026-03-22T14:30:00+09:00
processed: 2026-03-22T14:30:05+09:00
status: pending_review     # raw | pending_review | classified | auto_classified
ai_distill_depth: 4        # AI가 생성한 최고 레이어 (캡처 시 항상 4)
distill_layer: 0           # 사용자가 확인/승인한 최고 레이어 (0=미확인, 1~4)
contexts:
  - resources/ddd
  - projects/linkdive
tags: [ddd, aggregate, architecture]
ai_summary: "2-3 문장 요약 + 한 줄 핵심 (Executive Summary 겸용)"
ai_suggested_category: "resources/ddd"
related:                   # Reweave로 추가된 역연결
  - path: "resources/ddd/bounded-context.md"
    reason: "동일 도메인"
---
```

**distill_layer 설계 결정**:
- `ai_distill_depth`: AI가 캡처 시 생성한 최고 레이어. 현재는 항상 4 (Layer 1~4 일괄 생성). **존재 이유**: 향후 부분 Distill 지원 시 필요 — 예: 크롤링 실패로 본문이 짧아 Layer 2까지만 생성한 경우, 메모 캡처(source_type: memo)에서 Layer 축소 적용 시, 또는 LLM 비용 절감을 위해 캡처 시 Layer 2까지만 자동 생성하고 Layer 3~4는 수동 트리거로 전환하는 정책 변경 시. 이 시나리오가 발생하기 전까지는 항상 4이며, 필터/정렬 기준으로 사용하지 않음.
- `distill_layer`: **사용자가 확인/승인한 최고 레이어**. 캡처 직후 0 (미확인). 사용자가 노트를 열어보고 분류하면 1~2, 수동 재정제하면 3~4. 이 필드가 필터/정렬 기준이 됨 (예: "아직 안 본 노트" = `distill_layer: 0`).

**ai_summary 통합**: 기존 schema의 `ai_summary` 하나로 통합. Executive Summary(한 줄)와 상세 요약(2-3문장)을 별도 필드로 나누지 않음 — 본문 상단의 `> **Executive Summary**: ...` 블록이 한 줄 핵심을 담당하고, frontmatter `ai_summary`는 2-3문장 요약.

### 7.4 _settings.yaml 스키마

```yaml
# $VAULT/_settings.yaml
auto_classify:
  enabled: false          # 기본 꺼짐. 캡처는 항상 inbox + 추천만
  trigger: on_capture     # on_capture | scheduled | manual_only
  schedule: "sunday 09:00" # trigger: scheduled일 때만 사용
```

**분류 분리 원칙 (2026-03-24 결정):**

기존 구현은 `auto_classify: boolean`으로 캡처 파이프라인 step 10에서 분류를 실행했음. 이는 BASB CODE 원칙("Capture와 Organize는 인지적 목적이 다르므로 분리")에 위배.

변경:
- **캡처(para-pipeline)**: 항상 inbox 저장 + 추천 메시지만 전송. `auto_classify` 설정을 읽지 않음
- **분류(para-brain)**: 독립 워크플로우. 수동 분류가 기본. 자동분류는 `auto_classify.enabled: true`로 별도 활성화
- **자동분류 트리거**: 캡처에 결합되지 않고, `trigger` 설정에 따라 독립 실행
  - `manual_only`: "자동분류 실행해" 명령 시에만
  - `on_capture`: 캡처 완료 후 **별도 단계로** (para-brain이 처리)
  - `scheduled`: 설정된 시간에 inbox 일괄 처리

**하위 호환**: 마이그레이션 시 `_settings.yaml`을 새 스키마로 직접 변환 (§9.1 참조). 프롬프트 레벨 해석에 의존하지 않음.

---

## 8. 비교 요약

| 기준 | A: 단일 스킬 | B: CODE 4분할 | C: 2분할 + 훅 |
|------|-------------|-------------|---------|
| 스킬 수 | 1 | 4 | 2 + SessionStart 훅 1개 |
| SKILL.md 크기 | ~600줄 | ~150줄씩 | ~350줄 + ~250줄 |
| Express Ambient | 스킬 내부 | para-express 스킬 | SessionStart 훅 (스킬 트리거 불필요) |
| 컨텍스트 공유 | 자연스러움 | vault 파일 의존 | 중간 |
| 독립 테스트 | 어려움 | 쉬움 | 중간 |
| 사용자 인지 부하 | 낮음 (1개) | 높음 (4개 인식) | 낮음 (자동/대화 구분) |
| BASB 원칙 부합 | 중간 | 높음 (단계 명확) | 높음 (자동+의도적 분리) |
| 구현 난이도 | 낮음 | 높음 | 중간 |
| 확장성 | 비대해짐 | 좋음 | 좋음 |
| 플러그인 배포 | OK | OK | OK (훅 스크립트 스킬 폴더 내 포함) |
| NanoClaw 호환 | 그룹 1개 | 그룹 1개, 스킬 4개 (전 그룹 로드) | 그룹 1개, 스킬 2개 (전 그룹 로드) |
| Express Push (Phase 1a) | grep 기반 제한적 | grep 기반 제한적 | grep 기반 제한적 |
| Express Push (Phase 1d+) | QMD hybrid | QMD hybrid | QMD hybrid |

---

## 9. 마이그레이션 전략

현재 `second-brain` 스킬(340줄, 96% pass rate)에서 접근 C로의 전환:

### 9.1 전환 계획

| 항목 | 내용 |
|------|------|
| **변경 범위** | `container/skills/second-brain/` 삭제 → `para-pipeline/` + `para-brain/` 2개 신규 |
| **기존 테스트** | Capture 테스트(8개) → para-pipeline으로 이관. Organize 테스트(3개) → para-brain으로 이관. 크롤 진단(1개) → para-pipeline. 상세 매핑은 §10.1 참조 |
| **전환 방식** | Atomic swap (기존 삭제 + 신규 생성 동시) |
| **그룹 CLAUDE.md** | 스킬 참조 업데이트 (second-brain → para-pipeline, para-brain) |
| **`_settings.yaml` 마이그레이션** | `auto_classify: false` (boolean) → `auto_classify: { enabled: false, trigger: on_capture }` (object)로 변환. 한 줄 변경이므로 전환 시 즉시 수행. 프롬프트 레벨 하위 호환 해석에 의존하지 않음 |
| **vault 호환** | 100%. 기존 노트 그대로 유지. 새 frontmatter 필드(`ai_distill_depth`, `distill_layer`)는 기존 노트에 없어도 무방 (기본값 처리) |
| **inbox 기존 노트** | 현재 inbox에 다수(~47개) 미분류 노트 존재. 전환 직후 "inbox > 10개 알림"이 즉시 발동하므로, 마이그레이션 시 일괄 분류를 먼저 수행하거나 초기 threshold를 임시 상향(예: 30개) |

### 9.2 기존 노트 하위 호환

- `ai_distill_depth` 없는 기존 노트: AI가 Distill을 수행하지 않았다고 간주
- `distill_layer` 없는 기존 노트: 0 (미확인)으로 간주
- 기존 `ai_summary` 필드: 그대로 유지 (포맷 호환)
- 일괄 마이그레이션 불필요 — 새 캡처부터 새 스키마 적용, 기존 노트는 접근 시 점진적으로 업데이트

## 10. Eval 전략

### 10.1 기존 eval → 새 스킬 매핑

현재 `second-brain` eval 12개 → `para-pipeline` / `para-brain` 이관:

| 기존 Eval | 내용 | 이관 대상 | 변경 |
|-----------|------|----------|------|
| 1. URL 캡처 (DDD 기사) | URL → inbox/ 파일 생성 | para-pipeline | frontmatter에 `ai_distill_depth`, `distill_layer: 0` 추가 검증 |
| 2. 중복 감지 | 동일 URL 재캡처 거부 | para-pipeline | 그대로 |
| 3. 아카이브 거부 | 아카이브 노트 수정 불가 | para-brain | 그대로 |
| 4. 텍스트 메모 캡처 | 메모 → inbox/ 저장 | para-pipeline | 그대로 |
| 5-6. 분류 (수동+자동) | PARA 분류 | para-brain | 그대로 |
| 7. 주간 리뷰 | inbox 정리 + 분류 추천 | para-brain | 그대로 |
| 8-9. 플랫폼 크롤링 (Twitter, Threads) | 플랫폼별 전략 | para-pipeline | 그대로 |
| 10-11. YouTube 크롤링 | 메타데이터 + yt-dlp | para-pipeline | 그대로 |
| 12. 크롤 진단 | 로그 읽기/디버깅 | para-pipeline | 그대로 |

### 10.2 새 eval (Phase별 추가)

| CODE 단계 | Phase | 성공 기준 | 측정 방법 |
|-----------|-------|----------|----------|
| Capture + Distill | 1a | URL → inbox/ 파일 + Layer 2(볼드), Layer 4(Executive Summary) 포함 | para-pipeline eval |
| Organize + Reweave | 1a | 분류 추천 정확도 + related 역연결 관련성 | para-brain eval |
| Express Pull | 1b | vault 검색 시 관련 노트 적중률 + match 설명 품질 | 자동: 검색 결과 ≥ 1개, match 설명 필드 존재, 출처 경로 유효. 수동: 반환 노트의 실제 관련성 |
| Express Ambient | 1a | 일반 질문 시 vault 자동 참조 여부 | 자동: 훅 컨텍스트 주입 확인, vault grep 실행 여부. 수동: 인용 품질 |
| Express Push | 1d | 능동 추천의 연관성 + 사용자 반응 | 자동: 추천 노트 ≥ 1개, related에 미존재. 수동: 추천 → 사용자 열람/활용률 |

**Reweave eval 시나리오 (Phase 1a):**

1. **분류 시 역연결 추가**: 기존 vault에 `resources/ddd/bounded-context.md`가 있을 때, 새 노트를 `resources/ddd/`로 분류하면 기존 노트의 frontmatter에 `related:` 엔트리가 추가되는지 검증. 성공 기준: (a) 관련 기존 노트 1개 이상 발견, (b) `related.path`가 새 노트의 실제 경로와 일치, (c) `related.reason`이 의미 있는 연결 사유.
2. **write-path 예외 준수**: `classified` 노트에 `related:` 추가 시 본문과 다른 frontmatter 필드가 변경되지 않는지 검증. 성공 기준: diff가 `related:` 블록 추가만 포함.

## 11. 미결정 사항

**해소됨:**
- [x] 접근 방식 선택 → **C (2분할)** + Phase별 para-brain 확장 (§4.4)
- [x] `distill_layer` 필드 → `ai_distill_depth`(AI) + `distill_layer`(인간 확인)로 분리 (§7.3)
- [x] QMD 통합 시점 → Phase 1d 유지. Express Pull(1b)은 grep, Express Push(1d)는 QMD 전제 (§5)
- [x] 분류와 캡처 분리 → 캡처는 항상 inbox + 추천만, 자동분류는 para-brain의 별도 기능 (§7.4). `_settings.yaml` 스키마를 `auto_classify: boolean` → `auto_classify: {enabled, trigger, schedule}` 오브젝트로 변경

**미해소:**
- [ ] Express 능동 추천의 구체적 스케줄/트리거 (Phase 1d 시점에 결정)
- [ ] Distill 수동 트리거의 UX (메시지 명령? 스케줄?) — para-brain Phase 1a에서 "이 노트 다시 정리해줘" 메시지 명령으로 시작
- [ ] auto_classify trigger: on_capture의 정확한 실행 시점 — para-pipeline이 캡처 완료 메시지를 보낸 뒤 para-brain이 같은 세션에서 자동분류를 실행할지, 별도 세션(스케줄)으로 실행할지
- [ ] Claude Code vault 접근 방식 (MCP? 직접 읽기?) — QMD MCP 서버가 유력하지만 Phase 1d+
- [ ] Reweave의 자동화 수준 — Phase 1a에서는 분류 시에만 트리거, 추후 확장 검토
- [ ] Reweave write-path 예외를 PRD에 반영 — §7.2에서 `related:` 필드 에이전트 수정 허용을 결정했으나, PRD의 write-path 모델에 아직 미반영. §1.1a의 push/commit 불일치와 함께 PRD 수정 시 포함해야 함
- [ ] PRD 불일치 수정 — §1.1a에서 발견한 push/commit 불일치(PRD "git push" vs 구현 "commit only, scheduler push")를 PRD에 반영
- [ ] 주간 리뷰 스케줄 커스터마이즈 — 현재 "일요일 09:00" 하드코딩. `_settings.yaml`에 설정 가능하게 할지 (Phase 1a에선 하드코딩 OK, 추후 검토)
- [ ] SessionStart 훅 등록 방식 — `vault-context.sh`를 NanoClaw container-runner에서 자동 등록할지, 플러그인 설치 시 settings.json에 추가할지. 양쪽 호환 필요

---

## 부록: 참조 프로젝트 매핑

| CODE 단계 | 참조 프로젝트 패턴 | LinkDive 적용 |
|-----------|-------------------|--------------|
| Capture | khoj TextToEntries (8포맷), course Crawl4AI (비동기) | 현재 구현 유지 + 플랫폼별 전략 |
| Organize | arscontexta Reflect+Reweave, PARA 의사결정 트리 | Reweave 추가, 조건 기반 트리거 |
| Distill | BASB Progressive Summarization, course QualityScoring | Layer 2-4 자동화, 품질 스코어 선택적 |
| Express | Smart2Brain hybrid 검색 + match 배지, arscontexta MOC | QMD hybrid 검색, 능동 추천, match 설명 |
