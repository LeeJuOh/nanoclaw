# Second Brain CODE Redesign — Design Spec

> **Date**: 2026-03-22
> **Status**: Draft — 접근 방식 선택 전
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
| Match 설명 없음 | Smart2Brain: 왜 이 노트가 검색됐는지 배지 표시 (title/tag/semantic/recent) |
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
- **서브에이전트**: /ralph — 큐 기반 태스크, 단계별 fresh context (128k)
- **프리셋**: Research (atomicity 0.8), Personal (0.4), Experimental (사용자 정의)
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

- **검색**: MiniSearch(BM25) + HNSW(벡터) hybrid, recent boost (2.5x decay)
- **Match 배지**: title/tag/heading/content/semantic/recent — 왜 검색됐는지 설명
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
    references/
      note-template.md
      platform-strategies.md
      schema.md
      distill-layers.md
  para-brain/
    SKILL.md              ← Organize + Express (사용자 인터랙션)
    references/
      para.md
      express-patterns.md
```

**분리 원칙:** "사용자 개입 필요 여부"

| | para-pipeline (자동) | para-brain (인터랙션) |
|--|---------------------|----------------------|
| **트리거** | URL 감지, "캡처해" | 그 외 전부 |
| **성격** | 빠르게 처리하고 결과만 보고 | 대화형, 사용자 판단 필요 |
| **CODE** | Capture + Distill | Organize + Express |
| **사용자 개입** | 없음 (결과 알림만) | 분류 승인, 질문 답변, 추천 피드백 |

**para-pipeline (자동):**

```
URL/메모 수신
  → 플랫폼 감지 → 크롤링 → AI 분석
  → Progressive Summarization (Layer 1~4 자동)
  → Vault Connection 탐색 (기존 노트와 연결점)
  → inbox/ 저장 + git commit
  → 분류 추천 포함한 결과 메시지 전송
     "*캡처 완료: {title}*
      *핵심*: {Layer 4 요약}
      *연결*: {관련 기존 노트 2-3개}
      배치 추천: resources/ddd (기존)"
```

사용자 입장: URL 보내면 → 잠시 후 완성된 노트 + 분류 추천이 옴. 한 번의 메시지로 Capture+Distill+Organize 추천까지.

**para-brain (인터랙션):**

```
분류 명령
  → 추천 수락/변경 → git mv + frontmatter 업데이트
  → Reweave: 관련 기존 노트에 역연결 추가

PARA 관리
  → 프로젝트/영역/리소스 생성, 아카이브, 목록

질문/검색
  → vault 검색 → Match 설명 + 답변 합성
  → 볼트에 없으면 일반 지식 답변 (명시)

능동 추천 (스케줄)
  → 주간 리뷰: inbox 정리 + 분류 추천
  → 연결 발견: "이번 주 캡처와 관련된 기존 노트"
  → 조건 트리거: inbox > 10개 시 자동 알림

수동 Distill
  → "이 노트 다시 정리해줘" → Layer 재실행

프로젝트 지원
  → "프로젝트 X 시작" → 관련 Intermediate Packets 조립
```

**장점:**
- BASB 권장 패턴 반영 (Capture+Distill 자동, Organize 의도적 분리)
- 스킬 2개로 관리 단순
- 자동/인터랙션 경계가 명확 → 사용자 인지 부하 낮음
- para-pipeline은 속도 최적화, para-brain은 품질 최적화 가능
- Express의 능동 추천이 para-brain에 자연스럽게 통합

**단점:**
- para-pipeline에 Capture+Distill이 합쳐져 스킬이 다소 큼
- Distill 수동 트리거가 para-brain에 있어서 Distill 로직이 양쪽에 분산. **해소**: para-pipeline은 "자동 Distill"(캡처 시 Layer 1~4), para-brain은 "수동 재정제"(사용자 요청 시). 공유 레퍼런스 `distill-layers.md`로 일관성 유지
- 접근 B보다 각 단계의 독립 테스트가 어려움

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

QMD 도입 시점 판단 기준:
- vault 노트 수 300개 초과
- Express(능동적 추천) 구현 시작
- 사용자가 검색 품질에 불만 표시

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
distill_layer: 4
ai_executive_summary: "Aggregate는 트랜잭션 경계를 정의하는 클러스터..."
---

> **Executive Summary**: Aggregate는 트랜잭션 경계를 정의하는 클러스터...

## Core Claims

- **Aggregate는 일관성 경계다** — 하나의 트랜잭션에서...
- DDD에서 가장 흔한 실수는 ==Aggregate를 너무 크게 잡는 것==

## Key Arguments

- 작은 Aggregate가 **동시성 충돌을 줄인다**는 실증 데이터...
```

볼드(`**`)가 Layer 2, 상단 Executive Summary가 Layer 4.

**Layer 3 마커 선택지:**
- `==highlight==`: Obsidian에서만 렌더링됨. GitHub, iOS 앱에서는 무시됨
- `<mark>highlight</mark>`: GitHub에서 렌더링되지만 Obsidian에서는 플러그인 필요
- frontmatter `highlights: []` 배열: 렌더링 무관하게 데이터로 보존

**결정**: Phase 1a에서는 `==highlight==` 사용 (Obsidian이 주 소비자). Phase 1b(iOS 앱) 시점에 재검토. AI가 마킹하므로 나중에 포맷 일괄 변환 가능.

### 7.2 Reweave (역연결)

캡처/분류 시 관련 기존 노트 검색 → 역연결 추가.

**Write-path 충돌 해소**: PRD의 write-path 모델에서 `classified` 노트는 사용자만 수정 가능. Reweave가 기존 노트를 직접 수정하면 규칙 위반. 따라서 `related:` 추가는 **write-path 예외로 명시**: frontmatter의 `related:` 필드만 에이전트가 추가 가능, 나머지 필드와 본문은 기존 규칙 유지.

```yaml
# 기존 노트 (related: 필드만 에이전트 수정 허용)
---
title: "DDD Bounded Context 정의"
related:
  - path: "resources/ddd/20260322-aggregate-design.md"
    reason: "동일 도메인, 상위 개념"
    added: 2026-03-22
---
```

### 7.3 frontmatter 확장

```yaml
---
title: "Note title"
source: "https://..."
source_type: web           # web | memo | youtube | twitter | ...
captured: 2026-03-22T14:30:00+09:00
processed: 2026-03-22T14:30:05+09:00
status: pending_review     # raw | pending_review | classified | auto_classified
distill_layer: 4           # 1 | 2 | 3 | 4 (Progressive Summarization 단계)
contexts:
  - resources/ddd
  - projects/linkdive
tags: [ddd, aggregate, architecture]
ai_executive_summary: "한 줄 요약..."
ai_summary: "2-3 문장 요약"
ai_suggested_category: "resources/ddd"
related:                   # Reweave로 추가된 역연결
  - path: "resources/ddd/bounded-context.md"
    reason: "동일 도메인"
---
```

---

## 8. 비교 요약

| 기준 | A: 단일 스킬 | B: CODE 4분할 | C: 2분할 |
|------|-------------|-------------|---------|
| 스킬 수 | 1 | 4 | 2 |
| SKILL.md 크기 | ~600줄 | ~150줄씩 | ~300줄씩 |
| 컨텍스트 공유 | 자연스러움 | vault 파일 의존 | 중간 |
| 독립 테스트 | 어려움 | 쉬움 | 중간 |
| 사용자 인지 부하 | 낮음 (1개) | 높음 (4개 인식) | 낮음 (자동/대화 구분) |
| BASB 원칙 부합 | 중간 | 높음 (단계 명확) | 높음 (자동+의도적 분리) |
| 구현 난이도 | 낮음 | 높음 | 중간 |
| 확장성 | 비대해짐 | 좋음 | 좋음 |
| NanoClaw 호환 | 그룹 1개 | 그룹 1개, 스킬 4개 (전 그룹 로드) | 그룹 1개, 스킬 2개 (전 그룹 로드) |
| Express Push (Phase 1a) | grep 기반 제한적 | grep 기반 제한적 | grep 기반 제한적 |
| Express Push (Phase 1d+) | QMD hybrid | QMD hybrid | QMD hybrid |

---

## 9. 마이그레이션 전략

현재 `second-brain` 스킬(340줄, eval 96%)에서 각 접근으로의 전환:

| | A: 단일 스킬 | B: CODE 4분할 | C: 2분할 |
|--|-------------|-------------|---------|
| **변경 범위** | 기존 SKILL.md 확장 | 기존 SKILL.md 삭제 → 4개 신규 | 기존 SKILL.md 삭제 → 2개 신규 |
| **기존 eval 생존** | 대부분 유지 (Capture/Organize eval) | 스킬별 새 eval 필요 | 파이프라인용 eval 재작성 |
| **전환 방식** | 점진적 (기능 추가) | 한 번에 (atomic swap) | 한 번에 (atomic swap) |
| **그룹 CLAUDE.md** | 변경 없음 | 스킬 참조 업데이트 | 스킬 참조 업데이트 |
| **vault 호환** | 100% (기존 노트 그대로) | 100% (frontmatter 확장은 하위 호환) | 100% |

## 10. Eval 전략

| CODE 단계 | 성공 기준 | 측정 방법 |
|-----------|----------|----------|
| Capture | URL → inbox/ 파일 생성 + 올바른 frontmatter | 기존 eval 활용 |
| Organize | 분류 추천 정확도, 사용자 승인률 | A/B: 추천 vs 실제 분류 일치율 |
| Distill | Layer 4 요약이 원문 핵심을 반영하는가 | 요약 vs 원문 키워드 겹침률 |
| Express | vault 검색 시 관련 노트 적중률 | 질문 → 반환 노트의 관련성 (수동 평가) |
| Reweave | 역연결의 관련성 | related: 추가된 노트 쌍의 실제 관련도 |

## 11. 미결정 사항

- [ ] 접근 방식 선택 (A / B / C)
- [ ] QMD 통합 시점 (Phase 1a에 당길지, Phase 1d 유지할지)
- [ ] Express 능동 추천의 구체적 스케줄/트리거
- [ ] Distill 수동 트리거의 UX (메시지 명령? 스케줄?)
- [ ] Claude Code vault 접근 방식 (MCP? 직접 읽기?)
- [ ] Reweave의 자동화 수준 (캡처마다? 분류마다? 스케줄?)
- [ ] `distill_layer` 필드: 캡처 시 항상 4로 설정되면 무의미. 사용자 리뷰/수동 재정제 시에만 의미 → 인간이 확인한 최고 레이어를 추적하는 용도로 재정의 필요

---

## 부록: 참조 프로젝트 매핑

| CODE 단계 | 참조 프로젝트 패턴 | LinkDive 적용 |
|-----------|-------------------|--------------|
| Capture | khoj TextToEntries (8포맷), course Crawl4AI (비동기) | 현재 구현 유지 + 플랫폼별 전략 |
| Organize | arscontexta Reflect+Reweave, PARA 의사결정 트리 | Reweave 추가, 조건 기반 트리거 |
| Distill | BASB Progressive Summarization, course QualityScoring | Layer 2-4 자동화, 품질 스코어 선택적 |
| Express | Smart2Brain hybrid 검색 + match 배지, arscontexta MOC | QMD hybrid 검색, 능동 추천, match 설명 |
