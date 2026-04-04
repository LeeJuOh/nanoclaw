# References 31개 프로젝트 비교분석 — 채택 결정

> **Date**: 2026-03-28
> **Context**: CODE 재설계 스펙 (2026-03-22) 3차 검수 시 31개 참조 프로젝트 심층 분석
> **결론**: Approach C 유지. 6건 채택, 3건 Phase 로드맵 추가, 나머지는 미채택 (근거 포함)

---

## 1. 분석 요약

### 1.1 전제

- 이 프로젝트는 개인 도구이자 **제품화 가능성**이 있음
- **Obsidian 호환**이 목표이므로 Zettelkasten 링킹 지원 필수
- 좋은 아이디어는 "참고용"이 아니라 구체적으로 채택해야 함

### 1.2 결론

31개 프로젝트 중 Approach C(2분할 + Express 3분할 + Git markdown vault + PARA)를 통째로 대체할 만한 건 없음. 그러나 **6건의 구체적 채택 사항**과 **3건의 Phase 로드맵 추가**가 도출됨.

---

## 2. Tier 1 — 채택 (스펙 변경 필요)

### 2.1 `[[wikilink]]` + 원자적 노트 지원 (from arscontexta)

**현재 스펙**: frontmatter `related:` 필드로만 노트 간 연결. 본문에 링크 없음.

**문제**: Obsidian은 `[[wikilink]]`가 네이티브. PARA(폴더 분류)와 Zettelkasten(링크 그래프)은 배타적이 아니라 보완적:
- PARA = 운영 조직 (어디에 넣을지)
- Zettelkasten = 지식 그래프 (무엇과 연결되는지)

arscontexta가 이걸 정확히 보여줌: `notes/` 공간은 Zettelkasten(원자적 노트, 위키링크, MOC), `self/`+`ops/`는 PARA에 매핑.

**채택 내용**:
- 노트 본문에 `[[wikilink]]` 허용. AI가 캡처 시 관련 노트를 `[[기존노트제목]]`으로 본문에 링크
- `related:` frontmatter는 유지 (구조적 역연결 추적용). 위키링크는 서술적 연결, `related:`는 메타데이터 연결
- 원자적 노트 패턴: source_type에 `atomic` 추가. "핵심만 뽑아줘" Distill에서 긴 노트 → 원자적 클레임 분리 지원 (Phase 1b+)

**arscontexta 15가지 커널 원칙 중 채택하는 것**:
- Wiki links = 에지 생성
- Description 필드 (우리의 `ai_summary`)
- Topics footer (우리의 `tags` + `contexts`)
- Flat folder 내 unique address (PARA 경로 내에서 고유 파일명)

**채택하지 않는 것**:
- 3-space 분리 (self/notes/ops) — NanoClaw 그룹 구조와 충돌
- MOC 자동 생성 — Phase 1a 범위 초과
- 순수 Zettelkasten (PARA 없이) — 우리는 PARA 기반

**스펙 영향**: §7.1 노트 템플릿에 `[[wikilink]]` 예시 추가, §7.2 Reweave에 위키링크 생성 로직 추가

---

### 2.2 대화에서 fact 자동 추출 (from memory-bank)

**현재 스펙**: 캡처 대상이 URL과 텍스트 메모뿐. 에이전트와의 대화에서 나온 결정/선호/패턴은 캡처되지 않음.

**문제**: 사용자가 "DDD aggregate는 작게 잡아야 해"라고 대화 중 말해도 vault에 안 남음. URL 캡처만으로는 지식의 절반을 놓침.

**memory-bank 구현 분석**:
- 세션 종료 시 배치 추출 (5개 교환 단위로 LLM 호출)
- 카테고리: decision, preference, pattern, knowledge, constraint
- 스코프: project-specific vs global
- 신뢰도: 0.9+(명시적), 0.7-0.9(추론), <0.7(폐기)
- 중복 감지: 벡터 유사도 0.85 → LLM이 DUPLICATE/CONTRADICTION/EVOLUTION/INDEPENDENT 분류
- 세션당 최대 20개 fact (비용 통제)

**채택 내용**:
- para-brain에 "대화 fact 추출" 워크플로우 추가
- NanoClaw 컨테이너 세션 종료 시 에이전트가 대화에서 fact 추출 → inbox에 `source_type: conversation` 노트로 저장
- fact 카테고리는 memory-bank 것을 그대로 사용: decision, preference, pattern, knowledge, constraint
- 스코프는 그룹 단위 (NanoClaw 그룹 = memory-bank의 project)
- Phase 1b에서 추가 (Phase 1a는 URL/메모 캡처 안정화 우선)

**채택���지 않는 것**:
- 온톨로지 자동 분류 (Domain → Category) — PARA가 이 역할을 함
- Multi-hop 그래프 순회 — Phase 2+ 검색 고도화 시 검토
- 별도 fact DB (sqlite-vec) — vault markdown이 소스 of truth

**스펙 영향**: §4.3 para-brain에 워크플로우 추가, §4.4 Phase 1b 범위에 포함, §10.2 eval 추가

---

### 2.3 콘텐츠 해시 중복 감지 (from memsearch, khoj)

**현재 스펙**: URL 기반 중복 감지만 언급.

**문제**:
- 같은 콘텐츠가 다른 URL로 올 수 있음 (예: 원본 + AMP + 캐시)
- 같은 URL이지만 내용이 바뀌었을 때 재캡처를 허용해야 함

**참조 구현**:
- memsearch: SHA-256 on content → 변경 없으면 재인덱싱 스킵
- khoj: MD5 on compiled text → `hashed_value` 필드로 bulk dedup

**채택 내용**:
- para-pipeline 캡처 시 크롤링된 본문의 SHA-256 해시를 frontmatter `content_hash` 필드에 저장
- 중복 감지 순서: (1) URL 일치 → (2) content_hash 일치 → 중복 거부
- URL은 같지만 content_hash가 다르면 → 업데이트 캡처 허용 (기존 노트에 `updated` 마킹)

**스펙 영��**: §7.3 frontmatter에 `content_hash` 필드 추가, para-pipeline 캡처 플로우에 해시 체크 단계 추가

---

### 2.4 멀티포맷 경로 — PDF, 이미지 (from khoj)

**현재 스펙**: `source_type: web | memo | youtube | twitter | threads | github | reddit | medium`. 파일 첨부(PDF, 이미지) 없음.

**문제**: 제품이면 웹 링크와 메모만으로 부족. PDF 공유, 스크린샷 캡처는 기본 기대 사항.

**khoj 구현 분석**:
- `TextToEntries` 추상 클래스 → 포맷별 프로세서 (PdfToEntries, ImageToEntries 등)
- PDF: PyMuPDFLoader (LangChain), 이미지: OCR
- 8개 포맷을 동일 인터페이스로 처리

**채택 내용**:
- Phase 1b: `source_type: pdf` 추가 (텔레그램/WhatsApp 파일 첨부 → 텍스트 추출 → 일반 캡처 파이프라인)
- Phase 1d: `source_type: image` 추가 (OCR 또는 Vision API → 텍스트 추출)
- 구현은 para-pipeline SKILL.md에 포맷별 분기 추가

**채택하지 않는 것**:
- Notion/GitHub 동기화 — 커넥터 아키텍처는 Phase 2+
- DOCX/org-mode — 수요 불분명

**스펙 영향**: §4.4 Phase 로드맵에 추가, §7.3 `source_type` enum 확장

---

### 2.5 멀티테넌트/공유 경로 (from cognee, supermemory)

**현재 스펙**: 단일 사용자 vault 가정.

**문제**: 제품화하면 사용자 격리, 공유 vault, 권한 관리 필요.

**참조 구현**:
- cognee: User → Tenant → Dataset + ACL(READ/WRITE/DELETE/SHARE)
- supermemory: Container tags (문자열 기반 격리, 아키텍처 변경 없이)

**채택 내용**:
- Phase 1a: 변경 없음 (단일 사용자)
- Phase 2+: supermemory의 container tag 패턴 채택 — vault 경로 자체가 격리 단위 (`/vaults/{user_id}/`), 복잡한 ACL 없이 경로 기반 접근 제어
- cognee의 전체 ACL은 미채택 (Git 기반 vault에서는 Git 권한이 접근 제어 역할)

**스펙 영향**: §11 미결정에 "멀티테넌트 경로" 항목 추가

---

### 2.6 엔티티 추출 기반 스��트 Reweave (from cognee)

**현재 스펙**: Reweave는 같은 PARA 경로 + 태그 겹침 기반.

**문제**: 태그 매칭은 사용자가 태그를 일관되게 써야 작동. "DDD"와 "도메인 주도 설계"는 같은 개념인데 태그가 다르면 연결 안 됨.

**cognee 구현 분석**:
- LLM + Instructor 라이브러리 → Pydantic `KnowledgeGraph` 모델로 구조화 추출
- Node(id, name, type, description) + Edge(source, target, relationship_name)
- 온톨로지 매칭: 퍼지 매칭 80% 유사도로 기존 엔티티에 연결

**채택 내용**:
- Phase 1d+: Reweave에 엔티티 추출 레이어 추가
- 캡처 시 AI가 본문에서 핵심 엔티티를 추출 → frontmatter `entities: [DDD, Aggregate, Bounded Context]`
- Reweave 시 태그 겹침 OR 엔티티 겹침으로 threshold 확장
- 전체 지식 그래프 DB는 미채택 — frontmatter `entities` 필드 + grep으로 경량 구현

**스펙 영향**: §7.3 frontmatter에 `entities` 필드 추가 (Phase 1d), §7.2 Reweave threshold에 엔티티 조건 추가

---

## 3. Tier 2 — Phase 로드맵 추가 (스펙 본문은 미변경, 로드맵만 확장)

### 3.1 스킬 자가 개선 (from hermes-agent)

hermes-agent의 closed learning loop:
- 스킬 사용 후 agent가 실패/성공을 기록
- Pitfalls 섹션 자동 업데이트, Procedure 정제
- 버전 증가

**판단**: para-pipeline/para-brain SKILL.md가 자동으로 개선되면 캡처/분류 품질이 점진 향상. 하지만 Phase 1a에서는 수동 SKILL.md 편집이 더 통제 가능.

**Phase**: 2+ (스킬 eval 인프라가 갖춰진 후)

### 3.2 Speed-tiered 파일 (from walnut)

walnut의 "파일은 서로 다른 속도로 움직인다":
- key.md(주 단위) / now.md(매 저장) / log.md(불변) / insights.md(주간) / tasks.md(일일)
- 적응형 컨텍스트 사이징: 토큰 예산에 따라 자동 압축

**판단**: vault 노트의 frontmatter에 update_cadence 메타데이터를 추가하면 검색 가중치에 활용 가능. 하지만 Phase 1a에서는 단순 timestamp 기반 최신성으로 충분.

**Phase**: 1d+ (QMD 검색 가중치에 cadence 반영)

### 3.3 대화 fact의 중복/모순 통합 (from memory-bank)

memory-bank의 consolidation:
- 벡터 유사도 0.85 → DUPLICATE/CONTRADICTION/EVOLUTION/INDEPENDENT 분류
- 모순 감지 시 기존 fact 대체 + revision 기록

**판단**: §2.2에서 fact 추출은 채택했지만, consolidation은 fact가 충분히 쌓인 후 의미 있음.

**Phase**: 1d+ (fact 100개+ 축적 후)

---

## 4. Tier 3 — 미채택 (근거 포함)

| 프로젝트 | 기능 | 미채택 근거 |
|----------|------|------------|
| khoj | PostgreSQL + pgvector 인프라 | Git markdown vault와 양립 불가. 제품화 시에도 SQLite→QMD 경로가 가벼움 |
| khoj | APScheduler + leader election | NanoClaw task-scheduler가 이미 동일 역할 |
| cognee | 전체 지식 그래프 DB (Kuzu/Neo4j) | frontmatter entities + grep이 vault 규모에 충분. 별도 DB는 소스 of truth 분산 |
| cognee | ECL 파이프라인 프레임워크 | 우리 CODE 파이프라인과 1:1 매핑되지만, 추상화 레이어 추가 비용 대비 이득 없음 |
| supermemory | Cloudflare Workers 런타임 | Git-backed vault와 아키텍처 불일치 |
| supermemory | Memory vs RAG 분리 | vault markdown이 두 역할을 통합. 분리하면 소스 of truth 이원화 |
| memory-bank | 별도 SQLite fact DB | vault markdown이 소스 of truth. 별도 DB는 동기화 부담 |
| memory-bank | @xenova/transformers 로컬 임베딩 | QMD가 이미 로컬 임베딩(node-llama-cpp) 제공. 중복 |
| walnut | ALIVE 5폴더 구조 | PARA와 겹침. 두 체계 병행은 혼란 |
| walnut | Stash 메커닉 | §2.2 fact 추출이 동일 목적을 달성 |
| hermes | Honcho 사용자 모델링 | NanoClaw Per-Group CLAUDE.md가 이미 사용자 컨텍스트 역할 |
| arscontexta | 3-space 분리 (self/notes/ops) | NanoClaw 그룹 구조와 충돌 |
| arscontexta | /ralph 큐 오케스트레이션 | NanoClaw task-scheduler가 동일 역할 |
| notabase | Supabase + WYSIWYG | 클라우드 의존 + 에디터 중심. vault 접근과 다른 방향 |
| Smart2Brain | Orama 벡터 DB (JavaScript) | QMD의 sqlite-vec가 더 성숙하고 Node.js 호환 |
| PageIndex | Vectorless RAG (트리 추론) | 긴 단일 문서에 최적화. vault는 다수의 짧은 노트 → 다른 패턴 |
| browser-use | Python 브라우저 자동화 | NanoClaw는 Node.js. 크롤링은 이미 플랫폼별 전략으로 구현 |
| reader | Jina Reader API | 외부 API 의존. 크롤링 fallback으로는 고려 가능하나 핵심 채택은 아님 |
| Personal_AI_Infrastructure | TELOS 프레임워크 | 시스템이 너무 방대 (63+ 스킬, 16원칙). 개별 아이디어 레벨에서 이미 반영 |
| openclaw | Gateway WebSocket | NanoClaw IPC가 이미 동일 역할. 아키텍처 변경 불필요 |
| symphony | 스펙 기반 태스크 정의 | NanoClaw 스케줄 태스크가 이미 prompt 기반 |
| cli-jaw | 5-engine 멀티 AI | 단일 Claude 에이전트가 현재 설계. 멀티 LLM은 Phase 2+ |
| Scrapling | 적응형 스크래핑 | 플랫폼별 전략이 이미 구현. 범용 스크래퍼는 수요 불명확 |

---

## 5. 프로젝트별 상세 분석

### 5.1 khoj (33k+ stars) — AI Second Brain

**아키텍처**: Django + FastAPI + PostgreSQL/pgvector. Python.

**검색 파이프라인** (심층 분석):
- Stage 1: SentenceTransformer `thenlper/gte-small` (bi-encoder) → pgvector CosineDistance
- Stage 2: CrossEncoder `mixedbread-ai/mxbai-rerank-xsmall-v1` → reranking
- 신뢰도 threshold: 0.18 (DB 설정 가능)
- Reranking: `1 - cross_score`로 정렬, cross-encoder 우선 → bi-encoder fallback

**콘텐츠 인덱싱**:
- `TextToEntries` 추상 클래스 → 8개 포맷 프로세서
- 청킹: `RecursiveCharacterTextSplitter` (256토큰, separators: `\n\n` → `\n` → `.` → ` `)
- 중복: MD5 on `compiled` 텍스트. `hashed_value` 필드로 bulk dedup
- 배치: 200개 단위 bulk_create

**메모리 시스템**:
- `UserMemory` 모델: user + agent + embeddings(pgvector) + raw(텍스트)
- 7일 슬라이딩 윈도우: `updated_at >= now - 7days`, limit 10
- 장기 메모리: 벡터 유사도 검색, `CosineDistance <= max_distance`
- 추출: LLM이 대화에서 fact 추출 → `MemoryUpdates(create=[], delete=[])`

**자동화**: APScheduler + Django JobStore + ProcessLock(leader election). cron 기반 자동 쿼리, 메모리 생성, 뉴스레터.

**멀티 클라이언트**: CORS origin 기반 (obsidian.md, khoj.dev, capacitor, localhost). JWT 인증. 13개 API 엔드포인트.

**우리와의 비교**:
- 검색: khoj >> 우리 (시맨틱 2-stage vs grep). QMD 통합으로 격차 축소 예정
- 인프라: khoj = PostgreSQL 필수. 우리 = Git + SQLite (가볍지만 스케일 한계)
- 메모리: khoj의 UserMemory 7일 윈도우 + 벡터 검색은 우리 `distill_layer` 개념과 보완적
- 포맷: khoj 8개 vs 우리 8개 (종류 다름). PDF/이미지 경로 채택 (§2.4)

---

### 5.2 cognee — Knowledge Engine

**아키텍처**: Python async. Kuzu(그래프) + LanceDB(벡터) + SQLite/PostgreSQL(관계형).

**ECL 파이프라인** (심층 분석):
- ADD: 파일 인제스트 → DataItem 생성
- COGNIFY: classify → chunk → **extract_graph**(LLM + Instructor → KnowledgeGraph) → summarize → add_data_points
- SEARCH: 10개 검색 타입 (GRAPH_COMPLETION, RAG, CHUNKS, TEMPORAL 등)

**엔티티 추출**:
- Instructor 라이브러리: LLM 응답을 Pydantic 모델로 구조화
- `KnowledgeGraph(nodes: List[Node], edges: List[Edge])`
- Node: id, name, type, description
- Edge: source_node_id, target_node_id, relationship_name
- 프로바이더별 모드: OpenAI=json_schema, Anthropic=tool_call, Gemini=json_schema

**멀티테넌트**:
- User → Tenant → Dataset + ACL(READ/WRITE/DELETE/SHARE)
- 격리: 쿼리 필터링(기본) 또는 DB 인스턴스 분리(고급)

**우리와의 비교**:
- 그래프: cognee = 전체 그래프 DB. 우리 = frontmatter `related:` + `entities`. 경량 vs 풍부
- 엔티티 추출: cognee의 Instructor 패턴은 직접 채택 가치 (§2.6)
- 멀티테넌트: cognee의 ACL 모델은 제품화 참고 (§2.5)

---

### 5.3 supermemory — Memory + Context Engine

**아키텍처**: Cloudflare Workers + Next.js. HNSW 인덱싱.

**Memory vs RAG 구분**:
- Memory: 사용자에 대한 fact (선호, 결정). 시간적 관계 추적 (`Updates`, `Extends`, `Derives`)
- RAG: 문서 청크 검색. 누구에게나 동일 결과
- 하나의 지식 그래프에서 함께 운영. Container tag로 격리.

**시간적 지식**:
- "SF로 이사했어" → "NYC에 살아" 자동 대체 (`Updates` 관계)
- Static fact vs Dynamic memory 구분

**커넥터**: Google Drive, Gmail, Notion, GitHub (웹훅 실시간 동기화)

**우리와의 비교**:
- Memory/RAG 구분: 개념적으로 유용하나, vault markdown에서 분리하면 소스 이원화. 미채택
- Container tag: 경로 기반 격리로 동일 효과 달성 가능. 제품화 시 채택 (§2.5)
- 시간적 지식: `distill_layer` + `captured` timestamp으로 부분 커버. 명시적 모순 감지는 Phase 2+

---

### 5.4 memory-bank — Local Fact Engine

**아키텍처**: TypeScript + SQLite + sqlite-vec + @xenova/transformers. MCP 서버.

**Fact 추출** (심층 분석):
- 세션 종료 시 5개 교환 단위로 배치 처리
- 카테고리: decision, preference, pattern, knowledge, constraint
- 신뢰도: 0.9+(명시적), 0.7-0.9(추론), <0.7(폐기)
- 스코프: project-specific vs global
- 세션당 최대 20개 (비용 통제)

**Consolidation**:
- 벡터 유사도 0.85 → LLM이 관계 분류
- DUPLICATE → 병합 + consolidation_count++
- CONTRADICTION → 대체 + revision 기록
- EVOLUTION → 업데이트 + 변경 이력
- INDEPENDENT → 둘 다 유지
- 사이클당 최대 10회 LLM 호출 (비용 통제)

**온톨로지**: Domain → Category → Facts. 타입 관계: INFLUENCES, SUPERSEDES, SUPPORTS, CONTRADICTS.

**로컬 임베딩**: `Xenova/all-MiniLM-L6-v2` (384차원). API 호출 없음. sqlite-vec 가상 테이블.

**스코프 격리**: `scope_type = 'project' AND scope_project = ?` OR `scope_type = 'global'`

**MCP 도구 9개**: search, search_facts, search_ontology, trace_fact, explore_graph, cross_project_insights, ask_avatar, graph_stats, read

**우리와의 비교**:
- Fact 추출: 직접 채택 (§2.2). NanoClaw 세션 종료 시 동일 패턴
- Consolidation: Phase 1d+ (fact 축적 후)
- 로컬 임베딩: QMD가 이미 제공. 중복 미채택
- 스코프 격리: NanoClaw 그룹이 동일 역할

---

### 5.5 arscontexta — Agent-Native Second Brain

**아키텍처**: Claude Code 플러그인. Markdown + ripgrep + optional qmd.

**Zettelkasten + PARA** (심층 분석):
- **layered, not simultaneous**: Zettelkasten = knowledge graph (notes/ 공간), PARA = operational coordination (self/ + ops/)
- 원자적 노트: 산문 문장 제목, 단일 클레임, 플랫 폴더, `[[wikilink]]`
- 위키링크는 본문에 포함 = 관계의 의미를 서술
- MOC(Map of Content): 주제별 허브 노트

**6Rs 파이프라인**:
- Record → Reduce(LLM 추출) → Reflect(기존 노트 연결) → Reweave(기존 노트 역갱신) → Verify(cold-read 테스트) → Rethink(가정 도전)
- `/ralph`로 큐 기반 오케스트레이션, 서브에이전트별 fresh context
- 각 phase가 격리된 서브에이전트에서 실행 → 컨텍스트 오염 방지

**15가지 커널 원칙 중 주요**:
1. Markdown + YAML = 아티팩트
2. `[[wikilink]]` = 에지 생성
3. MOC 계층 = 주의 관리
4. Description 필드 = progressive disclosure
5. Schema enforcement = 검증 훅

**우리와의 비교**:
- Zettelkasten 링킹: 직접 채택 (§2.1). `[[wikilink]]` + 원자적 노트
- 6Rs: 우리 CODE와 매핑 (Record=Capture, Reduce=Distill, Reflect+Reweave=Organize의 Reweave, Rethink=Express). Verify가 우리에 없음 → Phase 1b eval에서 "cold-read 테스트" 추가 검토
- 서브에이전트별 fresh context: NanoClaw 메시지당 세션이 동일 효과

---

### 5.6 walnut — Speed-Tiered Context

**아키텍처**: 5개 코어 파일 (`_core/`), ALIVE 5폴더. Claude Code 플러그인.

**속도 계층** (심층 분석):
- `key.md` (주 단위): 정체성, 목표, 인물, 태그. append-only
- `now.md` (매 저장): 현재 상태 스냅샷. full replacement
- `log.md` (불변): 타임스탬프 결정 기록. prepend-only
- `insights.md` (주간): 도메인 지식, 상시 학습. narrative 성장
- `tasks.md` (일일): 우선순위별 큐 (Urgent/Active/Todo/Blocked/Done)

**적응형 컨텍스트 사이징**: 토큰 예산 초과 시 자동 압축 — log 축소 → tasks 축소 → hard cap

**Stash 메커닉**: 대화 중 결정/태스크/메모를 무음 수집 → 저장 시점에 목적지별 라우팅 (decisions→log, tasks→tasks, notes→목적지 walnut)

**PARA 매핑**:
- P(Projects) → `04_Ventures/` + active capsules
- A(Areas) → `02_Life/`
- R(Resources) → `03_Inputs/` + bundles
- A(Archives) → `01_Archive/`

**결정적 해석기**: LLM 없이 순수 문자열 매칭으로 walnut 해석 (exact → people → goal keyword → tag → sticky)

**우리와의 비교**:
- 속도 계층: 개념적으로 유용. 하지만 vault 노트에 cadence 메타데이터 추가는 Phase 1d+ (검색 가중치 반영 시)
- Stash: §2.2 fact 추출이 동일 목적
- ALIVE ↔ PARA: 겹침이 많아 병행 불필요

---

### 5.7 hermes-agent — Self-Improving Agent

**아키텍처**: Python. 6개 터미널 백엔드 (local, Docker, SSH, Daytona, Singularity, Modal).

**Closed Learning Loop** (심층 분석):
- 복잡한 태스크 완료 후 → 절차를 markdown 스킬로 저장 → `~/.hermes/skills/`
- 재사용 시: 실패/성공 기록 → Pitfalls 섹션 업데이트 → Procedure 정제 → 버전 증가
- agentskills.io 호환 포맷

**사용자 모델링**:
- `MEMORY.md` (~800 tokens): 환경, 프로젝트 규칙, 교훈
- `USER.md` (~500 tokens): 정체성, 선호, 소통 스타일
- Honcho 통합: 변증법적 이중 표현 (사용자의 자기 모델 + AI의 사용자 모델)
- 세션 시작 시 디스크에서 로드 → 시스템 프롬프트에 주입

**크로스 세션 회상**: SQLite FTS5 검색 + LLM 요약

**우리와의 비교**:
- 스킬 자가 개선: Phase 2+ (eval 인프라 후). 아이디어는 좋지만 통제 가능성 확보 필요
- 사용자 모델링: NanoClaw Per-Group CLAUDE.md가 동일 역할
- FTS5 회상: NanoClaw 대화 아카이브가 동일 역할

---

## 6. 나머지 프로젝트 요약

| 프로젝트 | 한줄 요약 | 채택 여부 |
|----------|----------|----------|
| qmd | BM25 + sqlite-vec + LLM reranking. MCP 서버 | 이미 Phase 1d 통합 예정 |
| memsearch | Markdown-first + SHA-256 dedup + file watcher | 콘텐츠 해시만 채택 (§2.3) |
| claudian | Obsidian + Claude Code. VaultFileAdapter, Permission Mode | 간접 참고 |
| openclaw | NanoClaw upstream. 25+ 채널, Gateway WS | upstream 머지로 이미 반영 |
| obsidian-skills | Agent Skills 스펙. defuddle(웹→마크다운) | 스킬 포맷 참고 |
| second-brain-skills | Progressive disclosure, MCP 클라이언트 | 스킬 설계 참고 |
| second-brain-ai-assistant-course | ZenML + MongoDB + Quality Scoring | 인프라 과도. 미채택 |
| cli-jaw | 5-engine, 116 스킬, PABCD | 간접 참고 |
| symphony | 에이전트 작업 spec 정의, proof-of-work | 간접 참고 |
| browser-use | Python CDP 브라우저 자동화 | 미채택 (Node.js 스택) |
| reader | Jina Reader API (URL→마크다운) | fallback 후보 |
| Scrapling | 적응형 스크래핑 + MCP | 미채택 |
| Understand-Anything | 코드베이스 → 지식 그래프 | 미채택 (코드 분석 특화) |
| awesome-agent-harness | 하니스 엔지니어링 모범 사례 | 철학 참고 |
| awesome-autoresearch | 자율 개선 루프 큐레이션 | Phase 2+ 참고 |
| everything-claude-code | 28 에이전트, 125 스킬, 훅 | 하니스 패턴 참고 |
| last30days-skill | 10+ 소스 실시간 수집 | 미채택 (다른 도메인) |
| walnut | Speed-tiered context, ALIVE | Tier 2 (§3.2) |
| GitNexus | BM25 + semantic + RRF, 영향도 분석 | QMD와 겹침 |
| OpenViking | Context DB, L0/L1/L2 tiered loading | 간접 참고 |
| gitagent | Git-native agent 표준 | 간접 참고 |
| notabase | Supabase + WYSIWYG + 양방향 링크 | 미채택 (클라우드) |
| Personal_AI_Infrastructure | TELOS, 63+ 스킬, 6-layer | 간접 참고 (너무 방대) |
| Scrapling | 적응형 스크래핑 | 미채택 |

---

## 부록: 채택 사항 → 스펙 변경 매핑

| 채택 | 스펙 섹션 | 변경 내용 | Phase |
|------|----------|----------|-------|
| §2.1 wikilink | §7.1 노트 템플릿 | `[[wikilink]]` 예시 추가 | 1a |
| §2.1 wikilink | §7.2 Reweave | 위키링크 생성 로직 | 1a |
| §2.2 fact 추출 | §4.3 para-brain | 대화 fact 추출 워크플로우 | 1b |
| §2.2 fact 추출 | §10.2 eval | fact 추출 eval 케이스 | 1b |
| §2.3 콘텐��� 해시 | §7.3 frontmatter | `content_hash` 필드 | 1a |
| §2.3 콘텐츠 해시 | §4.3 para-pipeline | 해시 체크 단계 | 1a |
| §2.4 멀티포맷 | §4.4 Phase 로드맵 | PDF(1b), 이미지(1d) | 1b, 1d |
| §2.4 멀티포맷 | §7.3 source_type | `pdf`, `image` 추가 | 1b, 1d |
| §2.5 멀티테넌트 | §11 미결정 | 경로 기반 격리 항목 | 2+ |
| §2.6 엔티티 추출 | §7.3 frontmatter | `entities` 필드 | 1d |
| §2.6 엔티티 추출 | §7.2 Reweave | 엔티티 겹침 threshold | 1d |
