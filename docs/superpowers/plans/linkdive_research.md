# LinkDive 리서치 — AI Second Brain 아키텍처 탐색

> 최종 정리: 2026-03-08
> 출처: prd_v1 → prd_v2 → prd_v3 → 검수 → v4 토론 → v5 토론 종합 → v6 토론 → v7 리서치 (QMD + Vox 분석) → v8 검수
> 상태: **방향 F 수렴** — iOS 앱 + NanoClaw 스킬
>
> **이 문서의 성격**: 리서치 + 의사결정 기록(ADR) + 기술 분석을 하나로 종합한 문서. prd_v1~v3의 발전 과정, 레퍼런스 프로젝트 비교, 아키텍처 탐색, 확정된 결정, 실행 계획을 담고 있다. 최종 방향은 **방향 F**이며, 이전 방향(A~E)은 의사결정 맥락으로 보존.

---

## 1. 프로젝트 경위

| 버전 | 방향 | 핵심 | 결과 |
|------|------|------|------|
| [prd_v1](./prd_v1.md) | **웹 앱** | 링크 저장 + PARA 분류 SaaS | 스코프 과다로 피봇 |
| [prd_v2](./prd_v2.md) | **웹 앱** | 소스 기반 노트 관리 + NotebookLM 연동 | 차별점 부족으로 피봇 |
| [prd_v3](./prd_v3.md) | **에이전트/하네스** | AI Second Brain (NanoClaw/OpenClaw 영향) | → 이 문서로 리서치 정리 |
| [pivot_analysis](./pivot_analysis.md) | 분석 | v2→v3 피봇 근거, 시장 조사, 레퍼런스 | v3의 기반 자료 |

### 방향 변화의 핵심

- v1/v2는 **"앱을 만들어서 사용자에게 제공"** 하는 SaaS 제품
- v3에서 NanoClaw/OpenClaw 생태계를 조사하면서 **"하네스 + 에이전트"** 방향으로 전환
- 이 과정에서 **웹 앱이 Phase 3으로 밀리고**, 텔레그램 + MCP가 Phase 1이 됨
- 근데 원래 만들려던 건 앱이었음 → **방향 재결정 필요**
- v4 토론에서 결론: **앱도 에이전트도 둘 다 필요** → NanoClaw를 베이스로 쓰고 텔레그램 대신 네이티브 앱을 UI로 붙이는 방향 (방향 D)
- v5 토론에서 재검토: NanoClaw 코드 분석 결과 **하네스를 직접 만들 필요 없음**. NanoClaw를 그대로 쓰고 second brain 스킬을 올리는 게 맞음. 채팅 UI도 텔레그램이면 충분. **Dashboard(시각적 vault 관리)가 LinkDive 고유 제품** (방향 E)
  - ⚠️ 단, NanoClaw 코어에는 WhatsApp만 구현되어 있음. Telegram은 `add-telegram` 스킬을 적용해야 사용 가능
- v6 토론에서 재검토: Dashboard를 Phase 2로 미루는 대신 **iOS 네이티브 앱을 처음부터 제품의 중심으로** 올림. 앱 = 캡처(공유시트) + vault 관리, 채팅 = 텔레그램/왓츠앱(NanoClaw 스킬 적용 후). GitHub repo = 유일한 공유 상태 (방향 F)

---

## 2. 문제 정의

### 페인포인트

- 정보는 넘치는데 다 읽을 시간이 없다
- 저장할 곳이 없다 — 브라우저 북마크, 카톡 나에게 보내기, 메모 앱에 흩어짐
- 저장해도 방치된다 — 분류가 귀찮아서
- AI Agent가 내 지식을 활용할 수 없다 — 사람용 도구와 Agent용 도구가 분리

### 핵심 가설 3개

| # | 가설 | 중요도 | 검증 난이도 | 검증 방법 |
|---|------|--------|------------|----------|
| H1 | 캡처 프릭션 ≈ 0이면 저장 습관이 생긴다 | 높음 | 중간 | 텔레그램 봇 or 앱 공유시트 |
| H2 | AI가 분류하면 방치 문제가 해결된다 | 높음 | 높음 | AI 파이프라인 필요 |
| H3 | 하나의 저장소를 사람과 Agent가 함께 쓸 수 있다 | 중간 | 낮음 | MCP 서버 + Obsidian |

가장 빠르게 가치를 주는 검증 순서: **H3 → H2 → H1**
> v5 실행 계획에서는 H1+H2(Phase 1b) → H3(Phase 2) 순으로 변경됨. 이유: NanoClaw+Obsidian으로 H3이 부분 달성되므로, H1(캡처 습관 = 제품 핵심 가치) 검증이 우선. 섹션 9 참조.

### 컨셉

> **"캡처는 인간처럼 쉽게, 활용은 Agent처럼 강력하게"**

---

## 3. 생태계 분석

### 3-1. 하네스/에이전트 생태계 (2026-03 기준)

OpenClaw가 문을 열고, 대안들이 폭발적으로 나오는 중.
([Kevin Simback의 OpenClaw 대안 리뷰](https://x.com/KSimback/status/2027812237390512631) 참고)

**Category 1 — Tiny Claws (경량 에이전트)**

| 프로젝트 | 언어 | 특징 |
|----------|------|------|
| **Nanobot** | Python | 읽기 쉬운 코드, ~4,000 lines (OpenClaw의 1/100) |
| **ZeroClaw** | Rust | 고성능, trait 기반 모듈화 |
| **PicoClaw** | Go | $10 하드웨어에서 동작, 10MB RAM |
| **NanoClaw** | Node.js | 컨테이너 격리, Agent SDK 네이티브, Agent Swarms. 범용 AI 에이전트 하네스 (Claude 전용 아님) |

대안들의 공통 목표 3가지:
1. **더 작게** — 이해 가능하고, 저렴한 하드웨어에서 돌리기
2. **더 안전하게** — 격리, allowlist, audit trail, 샌드박싱
3. **더 통제 가능하게** — 결정론적 워크플로우, 명시적 흐름

**Category 2 — Security-first 셀프 호스팅**

| 프로젝트 | 특징 |
|----------|------|
| **OpenFang** | "Agent OS" — ~32MB 바이너리, "Hands"(자율 워커) |
| **Hermes** | 보안 우선 |
| **Moltis** | 보안 우선 |
| **IronClaw** | 보안 우선 |

→ Part 2 (엔터프라이즈급)는 아직 미발표

### 3-2. 레퍼런스 프로젝트와 LinkDive의 관계

```
┌─────────────────────────────────────────┐
│  캡처 채널        → OpenClaw 유즈케이스  │  "폰에서 링크 보내면 끝"
├─────────────────────────────────────────┤
│  인프라/실행 엔진  → NanoClaw            │  폴링 하네스, SQLite 큐, Agent SDK
├─────────────────────────────────────────┤
│  PKM 철학/구조    → AI4PKM              │  Obsidian, inbox, PARA, 스케줄 처리
├─────────────────────────────────────────┤
│  검색 (Phase 1)   → QMD                 │  로컬 하이브리드 검색 (BM25+벡터+리랭킹)
├─────────────────────────────────────────┤
│  검색 (Phase 3+)  → PageIndex           │  PDF/긴 문서 추론 기반 검색
├─────────────────────────────────────────┤
│  참고 메커니즘     → Smart Connections   │  변경 감지, 청킹 패턴 참고
├─────────────────────────────────────────┤
│  사용자 UI        → Obsidian            │  vault 시각적 탐색 + 그래프 뷰
└─────────────────────────────────────────┘
```

| 뭘 가져오나 | 어디서 | LinkDive에서 |
|---|---|---|
| 에이전트 플랫폼 전체 (폴링, 큐, 격리, 스케줄러, 채팅) | **NanoClaw** | 그대로 사용. `/setup-second-brain` 스킬로 확장. 텔레그램은 `add-telegram` 스킬 적용 필요 (코어는 WhatsApp만 구현) |
| Obsidian vault, inbox 개념, DIR/WRP 스케줄 | **AI4PKM** | PARA 폴더 구조, 자동 분류 |
| 제로 프릭션 캡처 철학 | **OpenClaw 유즈케이스** | 텔레그램 캡처 (NanoClaw `add-telegram` 스킬 적용 후). 공유시트는 iOS 앱 |
| PARA 분류, Quality Gates | **OpenClaw PARA Skill** | AI 분류 추천 + 품질 체크리스트 |
| 로컬 하이브리드 검색 (BM25+벡터+LLM 리랭킹) | **QMD** | Phase 1d 시맨틱 검색 백엔드 (MemSearch에서 교체) |
| PDF/긴 문서 추론 기반 검색 | **PageIndex** | Phase 3+ PDF 전용 검색 |
| 변경 감지, 2단 임베딩 패턴 | **Smart Connections** | 기술 메커니즘 참고 (직접 사용 X) |
| vault 시각적 탐색 + 그래프 뷰 | **Obsidian** | 핵심 열람 UI — Dashboard 대안/보완 |

**솔직한 평가**: NanoClaw를 플랫폼으로 그대로 쓰고, second brain 스킬을 컨트리뷰션. iOS 앱(캡처+시각적 vault 관리)이 LinkDive 고유 제품.

### 3-3. 시장 조사 (AI Agent Memory / Knowledge Base)

| 프로젝트           | GitHub                                                                    | 핵심                                      |
| -------------- | ------------------------------------------------------------------------- | --------------------------------------- |
| Letta (MemGPT) | [letta-ai/letta](https://github.com/letta-ai/letta)                       | Agent 자체 메모리 관리 (OS 가상메모리 방식)           |
| Mem0           | [mem0ai/mem0](https://github.com/mem0ai/mem0)                             | Agent용 범용 메모리 레이어 (Vector+Graph+KV)     |
| Khoj           | [khoj-ai/khoj](https://github.com/khoj-ai/khoj)                           | 셀프호스팅 AI 세컨드 브레인. 33k+ 스타. PostgreSQL+pgvector, Django, Next.js, Docker 4컨테이너. LLM API 키 방식. **가장 유사한 기존 제품** — 섹션 5-10 상세 비교 |
| RAGFlow        | [infiniflow/ragflow](https://github.com/infiniflow/ragflow)               | 엔터프라이즈 RAG + 메모리 모듈                     |
| Graphiti / Zep | [getzep/graphiti](https://github.com/getzep/graphiti)                     | 시간 인식 지식 그래프                            |
| Supermemory    | [supermemoryai/supermemory](https://github.com/supermemoryai/supermemory) | 개인 메모리 엔진 + 앱                           |
| Cognee         | [topoteretes/cognee](https://github.com/topoteretes/cognee)               | 지식 그래프 기반 Agent 메모리                     |
| MemSearch      | [zilliztech/memsearch](https://github.com/zilliztech/memsearch)           | Markdown-first 시맨틱 검색 (OpenClaw 메모리 추출). ~~Phase 1 검색 후보~~ → QMD로 교체 |
| **QMD**        | [tobi/qmd](https://github.com/tobi/qmd)                                   | 로컬 하이브리드 검색 (BM25+벡터+LLM 리랭킹+쿼리 확장). Node.js. Tobi Lütke(Shopify 창업자) 제작. **Phase 1d 검색 백엔드로 채택** |

---

## 4. 아키텍처 탐색

### 4-1. 탐색한 아키텍처 (prd_v3 → v4 → v5 토론 반영)

**v3 원안:**
```
[캡처] iOS 공유시트 / 텔레그램 / CLI / Claude Code
       ↓
[하네스] 로컬 Node.js (폴링) → 큐
       ↓
[AI 처리] Claude Agent SDK
       ↓
[저장소] GitHub Private Repo (Markdown + YAML frontmatter)
       ↓
[접근] 앱/웹 + Obsidian + MCP 서버
```

**v4 토론 — 방향 D (폐기):**
```
네이티브 앱 ── GitHub OAuth ──→ GitHub vault repo
                                      ↑
                               NanoClaw 베이스 하네스
```
→ 폐기 이유: NanoClaw 코드 분석 결과, 하네스를 직접 만들 필요 없음. NanoClaw의 텔레그램 채널을 네이티브 앱으로 대체하는 것도 불필요 — 텔레그램 채팅이 충분히 강력.

**v5 토론 후 수렴 중인 아키텍처 (방향 E):**
```
┌─────────────────────┐              ┌────────────┐
│ Dashboard (웹앱)     │── GitHub ──→ │ GitHub     │
│ GitHub Pages        │   API        │ vault repo │
│                     │              │ (markdown) │
│ · 인박스 시각화      │              └────────────┘
│ · 링크 설정/태그     │                    ↑
│ · PARA 이동         │               git pull/push
│ · 검색              │                    │
└─────────────────────┘           ┌──────────────────┐
                                  │ NanoClaw           │
  텔레그램/왓츠앱 ───────────────→ │                   │
  (캡처 + 채팅)                   │ + second brain    │
                                  │   스킬             │
                                  │ · vault 그룹       │
                                  │ · AI 요약/태그     │
                                  │ · PARA 분류        │
                                  │ · 스케줄 처리       │
                                  └──────────────────┘
```

핵심 특징:
- **NanoClaw = 플랫폼** — 하네스, 큐, 스케줄러, 채팅, 컨테이너 격리 모두 재활용
- **스킬 = 컨트리뷰션** — `/setup-second-brain` 스킬을 NanoClaw 공식 repo에 PR
- **Dashboard = LinkDive 고유 제품** — GitHub Pages 웹앱, 시각적 vault 관리 (Phase 2)
- **추가 API 비용 0원** — NanoClaw가 Claude Agent SDK를 Max 구독으로 실행 (Max 구독 비용은 별도)
- **채팅은 텔레그램** — 캡처, 질의, 분류 모두 메시징 채널로 (NanoClaw `add-telegram` 스킬 적용 필요)

**v6 토론 후 수렴된 아키텍처 (방향 F):**

방향 E에서 Dashboard를 Phase 2로 미뤘으나, 재검토 결과 **iOS 앱을 처음부터 제품의 중심으로** 올림.
채팅은 텔레그램/왓츠앱(NanoClaw, 각각 스킬 적용 후)에 남기고, 앱은 캡처+시각적 관리 전담.

```
┌───────────────────────────┐         ┌────────────┐
│  LinkDive iOS App (Swift) │ GitHub  │  GitHub    │
│                           │  API    │  vault     │
│  · GitHub 로그인          │────────→│  repo      │
│    (Device Flow → OAuth)  │         │ (markdown) │
│  · 공유시트 캡처 (URL/텍스트)│←───────│            │
│  · 인박스 시각화           │  API    └────────────┘
│  · 태그/PARA 관리         │               ↑
│  · 검색 (GitHub Search API)│          git pull/push
│  · 채팅 없음              │               │
└───────────────────────────┘      ┌──────────────────┐
                                   │ NanoClaw          │
  텔레그램/왓츠앱 ────────────────→│ (사용자 로컬 Mac) │
  (채팅 + 간편 캡처)               │                   │
                                   │ + second brain    │
                                   │   스킬             │
                                   │ · vault repo 폴링  │
                                   │ · AI 크롤링/요약   │
                                   │ · PARA 분류        │
                                   │ · 스케줄 처리       │
                                   │ · QMD 검색         │
                                   └──────────────────┘
```

핵심 특징:
- **iOS 앱 = LinkDive 제품** — 캡처(공유시트) + 시각적 vault 관리. 채팅 없음
- **NanoClaw = AI 엔진** — 처리, 분류, 채팅, 스케줄. 텔레그램/왓츠앱이 채팅 UI (각각 `add-telegram`/`add-whatsapp` 스킬 적용 후)
- **GitHub repo = 유일한 공유 상태** — 앱과 NanoClaw가 서로 모름. repo만 보고 각자 일함
- **서버 없음 (MVP)** — 앱이 GitHub API 직접 호출. Device Flow 인증. **오프라인 미지원** — 인터넷 없으면 앱 기능 불가 (오프라인 캐싱은 Phase 2 검토)
- **Write Path** — status 기반 단일 작성자 원칙으로 Git 충돌 구조적 방지. 단, Obsidian 동시 사용 시 status convention 인식 불가 — Obsidian 편집은 `approved` 이후 노트에 한정 권장

### 4-2. NanoClaw의 역할과 LinkDive의 관계

**방향 E에서 NanoClaw는 "플랫폼"이고 LinkDive는 두 가지로 구성된다:**

```
1. /setup-second-brain 스킬 (NanoClaw에 컨트리뷰션, 오픈소스)
   → vault 그룹 설정, PARA 분류 규칙, AI 처리 지침, 스케줄 태스크

2. Dashboard 웹앱 (LinkDive 고유 제품, 별도 repo)
   → GitHub Pages, 시각적 vault 관리
```

**NanoClaw 코드 분석에서 확인한 재활용 가능 인프라:**

| NanoClaw에 이미 있음 | LinkDive에서의 역할 |
|---|---|
| Channel 인터페이스 (코어: WhatsApp, 스킬: Telegram/Slack/Discord/Gmail) | 텔레그램으로 캡처 + 채팅 (`add-telegram` 스킬 적용 필요) |
| 2초 폴링 루프 + SQLite 메시지 큐 | raw 파일 감지 및 처리 큐 |
| Claude Agent SDK 컨테이너 실행 | AI 요약/태그/분류 처리 |
| 스케줄러 (cron/interval/once) | 주기적 배치 처리 |
| IPC (JSON 파일 기반) | Agent ↔ 외부 통신 |
| 그룹 격리 (폴더 + CLAUDE.md) | vault를 하나의 그룹으로 마운트 |
| `/update-nanoclaw` 스킬 | 업스트림 업데이트 따라가기 |

**Git 충돌 방지 — 단일 작성자 원칙 유지:**
- `status: raw` 파일 → NanoClaw Agent만 수정
- `status: pending_review` 이후 → Dashboard/사용자만 수정

### 4-3. 저장소 결정: "파일 primary, DB derived"

"DB 없음"이 아니라 **"markdown 파일이 primary, SQLite는 derived"** 구조.

```
GitHub (markdown 파일)  ← 진실의 원천 (source of truth)
        ↕ git pull/push
로컬 파일시스템          ← 작업 공간
        ↓ 빌드
SQLite                  ← 파생 인덱스 (언제든 재빌드 가능)
```

이 구조를 쓰는 이유:

| | 파일 primary (현재) | DB primary |
|---|---|---|
| Obsidian 호환 | 그대로 열림 | 별도 sync 레이어 필요 |
| 사람이 직접 편집 | VS Code로 바로 | 앱/API 거쳐야 함 |
| 버전 관리 | git이 해줌 | 직접 구현해야 함 |
| 데이터 소유권 | markdown 파일 = 내 것 | DB 포맷에 갇힘 |
| Agent 접근 | markdown 파싱 쉬움 | DB 스키마 의존 |
| 인프라 비용 | 0원 | DB 호스팅 필요 (배포 시) |

SQLite의 역할 (캐시이자 인덱스):
- 처리 큐: 텔레그램에서 들어온 링크 → 처리 대기열
- 태그 인덱스: "AI 태그 붙은 노트 목록" 같은 쿼리를 grep 없이 즉시
- 처리 로그: timestamp, action, duration, success/fail

핵심 테스트: **SQLite를 삭제하고 `rebuild-index` 한 번 돌리면 100% 복구되는가?** Yes면 올바른 구조.

### 4-4. 방향 F — Write Path (충돌 방지)

앱과 NanoClaw가 같은 repo에 쓰므로 status 기반 단일 작성자 원칙 적용:

| status | 쓰기 권한 | 설명 |
|--------|----------|------|
| `raw` | **앱**이 생성, **NanoClaw만** 수정 | 캡처 직후. 앱은 읽기만 |
| `pending_review` | **NanoClaw**가 전환, **앱/사용자만** 수정 | AI 처리 완료. NanoClaw는 읽기만 |
| `approved` | **앱/사용자만** | 사용자 승인 완료 |
| `auto_classified` | **NanoClaw**가 전환 | 자동 분류 완료 (고신뢰도) |

상태 전이:
```
raw ──NanoClaw처리──→ pending_review ──사용자승인──→ approved
                      NanoClaw auto──→ auto_classified
```

같은 파일을 동시에 쓰는 경우가 구조적으로 불가능.

**⚠️ Obsidian 예외**: Obsidian은 status convention을 인식하지 못함. Obsidian에서 `raw`/`pending_review` 상태의 파일을 편집하면 NanoClaw와 충돌 가능. 권장: Obsidian 편집은 `approved`/`auto_classified` 상태의 노트에 한정. Obsidian Git 플러그인의 auto-commit 주기를 NanoClaw 처리 주기보다 길게 설정.

### 4-5. 방향 F — 검색 전략

검색이 두 곳에서 일어남:

| 검색 위치 | 방법 | 시점 |
|----------|------|------|
| **iOS 앱** | GitHub Search API (키워드) | Phase 1b~ |
| **NanoClaw (텔레그램 채팅)** | grep → QMD | Phase 1a~ → 1d~ |
| **iOS 앱 (고도화)** | GitHub Search API + QMD 결과 캐시 | Phase 2~ |

Phase별 검색 진화:
- 1a: NanoClaw grep (텔레그램 채팅)
- 1b: + iOS 앱 GitHub Search API (키워드)
- 1d: + NanoClaw QMD (하이브리드 시맨틱, 텔레그램 채팅). persistent server 모드로 콜드스타트 방지
- 2: + 앱에서 QMD 결과 활용 (NanoClaw가 검색 → 결과를 repo에 캐시 or 앱이 직접 호출)
- 4+: + PageIndex (긴 문서/PDF)

---

## 5. 레퍼런스 프로젝트 상세 비교

### 5-1. AI4PKM

| 요소 | AI4PKM | LinkDive 적용 |
|------|--------|--------------|
| 저장소 | Obsidian vault (로컬) | GitHub repo (동기화) |
| AI 처리 | Claude Code 직접 실행 | Claude Code CLI subprocess (동일 방식) |
| 자동화 | 오케스트레이터 + 폴러 (Python) | NanoClaw 베이스 하네스 (git pull 폴링) |
| inbox 개념 | `_Inbox_/` 폴더 | `inbox/` 폴더 |
| 스케줄 처리 | DIR(매일) / WRP(매주) / CKU(매시간) | 유사 구조 도입 가능 |
| 사람 UI | Obsidian only | 텔레그램 + Obsidian + Dashboard (Phase 2) |

### 5-2. NanoClaw

| 요소 | NanoClaw | LinkDive 적용 |
|------|----------|--------------|
| 하네스 | WhatsApp 폴링 (코어), Telegram/Slack/Discord/Gmail (스킬) | **그대로 사용** (vault 그룹 추가, `add-telegram` 스킬 적용) |
| AI 엔진 | Agent SDK (Claude Code 경유, Max 구독) | **그대로 사용** |
| 인터페이스 | WhatsApp(코어)/Telegram(스킬) (메시징이 곧 UI) | **그대로 사용** + iOS 앱 + Obsidian |
| 격리 | Apple Container / Docker | **그대로 사용** |
| 메시지 큐 | SQLite | **그대로 사용** |
| 메모리 | CLAUDE.md (그룹별) | vault 그룹 CLAUDE.md에 PARA 규칙 정의 |

v5에서의 핵심 전환: NanoClaw를 "베이스로 커스텀"하는 게 아니라 **그대로 쓰고 스킬만 추가**.

#### NanoClaw 메모리 시스템 분석 (코드 기반)

**3단 계층 구조 (전부 마크다운 파일, 벡터 DB 없음)**

| 계층 | 위치 | 접근 권한 | 역할 |
|------|------|----------|------|
| **Global** | `groups/global/CLAUDE.md` | 읽기 전용 (non-main) | 전체 그룹 공통 지시사항. SDK `append` 옵션으로 주입 |
| **Per-Group** | `groups/{name}/CLAUDE.md` | 읽기/쓰기 | 그룹별 기억, 설정, 정체성. SDK가 `cwd`+`settingSources: ['project']`로 자동 로드 |
| **Ad-hoc** | `groups/{name}/*.md` | 읽기/쓰기 | 에이전트가 자유롭게 생성하는 구조화 데이터 (고객 목록, 리서치 등) |

**세션 재개**: SQLite `sessions` 테이블에 세션 ID 저장 → SDK `resume` 옵션으로 JSONL 트랜스크립트 복원. 1차 인컨텍스트 메모리.

**대화 아카이브**: `PreCompact` 훅이 컨텍스트 압축 전 JSONL 트랜스크립트를 `conversations/{date}-{title}.md`로 자동 저장. `sessions-index.json`에서 제목 생성. 키워드 검색만 가능 (grep/Read).

**additionalMounts 보안 모델**: `containerConfig.additionalMounts`로 외부 디렉토리를 `/workspace/extra/{name}/`에 마운트. `~/.config/nanoclaw/mount-allowlist.json`으로 검증 (프로젝트 외부 = 에이전트 변조 불가). blockedPatterns(`.ssh`, `.gnupg`, `.aws` 등), `nonMainReadOnly`, `allowReadWrite` 지원.

**벡터/시맨틱 검색 = 없음**: 벡터 DB, 임베딩, 시맨틱 유사도 인프라 전무. `conversations/` 아카이브도 grep/Read 기반 키워드 검색만 가능. → **QMD로 보완 필수**.

#### NanoClaw vs OpenClaw 메모리 비교

| | NanoClaw | OpenClaw |
|---|---|---|
| 기본 메모리 | CLAUDE.md (3단 계층) | MEMORY.md + daily logs |
| 세션 지속성 | SQLite + SDK resume | SDK resume |
| 아카이브 | conversations/*.md (PreCompact 자동) | daily logs (자동) |
| **시맨틱 검색** | **없음** → QMD로 보완 (LinkDive 스킬) | **memory_search (벡터)** |
| 외부 마운트 | additionalMounts + allowlist | 없음 |
| 그룹 격리 | 컨테이너 + 폴더 분리 | 없음 (단일 인스턴스) |

### 5-3. OpenClaw PARA Skill

| | OpenClaw PARA Skill | LinkDive |
|---|---|---|
| 핵심 목적 | Agent의 컨텍스트 윈도우 한계 극복 | 사람의 정보 과부하 해결 |
| 주 사용자 | AI Agent (Clawdbot) | 사람 + AI Agent (듀얼) |
| 분류 주체 | Agent가 Decision Tree로 자동 | AI 추천 + 사람 승인 |
| 외부 캡처 | 없음 (Agent 대화 내에서만) | 텔레그램 / CLI / 앱 / 브라우저 |
| 사람 친화 UI | 없음 (Agent 전용) | 자체 앱/웹 + Obsidian 옵션 |

가져올 아이디어: Decision Tree 분류 로직, Content Templates, Quality Gates, Session Transcript Indexing, Curation Cadence

### 5-4. OpenClaw Second Brain 유즈케이스

핵심 차이: **"분류를 없앨 것인가 vs AI가 대신 할 것인가"**

- OpenClaw: 분류 자체를 제거 (zero-organization). 검색만으로 접근
- LinkDive: 분류의 가치는 유지, AI가 부담을 흡수

가져올 아이디어: 글로벌 서치 UX (Cmd+K), 제로 프릭션 온보딩, 자동 분류 모드 검증

### 5-5. QMD (Phase 1d 검색 백엔드로 채택)

> MemSearch에서 QMD로 교체. 이유: 검색 품질(쿼리 확장+리랭킹), Node.js 스택 일치, MCP 퍼스트클래스 지원.

| | QMD | LinkDive |
|---|---|---|
| 정체 | 로컬 CLI 검색 엔진 (마크다운 전용) | 시스템 (캡처 → 정리 → 접근) |
| 만든이 | Tobi Lütke (Shopify 창업자) | - |
| 언어 | **Node.js** (NanoClaw와 동일 스택) | Node.js (NanoClaw) + Swift (iOS 앱) |
| 범위 | 하이브리드 검색 (BM25 + 벡터 + LLM 리랭킹) | 캡처 + AI 처리 + 분류 + 검색 + UI |

**검색 파이프라인 (3단계 + 쿼리 확장):**

```
[1] 쿼리 확장 — 커스텀 1.7B 모델이 lex(키워드)/vec(시맨틱)/hyde(가상문서) 3종 변형 생성
       ↓
[2] 병렬 검색 — 원본(2x 가중치) + 2개 변형 × (BM25 + 벡터) = 6개 랭킹 리스트
       ↓
[3] RRF 퓨전 — Reciprocal Rank Fusion (k=60) → 상위 30개 후보
       ↓
[4] LLM 리랭킹 — Qwen3-Reranker 크로스인코더 (yes/no logprobs, 0-10 스케일)
       ↓
[5] Position-Aware 블렌딩 — RRF 75%(상위 1-3위) / 60%(4-10위) / 40%(11+위) 가중 최종 스코어
```

**모델 3개 (~2GB, GGUF, 자동 다운로드):**

| 모델 | 크기 | 용도 |
|------|------|------|
| Embedding Gemma 300M | ~300MB | 벡터 임베딩 |
| Qwen3-Reranker 0.6B | ~640MB | 크로스인코더 리랭킹 |
| QMD Query Expansion 1.7B (커스텀 파인튜닝) | ~1.1GB | 타입별 쿼리 확장 |

**청킹:** 스코어링 알고리즘 (~900토큰, 15% overlap). 헤딩 > 문단 > 문장 경계 순 우선. 코드블록 보호 (내부에서 분할 금지).

**MCP 서버 (퍼스트클래스):**

| 도구 | 설명 |
|------|------|
| `qmd_search` | BM25 키워드 검색 |
| `qmd_vector_search` | 시맨틱 벡터 검색 |
| `qmd_deep_search` | 풀 하이브리드 (확장+BM25+벡터+리랭킹) |
| `qmd_get` | 경로/docid로 문서 조회 |
| `qmd_multi_get` | glob/리스트/docid 배치 조회 |
| `qmd_status` | 인덱스 상태 확인 |

전송 모드: stdio(기본) / HTTP(`--http`, localhost:8181) / HTTP 데몬(`--http --daemon`, 모델 상주로 콜드스타트 제거)

**NanoClaw 통합 방식:**
```
NanoClaw vault 그룹 디렉토리 → QMD가 인덱싱
       ↓
QMD MCP 서버 (persistent HTTP 모드) → NanoClaw Agent가 도구로 호출
       ↓
에이전트/사용자가 텔레그램 채팅으로 시맨틱 검색
```

**Obsidian 플러그인:** [obsidian-qmd](https://github.com/achekulaev/obsidian-qmd) — Obsidian에서도 동일한 QMD 검색 사용 가능. 앱/텔레그램/Obsidian 3곳에서 일관된 검색 경험.

**QMD vs MemSearch (교체 근거):**

| | QMD | MemSearch |
|---|---|---|
| 쿼리 확장 | **있음** (커스텀 1.7B 모델) | 없음 |
| 리랭킹 | **있음** (Qwen3 크로스인코더) | 없음 (RRF만) |
| 언어 | **Node.js** (NanoClaw 일치) | Python (subprocess 필요) |
| MCP 서버 | **퍼스트클래스** (6개 도구) | 없음 (hooks 기반) |
| Obsidian 플러그인 | 있음 | 없음 |
| 완전 로컬 | 항상 (API 키 불필요) | 옵션 (sentence-transformers or Ollama) |
| 디스크 | ~2GB (GGUF 모델) | 가벼움 |
| 콜드스타트 | ~15초 (서버 모드면 0) | 빠름 |
| 토큰 절감 | 95%+ (600개 노트 vault 검증) | 유사 |
| 파일 와치 | 서버 모드로 대체 | `mem.watch()` 1500ms |
| 메모리/세션 | 검색 전용 | 세션 요약, 메모리 로그 포함 |

**결론**: 검색 품질(쿼리 확장+크로스인코더)과 스택 일치(Node.js)가 결정적. MemSearch의 파일 와치와 세션 요약 기능은 NanoClaw 스케줄 태스크로 대체 가능.

### 5-6. PageIndex

벡터 DB 없이 LLM 추론만으로 문서를 검색하는 시스템. 20k+ 스타, MIT 라이선스.

| | PageIndex | QMD |
|---|---|---|
| 접근법 | 벡터 없음 — LLM 추론 기반 트리 탐색 | 하이브리드 (BM25 + 벡터 + 쿼리 확장 + LLM 리랭킹) |
| 핵심 아이디어 | "유사성 ≠ 관련성" — 문서를 계층 트리로 만들고 LLM이 추론으로 탐색 | 스코어링 기반 청킹 + 3단계 검색 파이프라인 |
| 최적 대상 | 긴 문서 (재무보고서, 논문, 법률문서, PDF). **마크다운도 지원** (`#` heading 기반 파싱) | 짧은~중간 마크다운 노트 다수 (개인 지식베이스) |
| 인프라 | 벡터 DB 불필요, LLM API만 필요 | SQLite + sqlite-vec, 로컬 GGUF 모델 |
| 비용 | 검색 때마다 LLM 호출 (토큰 비용) | 임베딩+리랭킹 모두 로컬 (비용 0) |
| MCP 지원 | 있음 | 있음 (퍼스트클래스, 6개 도구) |
| 멀티모달 | Vision 기반 PDF 직접 분석 (OCR 불필요) | 텍스트 마크다운만 |

**LinkDive에서의 위치**: Phase 4+ 긴 문서 전용 (PDF + 긴 마크다운). 짧은 노트는 QMD, 긴 문서/PDF는 PageIndex로 병용. 웹 아티클은 마크다운 변환 후 QMD로 검색 가능. PDF 원본을 그대로 보관하면서 검색할 때만 PageIndex 필요.

### 5-7. Smart Connections (기술 메커니즘 참고)

Obsidian 플러그인. 직접 사용하지는 않지만 기술 패턴 참고용으로 검토.

**참고할 기술 패턴:**

| 패턴 | Smart Connections 방식 | LinkDive 적용 가능성 |
|------|----------------------|---------------------|
| 변경 감지 | `mtime` 기반 — 파일 수정 시간 비교로 재인덱싱 대상 판별 | QMD 서버 모드에서 유사. 대규모 vault에서 효율적 |
| 2단 임베딩 | SmartSource(파일 단위) + SmartBlock(heading/블록 단위) | QMD의 스코어링 기반 청킹과 유사 접근 |
| 저장 포맷 | AJSON (Append-only JSON) — 한 줄씩 추가, 전체 재작성 불필요 | 임베딩 캐시 저장에 참고 |
| 파일 감시 | 이벤트 기반 (Obsidian API의 vault 이벤트) | NanoClaw는 폴링 기반이므로 직접 적용 어려움 |

**결론**: Smart Connections의 핵심 가치(변경 감지, 청킹)는 QMD에도 유사하게 존재. 별도 통합보다 QMD 사용이 우리 아키텍처에 맞음. Obsidian에서는 obsidian-qmd 플러그인으로 동일한 검색 경험 제공, Smart Connections 플러그인은 vault 내 시맨틱 연결을 시각적으로 보는 보조 UI로 유용.

### 5-8. Symphony (설계 패턴 참고)

OpenAI가 만든 코딩 작업 관리 시스템(work management system). Linear 이슈 트래커에서 이슈를 폴링 → 이슈별 격리 워크스페이스 생성 → Codex 자동 실행. Apache 2.0.

**"사람이 에이전트를 감독하는 게 아니라, 작업을 관리하면 에이전트가 알아서 실행"**

| | Symphony | NanoClaw | LinkDive 적용 |
|---|---|---|---|
| AI 엔진 | Codex (OpenAI) | Claude Agent SDK | NanoClaw 따름 |
| 주 용도 | 코딩 작업 (이슈→PR) | 범용 에이전트 | PKM (캡처→정리→접근) |
| 입력 | Linear 이슈 트래커 | 메시징 (Telegram 등) | NanoClaw 따름 |
| 설정 파일 | WORKFLOW.md (YAML+프롬프트) | CLAUDE.md (비정형) | CLAUDE.md 구조화 참고 |
| 워크스페이스 격리 | 이슈별 디렉토리 | 그룹별 컨테이너 | NanoClaw 따름 |
| 상태 머신 | 정교 (5단계 + 재시도/백오프) | 단순 | 노트 처리 파이프라인에 단순화 적용 |
| 관측성 | Phoenix LiveView 대시보드 | 채팅 기반 | Phase 2 Dashboard 참고 |
| 언어 | Elixir/OTP | Node.js | Node.js |

**가져올 설계 패턴:**

| 패턴 | Symphony 방식 | LinkDive 적용 가능성 |
|------|-------------|-------------------|
| WORKFLOW.md | YAML front matter(설정) + Markdown body(프롬프트)를 하나의 파일에 통합 | CLAUDE.md 구조화: front matter에 vault 설정(PARA 규칙, 자동분류 threshold, 스케줄), body에 에이전트 행동 지침 |
| 라이프사이클 훅 | `after_create`, `before_run`, `after_run`, `before_remove` | vault 초기화(git clone, PARA 폴더), 실행 전 git pull, 실행 후 git commit & push |
| 재시도/백오프 | 실패 시 `min(10s × 2^(attempt-1), 5m)`, 성공 후 1초 continuation | 크롤링 실패, AI 처리 실패 시 exponential backoff. 현재 status 설계에 재시도 로직 없어서 보완 필요 |
| 프롬프트 템플릿 | Liquid 변수 치환 (`{{ issue.title }}`) + strict 모드 | AI 처리 프롬프트 커스터마이즈: `{{ note.url }}`, `{{ vault.tags }}` 등 |
| 관측성 대시보드 | 에이전트 상태, 토큰 사용량, 재시도 큐, 세션 로그 | Phase 2 Dashboard에 처리 파이프라인 상태, AI 처리 로그, vault 통계 추가 |

**직접 코드 활용 불가인 부분:** Codex app-server 프로토콜(OpenAI 전용), Linear 통합(도메인 불일치), Elixir/OTP 구현(스택 불일치).

**결론**: NanoClaw와 같은 "에이전트 작업 관리" 카테고리지만 목적이 다름 (코딩 자동화 vs 범용 에이전트). 직접 코드 재활용은 불가하나, 설정 패턴(WORKFLOW.md)·라이프사이클 훅·재시도 로직·관측성 구조는 LinkDive 설계에 참고할 가치 있음.

### 5-9. Khoj

**가장 유사한 기존 제품.** "AI 세컨드 브레인"을 표방하는 오픈소스 셀프호스팅 앱. 33k+ 스타.

| 요소 | Khoj | LinkDive (방향 F) |
|------|------|-------------------|
| 철학 | 전통적 서버 앱 — DB가 모든 걸 관리 | 에이전트 + 앱 — repo가 공유 상태 |
| AI 연결 | LLM API 키 (종량제, 멀티 LLM) | Claude Max 구독 (Agent SDK, 월정액) |
| 저장소 | PostgreSQL + pgvector | GitHub repo (markdown 파일) |
| 검색 | 3단계: bi-encoder(gte-small) → 필터(word/file/date) → cross-encoder(mxbai-rerank) 리랭킹 + LLM 쿼리 확장(2-5 서브쿼리) | grep(현재) → QMD(Phase 1d, BM25+벡터+리랭킹+쿼리 확장) → +PageIndex(Phase 4) |
| 인프라 | Docker 4컨테이너 (PostgreSQL+pgvector, SearXNG, Terrarium 샌드박스, Django 서버) | iOS 앱(서버 없음) + NanoClaw 1프로세스 |
| 데이터 포맷 | DB Entry 레코드 (256토큰 청크) | 마크다운 파일 (YAML frontmatter) |
| 데이터 소유 | DB에 갇힘 (export 필요) | 100% git (마크다운 = 내 파일) |
| 캡처 채널 | 브라우저 확장, Obsidian 플러그인, Emacs, 데스크톱 앱, WhatsApp | iOS 공유시트(앱) + 텔레그램/왓츠앱(NanoClaw) |
| 분류 체계 | 없음 (파일 단위 인덱싱만) | PARA + AI 자동 분류 |
| 에이전트 | 커스텀 에이전트 (페르소나+도구 조합, DB 저장) | NanoClaw 그룹별 CLAUDE.md |
| 자동화 | APScheduler cron (이메일 알림) | NanoClaw 스케줄 태스크 |
| 메모리 | UserMemory (대화에서 자동 추출, pgvector 저장) | CLAUDE.md 구조화 (5단 인지 모델) + QMD |
| 사용자 UI | Next.js 웹앱 + PWA + 데스크톱 | iOS 네이티브 앱 + Obsidian |
| 운영 비용 | 서버 + LLM API 비용 | 0원 (Claude Max 구독만) |
| Obsidian | 플러그인 (파일 → API → DB 동기화) | 직접 vault 열기 (같은 디렉토리) |

**Khoj에서 배울 점:**
1. 쿼리 확장 — 질문 1개 → LLM으로 2-5개 서브쿼리 생성 후 각각 검색. QMD가 이미 유사 기능 내장 (커스텀 1.7B 확장 모델)
2. Cross-encoder 리랭킹 — bi-encoder 후보 → cross-encoder 정밀 재순위
3. UserMemory — 대화에서 사실 정보 자동 추출하여 별도 저장. CLAUDE.md 자동 학습에 참고
4. 청크 단위 해시 중복 방지 — MD5 해시로 변경 안 된 청크 재임베딩 방지
5. 파일 타입별 프로세서 분리 — TextToEntries 베이스 → 마크다운/PDF/이미지 상속

**LinkDive가 Khoj보다 나은 점:**
1. 데이터 소유권 — 마크다운 파일 = 내 것 vs PostgreSQL에 갇힘
2. 인프라 경량성 — iOS 앱(서버 없음) + NanoClaw 1프로세스 vs Docker 4컨테이너
3. AI 비용 — Max 구독 월정액 vs API 종량제
4. 분류 체계 — PARA + AI 자동 분류 vs 없음
5. 모바일 캡처 — iOS 공유시트(네이티브) vs PWA
6. Obsidian 네이티브 — 같은 디렉토리가 vault

**Khoj가 LinkDive보다 나은 점:**
1. 검색 품질 — 3단계 파이프라인 vs grep (QMD로 Phase 1d에서 개선 예정. QMD도 쿼리 확장+리랭킹 3단계)
2. 멀티 LLM — 어떤 모델이든 vs Claude 전용
3. 즉시 사용 가능한 웹 UI — 풀스택 웹앱 vs iOS 앱 개발 필요
4. 다양한 캡처 채널 — 브라우저 확장, Emacs 등
5. 코드 실행 — Terrarium 샌드박스

### 5-10. Vox (Reddit DIY 사례 — 교훈 참고)

> 출처: Reddit r/ClaudeAI "I built a persistent AI assistant with Claude Code + Obsidian + QMD" (2026-03)

Claude Code + Obsidian + QMD로 만든 개인 persistent AI 비서. **LinkDive와 다른 문제를 풂** — 비교 대상이 아니라 교훈 대상.

| | Vox | LinkDive (방향 F) |
|---|---|---|
| 정체 | 개인 DIY 인지 보조체 | 배포 가능한 제품 |
| 타겟 | Claude Code 쓸 줄 아는 파워 개발자 1명 | 폰으로 링크 저장하고 싶은 일반 유저 |
| 캡처 | 터미널 타이핑 or 폴더에 파일 드롭 | iOS 공유시트 + 텔레그램 |
| 모바일 | 없음 | iOS 네이티브 앱 (핵심) |
| 배포 | 불가능 (본인만 쓸 수 있는 bespoke 시스템) | App Store + NanoClaw 스킬 PR |
| 외부 콘텐츠 처리 | 없음 (대화 내용만) | URL 크롤링 → 요약 → 태그 → 분류 파이프라인 |
| 분류 | 메모리 유형별 (episodic/semantic/procedural) | PARA + AI 자동 분류 |
| 멀티유저 | 불가능 | GitHub repo 분리로 가능 |
| 메모리 모델 | **5단 인지 모델** (working/episodic/semantic/procedural/identity) | CLAUDE.md (비정형) → v7에서 5단 구조 채택 |
| IoT/환경 인식 | Govee 조명, Google Calendar | 없음 (로드맵 외) |

**Vox가 LinkDive를 무의미하게 만드는가?** 아니요. Vox는 재현 불가능한 개인 해킹이고 LinkDive는 배포 가능한 제품. 타겟 유저, 캡처 채널, 분류 체계, 배포 모델이 전혀 다름.

**위험 신호**: "AI + 마크다운 + Obsidian" 아키텍처가 commodity화 중. DIY 접근이 폭발적으로 늘고 있음. Khoj(33k+ 스타)처럼 이미 동작하는 유사 제품도 존재. → **LinkDive의 진짜 차별점은 iOS 앱 + 구조화된 캡처 파이프라인 + 배포 가능성 + PARA 자동 분류**. Khoj 대비: 데이터 소유권(마크다운 vs DB), 인프라 경량성(서버 없음 vs Docker 4컨테이너), PARA 분류 체계(있음 vs 없음). 단, Khoj는 이미 동작하는 풀스택 제품이라는 점에서 실행 속도가 관건.

**가져온 교훈** (v7 결정에 반영):

| 교훈 | Vox 방식 | LinkDive 적용 | 우선순위 |
|------|---------|-------------|---------|
| 세션 다이제스트 | 매 세션 종료 시 daily note에 구조화 요약 기록 | NanoClaw 처리 배치 완료 후 `digests/YYYY-MM-DD.md`에 기록 | 높음 |
| 구조화된 CLAUDE.md | Identity/Procedural/Semantic/Episodic/Working 5단 계층 | vault 그룹 CLAUDE.md에 동일 구조 적용 | 높음 |
| 크래시 버퍼 | 진행 중 추론을 temp 파일에 기록, 완료 시 삭제 | 처리 시작 시 `.processing_buffer` → 완료 시 삭제 | 중간 |
| 비동기 지시 폴더 | 마크다운 파일 드롭 → 에이전트가 폴링 | `_instructions/` 폴더 → 처리 후 `_instructions/processed/`로 이동 | 중간 |
| 시작 컨텍스트 합성 | startup ritual — 최근 기억 로드 후 페르소나 재확립 | 처리 전 최근 다이제스트 읽기 (경량판) | 중간 |
| Reflection 큐 | 에이전트가 불확실한 항목을 큐에 기록 | `_reflection.md` → iOS 앱 "확인 필요" 섹션에 표시 | 낮음 |

### 5-11. 종합 비교

| | AI4PKM | NanoClaw | OpenClaw | Symphony | Khoj | LinkDive (방향 F) |
|---|---|---|---|---|---|---|
| 외부 캡처 | X (수동) | O (WhatsApp 코어 + 스킬) | O (메시징) | X (이슈 트래커) | O (브라우저 확장, Obsidian, WhatsApp) | O (iOS 공유시트 + NanoClaw 텔레그램 스킬) |
| 사람 친화 UI | Obsidian only | X (메시징이 UI) | Next.js 자동생성 (미검증) | Phoenix LiveView 대시보드 | Next.js 웹앱 + PWA | iOS 네이티브 앱(캡처+관리) + Obsidian(열람) + 텔레그램(채팅) |
| Agent 접근 | Claude 직접 | 내부 | 내부 | Codex app-server | 커스텀 에이전트 (DB) | NanoClaw 내부 |
| Obsidian 호환 | 필수 | X | X | X | 플러그인 (DB 동기화) | **핵심 열람 UI** — 같은 디렉토리가 3중 역할 |
| 분류 체계 | 커스텀 | X | X | X (이슈 상태 기반) | 없음 | PARA + AI |
| 데이터 소유 | 100% 로컬 | 로컬 | 플랫폼 | 로컬 워크스페이스 | DB (export 필요) | 100% Git |
| 검색 | grep (로컬) | grep (키워드만) | memory_search (벡터) | X (코딩 전용) | bi-encoder+cross-encoder 3단계 | QMD (Phase 1d, BM25+벡터+리랭킹) + PageIndex (Phase 4) |
| 메모리 시스템 | CLAUDE.md | CLAUDE.md 3단 계층 | MEMORY.md + 벡터 | WORKFLOW.md (세션 단위) | UserMemory (pgvector) | CLAUDE.md 구조화 (5단 인지 모델) + QMD 시맨틱 |
| 설정 패턴 | 수동 | CLAUDE.md 비정형 | 플랫폼 설정 | WORKFLOW.md (YAML+프롬프트 통합) | Django admin | CLAUDE.md 구조화 (Symphony 참고) |

---

## 6. 기술적 발견 (문서 이슈 16건)

prd_v3 검수에서 발견한 이슈들. 어느 방향으로 가든 참고해야 할 사항.

### Critical (5건)

| # | 문제 | 해결 제안 | 상태 |
|---|------|-----------|------|
| 1 | GitHub API 호출량 과소평가 (prd_v3 §8-1 API 제한) | 하네스는 로컬 git clone에서 작업, GitHub API는 앱 전용. 앱 UX(스크롤, 검색, 필터)에서 호출 폭증 가능 — 캐싱 전략 필요 | 부분 해결 |
| 2 | `search_notes` 검색 방식 미정의 (prd_v3 §8-3 MCP 도구) | Phase 1d = QMD (하이브리드 검색). v7에서 QMD로 확정 | 해결 |
| 3 | `related_notes`의 O(N) 스케일링 (prd_v3 §6 노트 포맷) | Phase 1에서 제거 → `contexts` 필드로 대체 (섹션 10 참조) | 해결 |
| 4 | Phase 1 스코프 과다 (prd_v3 §10 실행 계획) | 4단계(1a/1b/1c/1d)로 분할 | 해결 |
| 5 | Git 충돌 전략 미결 (prd_v3 §6 저장소) | 단일 작성자 원칙 — status 기반 권한 분리 (섹션 4-4 참조). ⚠️ Obsidian 동시 편집은 미커버 | 부분 해결 |

### Significant (7건)

| # | 문제 | 해결 제안 | 상태 |
|---|------|-----------|------|
| 6 | "DB 없음" 원칙과 SQLite 모순 (prd_v3 §2 vs §4) | "GitHub = 진실, SQLite = 재빌드 가능한 캐시"로 재정의 | 해결 |
| 7 | Agent SDK 언어 불일치 — Python vs Node.js (prd_v3 §5 AI 처리) | TypeScript SDK로 통일 | 해결 |
| 8 | 웹 크롤링 실패 전략 부재 (prd_v3 §5 파이프라인) | fallback: fetch → og:meta → raw 저장. 캡처를 절대 실패시키지 않기 | 해결 |
| 9 | 파일 명명 규칙 미정의 (prd_v3 §6 노트 포맷) | `YYYYMMDD-HHMMSS-slug.md`, 한국어 음역/해시, 최대 100자 | 해결 |
| 10 | 컨테이너 격리 오버헤드 (prd_v3 §5 AI 엔진) | Phase 1 생략, 파일시스템 샌드박싱만 | 해결 |
| 11 | OAuth 정책 리스크 대응 미비 (prd_v3 §5 Agent SDK) | Phase 1에서 `AIProcessor` 인터페이스 정의 필수 | 해결 |
| 12 | 이미지/파일 처리 부재 (prd_v3 §5 파이프라인) | 이미지 → `inbox/images/` + markdown stub, AI 처리는 나중에 | 해결 |

### Minor (4건)

| # | 문제 | 해결 제안 | 상태 |
|---|------|-----------|------|
| 13 | `status: raw` 워크플로우 미설명 (prd_v3 §6 노트 포맷) | "캡처됐지만 AI 미처리 상태"로 정의 | 해결 |
| 14 | `captured_via` enum 불일치 (prd_v3 §6 노트 포맷) | `telegram | cli | mcp | app | share-extension | browser-extension` (prd_v3의 `claude-code` → `mcp`로 변경, `app` 추가) | 해결 |
| 15 | 성공 지표 측정 수단 부재 (prd_v3 §10 실행 계획) | SQLite에 경량 로그 추가 | 해결 |
| 16 | 파일명/로깅/AIProcessor 섹션 자체가 부재 | 신규 섹션 3개 추가 필요 | 미해결 |

---

## 7. 확정된 아키텍처 결정

### 7-0. 현재 유효한 결정 요약 (방향 F 기준)

> 아래 7-1~7-5의 변천 과정에서 최종적으로 유효한 결정만 추린 것.

| 영역 | 결정 | 비고 |
|------|------|------|
| 제품 형태 | iOS 네이티브 앱 (Swift) | 캡처(공유시트) + vault 관리. 채팅 없음 |
| AI 엔진 | NanoClaw (그대로 사용) + second brain 스킬 | 텔레그램 채팅은 `add-telegram` 스킬 적용 필요 |
| 저장소 | GitHub private repo (markdown) | 파일 primary, SQLite = 재빌드 가능한 캐시 |
| 포맷 | Markdown + YAML frontmatter | `contexts`(M:N 소속) + `tags`(속성) 분리 |
| 분류 | PARA + AI 자동 분류 | 자동분류 threshold 설정 가능 |
| 검색 | Phase 1a=grep, 1b=GitHub Search API, 1d=QMD | QMD persistent 서버 모드 |
| 인증 (MVP) | GitHub Device Flow | 서버 없음 |
| 동시 쓰기 | status 기반 단일 작성자 | Obsidian은 `approved` 노트만 편집 권장 |
| AI 비용 | Max 구독 월정액 (추가 종량제 0원) | `AIProcessor` 인터페이스로 교체 가능 설계 |
| CLAUDE.md | 5단 인지 모델 (Vox 패턴) | Identity/Procedural/Semantic/Episodic/Working |
| 오프라인 | MVP 미지원 | 앱=GitHub API 직접 호출. 오프라인 캐싱은 Phase 2 검토 |

### 7-1. 이전부터 확정

| 결정 | 선택 | 이유 |
|------|------|------|
| 저장소 | GitHub private repo (markdown) | 무료, 버전관리, Obsidian 호환, 데이터 소유 |
| 포맷 | Markdown + YAML frontmatter | 사람/Agent 모두 파싱 가능 |
| 분류 체계 | PARA | Projects, Areas, Resources, Archive |
| PARA Projects 정의 | 프로젝트 "관련 자료" 모음 (프로젝트 관리 도구가 아님) | LinkDive는 정보 캡처/정리 도구. 프로젝트 관리는 별도 도구 |
| DB 전략 | 파일 primary, SQLite = 재빌드 가능한 캐시 | 현실과 원칙의 일관성 |
| 동시 쓰기 | 단일 작성자 원칙 (status별 권한 분리) | Git 충돌 방지 |
| 파일명 | `YYYYMMDD-HHMMSS-slug.md` | 정렬 + 중복 방지 |
| AI 추상화 | `AIProcessor` 인터페이스 | 정책 변경 대비 |
| ~~Phase 1 검색~~ | ~~로컬 grep~~ | ~~현실적. Phase 4에서 시맨틱으로 업그레이드~~ → 7-3에서 MemSearch → 7-5에서 QMD로 변경 |
| 컨테이너 격리 | Phase 1 생략 | 개인 로컬 사용에 과도 |

### 7-2. v4 토론에서 추가 확정

| 결정 | 선택 | 이유 |
|------|------|------|
| 하네스 저장소 접근 | 로컬 git clone (git pull 폴링) | API 아닌 git으로 직접 |
| AI 엔진 | Claude Code CLI (subprocess) | Max 구독 활용, API 비용 0원. NanoClaw도 동일 방식 |

### 7-3. v5 토론에서 추가 확정 / 수정

| 결정 | 선택 | 이유 |
|------|------|------|
| 에이전트 플랫폼 | NanoClaw 그대로 사용 | 하네스, 큐, 스케줄러, 채팅, 격리 모두 재활용. 직접 만들 필요 없음 |
| 캡처/채팅 채널 | 텔레그램 (`add-telegram` 스킬 적용) | NanoClaw 코어는 WhatsApp만. 텔레그램은 스킬로 추가. 채팅이 캡처+분류+검색+질의 다 커버 |
| LinkDive 스킬 | NanoClaw 공식 repo에 PR | `/setup-second-brain` 스킬로 컨트리뷰션. 오픈소스 |
| Dashboard | GitHub Pages 웹앱 (Phase 2) | GitHub API로 vault CRUD. 시각적 관리가 필요해질 때 개발 |
| ~~GitHub Pages~~ | ~~사용 안 함~~ → **Dashboard 호스팅에 사용** | v4에서 "읽기 전용이라 불가"로 판단했으나 오류. Pages는 호스팅만 읽기전용이고, JS 앱은 GitHub API로 vault repo에 CRUD 가능 |
| ~~네이티브 앱~~ | ~~필수~~ → **Phase 1 불필요** | iOS Share Extension은 나중에. 텔레그램 캡처로 Phase 1 충분 |
| ~~하네스 직접 구현~~ | ~~NanoClaw 베이스~~ → **NanoClaw 그대로** | 코드 분석 결과 커스텀 하네스 불필요. 스킬 추가만으로 충분 |
| Obsidian | 핵심 열람 UI — vault 직접 열기, 그래프 뷰, obsidian-qmd 플러그인. Dashboard 대안/보완 | 같은 마크다운 디렉토리가 NanoClaw 메모리 + QMD 인덱스 + Obsidian vault 3중 역할 |
| ~~검색 (Phase 1)~~ | ~~MemSearch (시맨틱 검색)~~ → **QMD** | Node.js 스택 일치, 쿼리 확장+리랭킹으로 검색 품질 우위, MCP 퍼스트클래스 |
| 마크다운 디렉토리 3중 역할 | `groups/{name}/` 하나의 디렉토리가 NanoClaw 메모리, QMD 인덱스, Obsidian vault | 별도 sync 없이 자연스러운 통합 |

### 7-4. v6 토론에서 추가 확정 / 수정

| 결정 | 선택 | 이유 |
|------|------|------|
| 제품 형태 | **iOS 네이티브 앱 (Swift)** | 공유시트 캡처 필수. 채팅은 텔레그램에 남김 |
| 앱 역할 | 캡처 + 시각적 vault 관리. **채팅 없음** | 채팅은 NanoClaw 텔레그램이 커버 (`add-telegram` 스킬 적용 후) |
| NanoClaw 역할 | AI 처리 + 채팅 + 스케줄. **앱과 직접 통신 없음** | GitHub repo만 공유 상태 |
| 인증 (MVP) | **GitHub Device Flow** | 서버 없이 동작. UX 투박하지만 검증용 충분 |
| 인증 (이후) | **OAuth + Cloudflare Worker** | 서버리스 함수 1개로 UX 개선 |
| 서버 | **없음 (MVP)** | 앱이 GitHub API 직접 호출. 서버 비용 0원 |
| 캡처 우선순위 | 링크 > 텍스트 메모 > 파일(후순위) | 파일은 MVP에서 제외 가능 |
| Write Path | **status 기반 단일 작성자** | raw→NanoClaw만, pending_review 이후→앱/사용자만 (섹션 4-4) |
| ~~Dashboard~~ | ~~GitHub Pages 웹앱 (Phase 2)~~ → **iOS 앱으로 통합** | 별도 웹 대시보드 불필요. 앱이 대시보드 역할 |
| ~~네이티브 앱 Phase 1 불필요~~ | ~~텔레그램으로 충분~~ → **iOS 앱이 Phase 1 핵심** | 앱이 제품의 중심. 텔레그램은 채팅/간편캡처 보조 |
| 가장 유사한 기존 제품 | **Khoj** (33k+ 스타) | LLM API 방식의 풀스택 서버 앱. LinkDive는 Agent SDK + 네이티브 앱 + PARA 자동 분류로 차별화. 단 Khoj는 이미 동작하는 제품 — 실행 속도가 관건 |

### 7-5. v7 리서치에서 추가 확정 / 수정

> 출처: Reddit "Vox" 사례 분석 + QMD 코드베이스 분석 (2026-03-07)

| 결정 | 선택 | 이유 |
|------|------|------|
| ~~검색 (Phase 1d)~~ | ~~MemSearch~~ → **QMD** | 검색 품질(쿼리 확장+크로스인코더 리랭킹), Node.js 스택 일치(NanoClaw), MCP 퍼스트클래스(6개 도구), Obsidian 플러그인 |
| CLAUDE.md 구조 | **5단 인지 모델** (Vox 패턴 참고) | Identity/Procedural/Semantic/Episodic/Working 섹션 분리. 에이전트 행동 일관성 향상 |
| 세션 다이제스트 | **처리 후 `digests/YYYY-MM-DD.md`에 요약 기록** | NanoClaw 처리 배치 완료 시 자동. 에이전트 세션 간 연속성 확보 |
| 크래시 버퍼 | **처리 시작 시 temp 파일 → 완료 시 삭제** | 진행 중 AI 추론 보호. SQLite 큐는 데이터만 보호, 추론은 보호 못함 |
| 비동기 지시 폴더 | **`_instructions/` 폴더** | 파워유저가 복잡한 지시를 마크다운 파일로 드롭. 텔레그램 없이도 에이전트에 지시 가능 |
| 시작 컨텍스트 | **처리 전 최근 다이제스트 읽기** | Vox의 startup ritual 경량판. 어제 컨텍스트 없이 오늘 처리하지 않음 |
| 다대다 관계 | **frontmatter `contexts` 필드** | PARA 폴더는 1:1(물리적 위치), contexts로 M:N 논리적 연결. 태그와 역할 분리 (contexts=소속, tags=속성) |
| contexts vs tags | **분리 유지** | contexts = PARA 경로 (구조적 소속, e.g. `projects/app-redesign`). tags = 자유 키워드 (주제/속성, e.g. `ux`, `react`) |
| contexts UI 표시 | **실제 위치와 연결된 위치 구분 표시** | 앱/Obsidian에서 contexts로 모아볼 때, 실제 파일 위치가 아닌 노트는 경로를 작게 표시하여 혼란 방지 |
| SQLite 다대다 인덱싱 | **`note_contexts`, `note_tags` junction 테이블** | frontmatter에서 파생. SQLite 삭제 후 rebuild로 100% 복구 가능 |

---

## 8. 방향 선택 과정

### 탐색한 방향들 (A/B/C)

| 방향 | 내용 | 평가 |
|------|------|------|
| A: 앱 | 웹/모바일 앱 → GitHub repo | 앱이 필요하지만 단독으로는 에이전트 없음 |
| B: 에이전트/하네스 | 텔레그램/CLI → 하네스 → GitHub repo | 에이전트는 필요하지만 UI가 없음 |
| C: MCP 서버 | Claude Code → MCP → 로컬 git | 최소지만 인박스/열람/모바일 안 됨 |

### 왜 A/B/C 단독으로 안 되는가 (v4 토론 결과)

토론 과정에서 자연스럽게 드러난 요구사항:
1. "인박스 구현 가능?" → 시각적 UI 필요 (B/C 탈락)
2. "인박스에서 수정도?" → 읽기+쓰기 UI 필요 (GitHub Pages 탈락)
3. "리소스 조회는?" → 하나의 앱에서 다 해야 함 (Vercel+GitHub Pages 분리 구조 탈락)
4. "공유 기능으로 캡처" → iOS Share Extension 필요 → 네이티브 앱 필수 (웹 앱 탈락)
5. "서버 필요 없잖아?" → GitHub OAuth 직접 통신 (별도 백엔드 탈락)
6. "AI API 비용?" → Claude Code CLI subprocess (API 키 종량제 탈락)
7. "범용 에이전트 + UI?" → NanoClaw 베이스 + 네이티브 앱 (방향 D 탄생)

### 방향 D: NanoClaw 베이스 + 네이티브 앱 (폐기)

v5에서 폐기. 이유:
1. NanoClaw 코드 분석 결과, 채널 인터페이스가 깔끔하게 분리되어 있어 **텔레그램을 굳이 교체할 필요 없음**
2. 캡처/분류/검색/질의 모두 채팅으로 가능 — 네이티브 앱은 Phase 1에서 과도
3. 대시보드(시각적 관리)만 별도로 만들면 됨 — 네이티브가 아닌 웹앱으로 충분

### 방향 E: NanoClaw 스킬 + Dashboard (방향 F로 진화)

> 아키텍처 다이어그램은 **섹션 4-1 "방향 E"** 참조.

**두 가지 산출물:**
1. **`/setup-second-brain` 스킬** — NanoClaw 공식 repo에 PR (오픈소스)
2. **Dashboard 웹앱** — LinkDive 고유 제품 (별도 repo)

**전략:**
- 스킬 = 유저 유입 채널 (NanoClaw 생태계에서 발견)
- Dashboard = 차별점 (채팅만으로 부족해질 때의 시각적 관리 도구)

### 방향 F: iOS 앱 + NanoClaw 스킬 (수렴)

방향 E에서 Dashboard를 Phase 2로 미뤘으나, 재검토 결과:
1. **원래 만들려던 건 앱이었음** (v4 토론에서도 같은 결론)
2. 텔레그램 채팅만으로는 "시각적 관리"가 부족
3. iOS 공유시트가 캡처 프릭션을 0에 가깝게 만듦
4. Dashboard(웹앱)보다 네이티브 앱이 공유시트 + 오프라인에서 우위

→ **앱을 처음부터 제품의 중심으로**, 채팅은 텔레그램에 남김

핵심 차이 vs 방향 D(폐기):
- 방향 D: 네이티브 앱이 NanoClaw의 텔레그램을 "교체"
- 방향 F: 네이티브 앱과 텔레그램이 "공존". 앱=캡처+관리, 텔레그램=채팅+간편캡처

핵심 차이 vs 방향 E:
- 방향 E: Dashboard는 Phase 2, 텔레그램만으로 Phase 1 충분
- 방향 F: iOS 앱이 Phase 1 핵심 제품. 텔레그램은 채팅 보조

두 가지 산출물:
1. **LinkDive iOS 앱** — 고유 제품 (캡처 + vault 관리 + 검색)
2. **`/setup-second-brain` 스킬** — NanoClaw 컨트리뷰션 (오픈소스)

### Remote Control vs NanoClaw 비교

NanoClaw와 유사한 접근인 "Remote Control" 패턴과의 비교. Reddit에서 논의된 DIY 접근법도 포함.

| | NanoClaw | Remote Control (DIY) |
|---|---|---|
| 구조 | 전용 하네스 + 채널 + 스케줄러 + 컨테이너 격리 | `claude -p` + telegram bot + cron |
| 24/7 구동 | launchd 서비스로 상시 동작 | cron/systemd로 주기적 실행 |
| 채팅 UI | WhatsApp/Telegram 네이티브 통합 | Telegram bot API 직접 구현 |
| 능동성 | 스케줄 태스크로 자발적 행동 가능 | cron 기반 주기적 실행만 |
| 격리/보안 | 컨테이너 샌드박스 + mount allowlist | 없음 (호스트에서 직접 실행) |
| 메모리 | CLAUDE.md 3단 계층 + 세션 재개 | 파일 기반 수동 관리 |
| 복잡도 | 높음 (Node.js 프로젝트, Docker/Apple Container) | 낮음 (셸 스크립트 수준) |

**Reddit DIY 접근법 요약**: `claude -p "프롬프트"` + Telegram Bot API + cron으로 최소한의 AI 에이전트 구성 가능. 하지만 세션 지속성, 격리, 스케줄링, 다중 그룹 지원 등을 직접 구현해야 함.

**결론**: NanoClaw 필요성 유지. LinkDive의 vault 그룹, 스케줄 처리, 보안 격리 요구사항을 DIY로 충족하려면 결국 NanoClaw급 하네스를 만들게 됨. 단, **극도로 단순한 MVP** (링크 캡처만)를 먼저 테스트하고 싶다면 DIY 경량 접근도 옵션으로 기록.

### 미결정 사항

- `/setup-second-brain` 스킬의 상세 설계 (vault 구조, CLAUDE.md 5단 구조 내용, 스케줄 태스크)
- iOS 앱 세부 UI/UX 설계
- QMD 결과를 앱에서 활용하는 방식 (Phase 2) — NanoClaw가 검색 → repo에 캐시 or 앱이 직접 QMD MCP 호출
- QMD persistent 서버 모드 운영 방식 — NanoClaw와 별도 프로세스 vs NanoClaw 내부 통합
- contexts vs tags 구분을 일반 사용자에게 어떻게 노출할지 (UI/UX 검증 필요)
- Phase 1a/1b 병렬 개발 시 우선순위 — Swift(iOS) vs Node.js(NanoClaw 스킬) 중 어느 것을 먼저?
- 오프라인 캐싱 전략 — Phase 2에서 로컬 캐시 도입 시 동기화 충돌 처리 방식
- GitHub repo 크기 관리 — "캡처 = 아카이빙(원본 전체 저장)" 원칙과 GitHub 권장 1GB 한계의 충돌. LFS 도입 시점, 또는 원본 축약 정책
- 최소 시스템 요구사항 — QMD ~2GB 모델 + NanoClaw 컨테이너 + Claude Agent SDK 실행에 필요한 RAM/디스크/OS 버전

### 리스크 분석

| 리스크 | 영향 | 대응 |
|--------|------|------|
| **NanoClaw 의존성** — PR 거절, 프로젝트 방향 변경, 메인테이너 갈등 | 높음 | 스킬은 fork에서도 동작. 최악의 경우 fork 유지. 스킬 자체는 CLAUDE.md + 스케줄 정의라 플랫폼 교체 시 이식 가능 |
| **Claude Max 정책 변경** — Agent SDK 사용 제한 강화 | 높음 | `AIProcessor` 인터페이스로 추상화 완료. Claude API(종량제), OpenAI, 로컬 LLM 대안 존재 |
| **GitHub repo 크기 폭발** — 원본 전체 저장 시 1GB 초과 | 중간 | 모니터링 후 LFS 도입 또는 원본 축약 정책(요약만 저장, 원본 URL 보존) 전환 |
| **오프라인 무용** — 인터넷 없으면 앱 기능 불가 | 중간 | Phase 2에서 로컬 캐싱(CoreData 또는 SQLite) 도입. MVP는 온라인 전용 명시 |
| **Khoj/DIY 대안의 commodity화** — 유사 접근이 폭발적 증가 | 중간 | 실행 속도가 관건. iOS 앱 + PARA 자동 분류가 차별점. 빨리 출시 |
| **1인 2스택 개발** — Swift + Node.js 병렬 개발 부담 | 낮음 | Phase 1a(NanoClaw 스킬)를 먼저 완료 → 1b(iOS 앱) 순차 진행도 옵션 |

### 공유/배포 시 사용자가 준비할 것

```
당신이 배포: /setup-second-brain 스킬 (NanoClaw PR), LinkDive iOS 앱 (TestFlight → App Store)
사용자 준비: NanoClaw 설치, 본인 GitHub private repo, 본인 Claude Max 구독, iOS 기기
```

각자 자기 repo, 자기 AI 구독, 자기 데이터. 서버 비용 0원, 추가 API 비용 0원.
단, **Claude Max 구독 필수** (월 $100+)가 진입장벽. `AIProcessor` 인터페이스 있으면 나중에 OpenAI/Gemini/로컬 LLM 교체 가능.

**최소 시스템 요구사항 (추정):**
- macOS (Apple Silicon 권장 — NanoClaw 컨테이너 + QMD GGUF 모델 실행)
- RAM 16GB+ (QMD 모델 ~2GB + NanoClaw + Claude Agent SDK)
- 디스크 여유 5GB+ (QMD 모델 ~2GB + vault + 인덱스)
- 상시 인터넷 연결 (GitHub API, Claude API)

---

## 9. Phase 실행 계획 (방향 F 기준)

### 이전 계획들 (폐기)

| 버전 | 계획 | 폐기 이유 |
|------|------|----------|
| v3 | MCP → AI → 텔레그램 → CLI | 앱이 먼저라는 판단으로 폐기 |
| v4 | 네이티브 앱 → 하네스 → MCP | NanoClaw 분석 후 하네스/앱 직접 구현 불필요로 폐기 |
| v5 | NanoClaw 셋업 → 스킬 → Dashboard(Phase 2) | iOS 앱이 제품 중심으로 올라오면서 폐기 |

### 현재 계획 (v6)

| Phase | 내용 | 목표 | 검증 가설 |
|-------|------|------|------------|
| **1a** NanoClaw 셋업 + 개인 사용 | `/setup` + `/add-telegram` + vault 그룹 | 텔레그램으로 링크 캡처 → AI 처리 → 개인 사용 검증 | H1 (제로 프릭션) |
| **1b** iOS 앱 MVP | GitHub Device Flow 로그인, 공유시트 캡처(URL→raw stub), 인박스 목록, pending_review 승인 | 앱으로 캡처 → NanoClaw 처리 → 앱에서 확인 | H1 + H2 |
| **1c** `/setup-second-brain` 스킬 PR | PARA 분류, AI 요약/태그, vault CLAUDE.md, 스케줄 태스크, NanoClaw 공식 repo에 컨트리뷰션 | 다른 NanoClaw 유저도 사용 가능 | - |
| **1d** QMD 통합 | NanoClaw에 QMD 연결 (persistent HTTP 서버 모드), 하이브리드 시맨틱 검색 | 텔레그램 채팅으로 시맨틱 검색 | - |
| **2** 앱 고도화 | OAuth(CF Worker), 태그/PARA 편집, 검색 UI, 텍스트 메모 캡처 | 풀스펙 vault 관리 앱 | H3 (듀얼 접근) |
| **3** 토픽 관리 + Obsidian 심화 | 토픽 그루핑, Obsidian 그래프 뷰/백링크, Smart Connections | 노트 간 연결 발견 | - |
| **4** PageIndex + 파일 캡처 | PDF/긴 문서 추론 검색, 이미지 캡처(Vision), 파일 업로드 | 멀티모달 + 긴 문서 | - |

Phase 1a에서 개인 검증, 1b에서 앱 MVP, 1c에서 오픈소스 컨트리뷰션.
앱과 NanoClaw가 독립적이므로 1a↔1b 병렬 개발 가능하나, 1인 개발 시 1a 완료 → 1b 순차 진행이 현실적.

**전제 조건**: Phase 1a 시작 전 NanoClaw에 `add-telegram` 스킬 적용 필요 (코어에 WhatsApp만 구현, 텔레그램 미구현).

**가설 검증 순서 변경 이유**: 원래 "H3(사람+Agent 듀얼 접근) → H2(AI 분류) → H1(제로 프릭션)"이 가장 빠르다고 판단했으나, v5에서 NanoClaw 분석 후 **H1(캡처 습관)이 제품의 핵심 가치**이고 H3(듀얼 접근)은 NanoClaw+Obsidian으로 이미 부분 달성된다고 판단하여 순서 변경.

---

## 10. 탐색한 세부 설계

> 아래 내용은 prd_v3에서 탐색한 설계안. 확정이 아니라 참고용.

### 노트 포맷

```yaml
---
title: "UX 리서치 방법론 가이드"
url: "https://example.com/ux-research"
source_type: web                        # web | youtube | text | image | file
tags: [ux, research, methodology]
contexts:                               # 다대다(M:N) 논리적 소속 — 이 노트가 관련된 모든 PARA 경로
  - projects/app-redesign               #   물리적으로는 한 폴더에만 존재하지만
  - areas/ux-design                     #   논리적으로는 여러 곳에 속함
  - resources/research-methods          #   ← 파일 경로와 일치하는 것이 실제 물리적 위치
ai_summary: "..."
ai_suggested_category: "resources/ux"
status: pending_review                  # raw | pending_review | approved | auto_classified
captured_via: telegram                  # telegram | cli | mcp | app | share-extension | browser-extension
created: 2026-02-28T14:30:00+09:00
processed: 2026-02-28T14:30:05+09:00
---
```

- `raw`: 캡처됐지만 AI 미처리 (컴퓨터 꺼짐, 크롤링 실패 등)
- `related_notes`: Phase 1에서 제거 (O(N) 문제) → `contexts` 필드로 대체
- `contexts` vs `tags`: contexts는 PARA 경로(구조적 소속), tags는 자유 키워드(주제/속성). 역할이 다름
- 물리적 위치 판별: contexts 중 파일 경로와 일치하는 항목이 실제 위치. AI가 "가장 중요한 맥락"을 골라 물리적 배치

### 볼트 구조

```
linkdive-vault/
  inbox/                     ← 미분류
  projects/                  ← 마감 있는 것
  areas/                     ← 지속적 책임
  resources/                 ← 관심 주제
  archive/                   ← 완료/비활성
  .linkdive/
    config.yaml
    templates/
```

### 다대다(M:N) 관계 설계

**문제**: PARA 폴더 구조는 1:1 — 파일은 물리적으로 한 폴더에만 존재. 세컨드 브레인은 하나의 노트가 여러 맥락에 속하는 다대다 관계가 필요.

**해결**: 물리적 배치(폴더) + 논리적 연결(contexts) + 검색(QMD) 3층 구조

```
물리적 구조:  PARA 폴더로 분산 (AI가 "가장 중요한 맥락"에 배치)
논리적 연결:  frontmatter contexts 필드로 다대다
검색:        QMD가 vault 전체를 하나로 인덱싱 (폴더 구조 무관)
```

**contexts vs tags 역할 분리:**

> ⚠️ 이 구분을 일반 사용자가 직관적으로 이해할 수 있는지 검증 필요. MVP에서 사용자 반응 확인 후 단순화 여부 결정.

| | contexts | tags |
|---|---|---|
| 의미 | **소속** — 어디에 연결되는가 | **속성** — 무엇에 대한 것인가 |
| 값 형태 | PARA 경로 (`projects/app-redesign`) | 자유 키워드 (`ux`, `react`, `2026-Q1`) |
| 쿼리 예시 | "app-redesign 프로젝트 관련 노트 전부" | "react 태그 붙은 노트 전부" |
| PARA 관계 | PARA 경로 그 자체 | PARA와 무관 |

**SQLite 인덱싱 (파생 캐시):**

contexts와 tags를 junction 테이블로 인덱싱하여 빠른 M:N 쿼리 지원.

```
note_contexts 테이블              note_tags 테이블
┌─────────┬──────────────────┐   ┌─────────┬─────────┐
│ note_id │ context          │   │ note_id │ tag     │
│ 1       │ projects/app     │   │ 1       │ ux      │
│ 1       │ areas/ux-design  │   │ 1       │ react   │
│ 1       │ resources/methods│   │ 2       │ ux      │
│ 2       │ projects/app     │   └─────────┴─────────┘
└─────────┴──────────────────┘
```

핵심 테스트: SQLite 삭제 → `rebuild-index` 실행 → frontmatter에서 100% 복구되는가? Yes면 올바른 구조.

**UI 표시 — 실제 위치 혼란 방지:**

앱/Obsidian에서 contexts로 노트를 모아볼 때, 해당 폴더에 실제 저장된 파일과 contexts로만 연결된 파일을 구분 표시:

```
📂 projects/app-redesign
  ├─ 앱 와이어프레임 초안              ← 여기 실제 저장됨
  ├─ 스프린트 2 회고                   ← 여기 실제 저장됨
  ├─ UX 리서치 방법론 가이드           ← 📍 resources/research-methods/
  └─ React 컴포넌트 패턴              ← 📍 resources/react/
```

실제 위치 판별 방법: contexts 중 파일 경로와 일치하는 항목이 물리적 위치. 앱이 자동 구분 가능.

**QMD/PageIndex와의 관계:**

폴더 구조와 무관하게 동작. vault 루트 디렉터리를 지정하면 하위 폴더 전부 재귀 인덱싱. PARA 폴더로 나눠도 검색에 영향 없음.

### MCP 서버 도구

> ⚠️ prd_v3 원안 기반. 방향 F에서 검색은 QMD로 변경됨.

```
add_note(url_or_text, tags?)        → inbox/에 markdown 생성
get_note(path)                      → 파일 읽기
list_inbox(limit?)                  → 미분류 노트 목록
list_notes(category?, tags?)        → 폴더/태그별 목록
classify_note(path, to_category)    → git mv로 폴더 이동
search_notes(query)                 → Phase 1a: 로컬 grep → Phase 1d: QMD 하이브리드 검색
```

### 캡처 파이프라인 & 멱등성 설계

**입력 3종 → 전부 마크다운 변환**

```
입력 채널                     처리                        저장
─────────────────────────────────────────────────────────────────
링크 (URL)        →  크롤링 → 마크다운 변환    →  inbox/YYYYMMDD-HHMMSS-slug.md
텍스트 (메모)      →  그대로 마크다운           →  inbox/YYYYMMDD-HHMMSS-slug.md
파일 (PDF/이미지)  →  텍스트 추출 + 원본 보관   →  inbox/YYYYMMDD-HHMMSS-slug.md
                                                   + files/원본파일
```

**캡처 = 아카이빙**: 원본 전체를 저장하고, 요약은 상단에 붙인다.

> ⚠️ **GitHub repo 크기 주의**: GitHub 권장 1GB, 최대 5GB. 웹페이지 전문 저장 시 노트 1개 = 수 KB~수십 KB. 1,000개 노트 ≈ 수~수십 MB로 텍스트만이면 당분간 안전. 단, PDF/이미지 파일 포함 시 급격히 증가 → `files/` 폴더를 Git LFS로 전환하거나 원본 URL만 보존하는 정책 검토 필요.

```markdown
---
title: "UX 리서치 방법론 가이드"
url: "https://example.com/ux-research"
content_hash: "sha256:a1b2c3..."
---

## 요약
(에이전트가 생성한 짧은 요약)

## 원본 내용
(크롤링한 전체 텍스트를 마크다운으로 변환)
```

**파일 처리:**

| 파일 유형 | 변환 방법 | 원본 보관 |
|----------|----------|----------|
| PDF | 텍스트 추출 (pdftotext 등) | `files/` 폴더에 원본 보관 |
| 이미지 | Vision API / OCR → 설명 텍스트 | `files/` 폴더에 원본 보관 |
| 문서 (docx 등) | 마크다운 변환 (pandoc 등) | `files/` 폴더에 원본 보관 |

**멱등성 설계: URL 정규화 + SHA-256 해시**

```
캡처 요청 → URL 정규화 (쿼리 파라미터 정리, 트레일링 슬래시 통일)
    ↓
콘텐츠 크롤링 → SHA-256 해시 생성
    ↓
기존 노트 검색 (URL 매칭 또는 파일 해시 매칭)
    ↓
┌─ 새 URL + 새 해시      → 새 노트 생성
├─ 같은 URL + 같은 해시  → 스킵 (이미 존재)
└─ 같은 URL + 다른 해시  → 업데이트 (내용 변경됨, 버전 기록)
```

| 시나리오 | 처리 |
|---------|------|
| 새 캡처 | 노트 생성, frontmatter에 `content_hash` 기록 |
| 같은 URL, 같은 내용 | 스킵. "이미 저장됨" 알림 |
| 같은 URL, 내용 변경 | 기존 노트 업데이트, git diff로 변경 이력 자동 추적 |
| 텍스트/파일 | SHA-256 해시로 동일 콘텐츠 중복 방지 |

### AI 처리 파이프라인

```
[raw 입력] URL, 텍스트, 또는 파일
     ↓
[1단계] 콘텐츠 추출 (fallback: fetch → og:meta → raw 저장)
     ↓
[1.5단계] 멱등성 체크 (URL+해시로 중복 판단)
     ↓
[2단계] AI 분석 (요약 + 태그 + 분류 추천)
     ↓
[3단계] Markdown 생성 → inbox/에 저장 (요약 + 원본 전체)
     ↓
[4단계] Git commit & push
     ↓
[5단계] QMD 자동 인덱싱 (persistent 서버 모드)
```

### 자동 분류 모드

```yaml
# .linkdive/config.yaml
classification:
  mode: manual          # manual | auto | hybrid
  auto_threshold: 0.8   # hybrid에서 자동 분류 신뢰도 임계값
```

### OAuth 정책

| 용도 | 허용 여부 | 인증 방식 |
|------|----------|----------|
| 개인 로컬 개발/실험 | 허용 | Max 구독 OAuth |
| 비즈니스/서비스 운영 | API 키 필요 | API 키 (종량제) |

AI 처리 레이어 추상화로 Agent SDK → Claude API → 다른 모델 교체 가능하게 설계.

---

## 11. 참고 자료

### 내부 문서

| 문서 | 설명 |
|------|------|
| [prd_v1.md](./prd_v1.md) | 초기 기획 — 링크 저장 + PARA 분류 SaaS |
| [prd_v2.md](./prd_v2.md) | 2차 기획 — 소스 기반 노트 관리 + NotebookLM 연동 |
| [prd_v3.md](./prd_v3.md) | 3차 탐색 — AI Second Brain (에이전트/하네스 방향) |
| [pivot_analysis.md](./pivot_analysis.md) | v2→v3 피봇 분석 — 시장 조사, 레퍼런스, 아키텍처 |

### 레퍼런스 프로젝트

| 프로젝트                      | GitHub                                                                                                                          | 참고 포인트                                |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| **AI4PKM**                | [jykim/AI4PKM](https://github.com/jykim/AI4PKM)                                                                                 | Obsidian + Claude Code 기반 Agentic PKM |
| AI4PKM 문서                 | [jykim.github.io/AI4PKM](https://jykim.github.io/AI4PKM/)                                                                       | 설계 철학 및 가이드                           |
| AI4PKM Vault              | [jykim/ai4pkm-vault](https://github.com/jykim/ai4pkm-vault)                                                                     | Obsidian Vault 스타터                    |
| **OpenClaw**              | [openclaw/openclaw](https://github.com/openclaw/openclaw)                                                                       | 텔레그램 기반 제로 프릭션 캡처                     |
| **NanoClaw**              | [qwibitai/nanoclaw](https://github.com/qwibitai/nanoclaw)                                                                       | 경량 범용 AI 에이전트 하네스 (20k+ 스타), 컨테이너 격리, 폴링. 코어: WhatsApp, 스킬: Telegram/Slack/Discord/Gmail |
| **OpenClaw PARA Skill**   | [halthelobster/para-second-brain](https://github.com/openclaw/skills/blob/main/skills/halthelobster/para-second-brain/SKILL.md) | PARA Agent 메모리, Decision Tree         |
| **OpenClaw Second Brain** | [awesome-openclaw-usecases](https://github.com/hesamsheikh/awesome-openclaw-usecases/blob/main/usecases/second-brain.md)        | 제로 오거나이제이션, 검색 대시보드                   |
| **Khoj**                  | [khoj-ai/khoj](https://github.com/khoj-ai/khoj)                                                                                 | 셀프호스팅 AI 세컨드 브레인 (33k+ 스타), PostgreSQL+pgvector, 3단계 검색 |
| **QMD**                   | [tobi/qmd](https://github.com/tobi/qmd)                                                                                         | 로컬 하이브리드 검색 (13k+ 스타, BM25+벡터+LLM 리랭킹+쿼리 확장). **Phase 1d 검색 백엔드** |
| QMD Obsidian 플러그인        | [achekulaev/obsidian-qmd](https://github.com/achekulaev/obsidian-qmd)                                                           | QMD 로컬 검색의 Obsidian 통합               |
| QMD Query Expansion 모델    | [HuggingFace](https://huggingface.co/tobil/qmd-query-expansion-1.7B)                                                            | 커스텀 파인튜닝 1.7B 쿼리 확장 모델             |
| ~~MemSearch~~             | [zilliztech/memsearch](https://github.com/zilliztech/memsearch)                                                                 | ~~Phase 1 검색 후보~~ → QMD로 교체. Python + Milvus Lite |
| MemSearch 블로그             | [Milvus Blog](https://milvus.io/blog/we-extracted-openclaws-memory-system-and-opensourced-it-memsearch.md)                      | 아키텍처 원문                               |
| **PageIndex**             | [VectifyAI/PageIndex](https://github.com/VectifyAI/PageIndex)                                                                   | 벡터 없는 추론 기반 RAG, PDF 트리 탐색            |
| **Smart Connections**     | [brianpetro/obsidian-smart-connections](https://github.com/brianpetro/obsidian-smart-connections)                               | Obsidian 시맨틱 연결, 2단 임베딩               |
| jsbrains                  | [brianpetro/jsbrains](https://github.com/brianpetro/jsbrains)                                                                   | Smart Connections 코어 엔진               |
| **Symphony**              | [openai/symphony](https://github.com/openai/symphony)                                                                           | 코딩 작업 관리 시스템 (8.7k 스타), WORKFLOW.md 패턴, 라이프사이클 훅 |

### 기술 스택 공식 문서

| 기술 | 링크 | 용도 |
|------|------|------|
| Claude Agent SDK (Python) | [GitHub](https://github.com/anthropics/claude-agent-sdk-python) | AI 엔진 |
| Claude Agent SDK (TypeScript) | [GitHub](https://github.com/anthropics/claude-agent-sdk-typescript) | AI 엔진 (TS) |
| Claude Agent SDK 문서 | [platform.claude.com](https://platform.claude.com/docs/en/agent-sdk/overview) | 공식 가이드 |
| Model Context Protocol (MCP) | [modelcontextprotocol.io](https://modelcontextprotocol.io) | Agent 접근 프로토콜 |
| MCP TypeScript SDK | [GitHub](https://github.com/modelcontextprotocol/typescript-sdk) | MCP 서버 구현용 |
| Obsidian Git Plugin | [GitHub](https://github.com/Vinzent03/obsidian-git) | Vault ↔ GitHub 동기화 |
| Claude Code | [GitHub](https://github.com/anthropics/claude-code) | MCP 클라이언트 |

### Anthropic 정책 관련

| 제목 | 출처 | 날짜 |
|------|------|------|
| Agent SDK 정책 혼란 정리 | [The New Stack](https://thenewstack.io/anthropic-agent-sdk-confusion/) | 2026-02 |
| 3rd-party 앱에서 구독 OAuth 금지 | [WinBuzzer](https://winbuzzer.com/2026/02/19/anthropic-bans-claude-subscription-oauth-in-third-party-apps-xcxwbn/) | 2026-02-19 |
| 3rd-party 접근 금지 명확화 | [The Register](https://www.theregister.com/2026/02/20/anthropic_clarifies_ban_third_party_claude_access/) | 2026-02-20 |
| OpenClaw OAuth 차단 분석 | [Natural 20](https://natural20.com/coverage/anthropic-banned-openclaw-oauth-claude-code-third-party) | 2026-02 |

### 하네스 생태계 리뷰

| 제목 | 출처 | 비고 |
|------|------|------|
| Everything is Agent: OpenClaw Alternatives (Part 1) | [Kevin Simback / X](https://x.com/KSimback/status/2027812237390512631) | Tiny Claws, Security-first 카테고리 |
| Remote Control / DIY 에이전트 접근법 | [Reddit r/ClaudeAI 토론](https://www.reddit.com/r/ClaudeAI/) | `claude -p` + telegram + cron DIY 패턴 |
| Vox — Persistent AI Assistant | [Reddit r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/) | Claude Code + Obsidian + QMD. 5단 인지 메모리 모델, startup ritual, 세션 다이제스트 패턴 참고 |
| QMD 토큰 절감 사례 | [Andrew Levine / X](https://x.com/andrarchy/status/2015783856087929254) | 600개 노트 vault에서 95% 토큰 절감 |
| QMD for faster Obsidian search | [rizwan.dev](https://rizwan.dev/blog/qmd-for-faster-obsidian-search/) | QMD + Obsidian 통합 가이드 |

### 프레임워크 / 방법론

| 이름 | 출처 | 설명 |
|------|------|------|
| PARA Method | [Tiago Forte](https://www.buildingasecondbrain.com/) | Projects, Areas, Resources, Archive |
| CODE Framework | [Tiago Forte](https://fortelabs.com/blog/the-4-levels-of-personal-knowledge-management/) | Capture, Organize, Distill, Express |
| Collector's Fallacy | [Christian Tietze](https://zettelkasten.de/posts/collectors-fallacy/) | "저장 = 학습" 착각 |
