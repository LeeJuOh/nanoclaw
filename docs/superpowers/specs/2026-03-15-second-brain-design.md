# Second Brain on NanoClaw — Design Spec

## Overview

NanoClaw 위에 개인용 second-brain 시스템을 구축한다. 텔레그램으로 링크/메모를 캡처하면 에이전트가 크롤링, 마크다운 변환, PARA 분류, GitHub 저장까지 자동 처리한다.

## Background

### 해결하려는 문제

- 정보 과잉 속에서 소비할 시간 부족
- 저장은 하지만 분류/활용이 안 됨 (북마크, 텔레그램 저장, 메모앱 분산)
- AI 에이전트가 사용자의 지식 베이스에 접근할 수 없음

### 핵심 가설 (discovery_plan.md 기반)

- **H3'**: 에이전트가 볼트를 능동적으로 활용하면 캡처 동기가 생긴다
- **H1**: 텔레그램 포워드 수준의 마찰이면 캡처 습관이 형성된다
- **H2'**: PARA 분류된 볼트가 flat 구조보다 에이전트 추론 품질이 높다

### 기존 리서치 결정사항

- 실행 플랫폼: NanoClaw (직접 구축 아님)
- 저장소: GitHub private repo (마크다운)
- 분류 체계: PARA (Projects / Areas / Resources / Archive)
- 분류 기준: 주제가 아닌 실행 가능성(Actionability) 기반
- 인증: OAuth (Claude Max 구독)
- 경량 오케스트레이터(CLI) 전환: 후순위로 별도 검토

### PARA 정의 (Building a Second Brain 기반)

| 카테고리 | 정의 | 라이프사이클 |
|----------|------|-------------|
| **Projects** | 목표 + 마감일이 있는 단기 작업 | 완료/중단 시 → Archive |
| **Areas** | 마감 없이 지속 관리하는 책임 영역 | 비활성화 시 → Archive |
| **Resources** | 참고용 관심사/자료 | 불필요 시 → Archive |
| **Archive** | 완료/중단된 P,A,R의 콜드 스토리지 | **삭제 불가, 항상 존재** |

**의사결정 트리** (노트 분류 시):

1. 지금 진행 중인 프로젝트에 쓰이나? → Projects
2. 지속적 책임 영역에 필요한가? → Areas
3. 언젠가 참고할 만한가? → Resources
4. 다 끝났거나 필요 없는가? → Archive

**워크플로우** (CODE 프레임워크):
Capture(수집) → Organize(정리/PARA 분류) → Distill(핵심 추출) → Express(활용)

### 노트 저장 모델 (M:N contexts)

노트는 **물리적으로 PARA 폴더 1곳**에 존재하되, frontmatter `contexts` 필드로 **논리적 다대다 연결**을 지원한다.

```yaml
---
title: "UX 리서치 방법론 가이드"
source: "https://example.com/ux-research"
contexts:                               # 소속 — 이 노트가 관련된 PARA 경로들 (M:N)
  - projects/app-redesign
  - areas/ux-design
  - resources/research-methods          # ← 파일 경로와 일치하는 것이 실제 물리적 위치
tags: [ux, research, methodology]       # 속성 — 자유 키워드 (PARA와 무관)
---
```

| | contexts | tags |
|---|---|---|
| 의미 | **소속** — 어디에 연결되는가 | **속성** — 무엇에 대한 것인가 |
| 값 형태 | PARA 경로 (`projects/app-redesign`) | 자유 키워드 (`ux`, `react`) |

- 물리적 위치 판별: contexts 중 파일 경로와 일치하는 항목이 실제 위치
- AI가 "가장 중요한 맥락"을 골라 물리적 배치, 나머지는 contexts로 연결
- 검색(QMD)은 폴더 구조 무관하게 볼트 전체 인덱싱

## Architecture

```
┌─────────────┐     ┌──────────────────────────────────────────────┐
│  iPhone      │     │  Mac (상시 실행)                              │
│              │     │                                              │
│  텔레그램 ───────→  나노클로                                      │
│  (링크/메모)  │     │   ├─ 텔레그램 채널 (수신)                     │
│              │     │   ├─ SQLite 큐                               │
│              │     │   ├─ 컨테이너 (Agent SDK + OAuth)             │
│              │     │   │   └─ second-brain 그룹 에이전트            │
│              │     │   │       ├─ 볼트 셋업                        │
│              │     │   │       ├─ 캡처 파이프라인                   │
│              │     │   │       ├─ PARA 관리                        │
│              │     │   │       ├─ 분류 엔진                        │
│              │     │   │       ├─ 볼트 검색/질의                    │
│              │     │   │       └─ git commit + push                │
│              │     │   └─ 스케줄러                                 │
│              │     │       └─ 주간 리뷰 (inbox 비우기)              │
│              │     │                                              │
│              │     │  second-brain repo (GitHub private)           │
│              │     │   ├─ inbox/          ← 새 캡처 (raw)          │
│              │     │   ├─ projects/       ← PARA P (동적 생성)     │
│              │     │   ├─ areas/          ← PARA A (동적 생성)     │
│              │     │   ├─ resources/      ← PARA R (동적 생성)     │
│              │     │   └─ archive/        ← 삭제 불가, 항상 존재    │
└─────────────┘     └──────────────────────────────────────────────┘
```

## Message Routing

에이전트가 수신 메시지를 어떤 기능으로 분기하는지의 기본 규칙. CLAUDE.md(Step 4)에 반영.

| 메시지 유형 | 동작 | 기능 |
|------------|------|------|
| URL만 있는 메시지 | 캡처 | F3 |
| URL + 텍스트 | 캡처 (텍스트는 사용자 메모로 frontmatter에 포함) | F3 |
| 명시적 캡처 명령 ("저장해", "캡처해") + 텍스트 | 텍스트 메모 캡처 | F3 |
| 명시적 PARA 명령 ("새 프로젝트", "아카이브해", "분류해줘") | PARA 관리/분류 | F2, F4 |
| 파일 첨부 (PDF, 이미지 등) | 미지원 안내 (Phase 1a Scope Out) | - |
| 그 외 텍스트 | 대화/질의 — 볼트 검색 우선, 없으면 일반 지식 | F5 |
| 모호한 경우 | 확인 질문 | - |

**원칙**: URL은 의도가 명확하므로 자동 캡처. 텍스트는 명시적 트리거 없으면 대화로 취급.

## Features

### F1. 볼트 셋업

최초 1회 실행. 텔레그램에서 "볼트 셋업해줘"로 트리거.

**입력**: GitHub repo 이름

**동작**:
1. 새 GitHub private repo 초기화
   - `git init` + 호스트에서 사전 생성한 remote 추가
   - 기존 레포 연결/clone 불가 — 포맷 불일치로 인한 혼란 방지
2. PARA 디렉토리 구조 초기화:
   ```
   inbox/
   projects/
   areas/
   resources/
   archive/
   ```
   - `archive/`는 **삭제 불가, 항상 존재** — 볼트에서 제거 시도 시 에이전트가 거부
3. `.gitignore` 생성 (`.obsidian/`, `.DS_Store` 등 제외)
4. 볼트 README.md 생성 (PARA 규칙 요약)
5. initial commit + push
6. 셋업 완료 확인 메시지

**Note**: `gh` CLI는 컨테이너에 미설치. GitHub repo 생성은 호스트에서 사전 수행하거나, 에이전트가 GitHub API를 직접 호출한다. 컨테이너 안에서는 `git` 명령만 사용.

**기존 볼트 마이그레이션**: 기존 볼트(`a_*`, `p_*` 접두어 파일)와의 공존은 지원하지 않음. 포맷/디렉터리 구조 불일치로 검색·분류가 꼬이므로 새 레포로 시작. 마이그레이션은 별도 스크립트로 진행.

### F2. PARA 관리

PARA 카테고리(하위 폴더)의 생성, 조회, 아카이브를 관리한다.

**명령 예시**:
- "새 프로젝트 만들어: LinkDive 개발" → `projects/linkdive-개발/` 생성
- "새 영역 추가: 건강관리" → `areas/건강관리/` 생성
- "새 리소스: DDD 패턴" → `resources/ddd-패턴/` 생성
- "LinkDive 프로젝트 아카이브해" → `projects/linkdive-개발/` → `archive/linkdive-개발/` 이동
- "프로젝트 목록 보여줘" → projects/ 하위 폴더 나열

**규칙**:
- Archive는 삭제 불가. "아카이브에서 삭제해줘" 요청 시 거부 + 이유 설명
- Archive는 항상 존재. 볼트 셋업 시 생성, 이후 제거 불가
- P/A/R → Archive 이동만 허용 (Archive → 다른 카테고리 복원은 허용)
- 카테고리 폴더 내에 하위 구조는 자유 (에이전트가 적절히 구성)

### F3. 캡처

사용자가 URL이나 텍스트를 보내면 볼트에 저장한다.

**URL 캡처 흐름**:
1. URL 감지
2. 크롤링 → 마크다운 변환 (`curl`/`fetch` 우선, 실패 시 에이전트 브라우저 fallback)
3. AI 요약 생성 (title, summary, tags)
4. YAML frontmatter 작성:
   ```yaml
   ---
   title: "제목"
   source: "https://..."
   source_type: web
   captured: 2026-03-15T14:30:00+09:00
   processed: 2026-03-15T14:30:05+09:00
   status: raw
   contexts: []
   tags: [tag1, tag2]
   ai_summary: "..."
   ai_suggested_category: "resources/ddd"
   ---
   ```
   - `captured`: 캡처 시점 (메시지 수신)
   - `processed`: AI 처리 완료 시점 (크롤링+요약 후). 처리 전이면 없음
5. `inbox/YYYYMMDD-HHMMSS-slug.md`에 저장
   - 파일명 예시: `20260315-143000-ux-research-methods.md`
   - slug 규칙: 제목에서 생성, ASCII 영문 + 숫자 + 하이픈, 최대 60자
   - 한국어 제목은 영문 키워드 추출 또는 날짜 기반 fallback
   - 타임스탬프 접두어로 시간순 정렬 + 중복 방지
6. `git add + commit + push`
   - push 실패 시: 로컬 commit은 유지, 다음 캡처 또는 주간 리뷰에서 재시도
7. 텔레그램으로 확인 회신: "캡처 완료: {title} → inbox/"

**텍스트 메모 캡처**:
- URL 없는 텍스트 → 제목 자동 생성, source 없이 저장
- 동일 흐름 (inbox/ → frontmatter → git push)

**중복 방지**: URL 정규화 + 기존 노트의 source 필드 grep 검색. 중복 시 사용자에게 알림.

### F4. 분류

inbox/의 노트를 PARA 카테고리로 이동한다. **수동 분류가 기본**, 자동 분류는 opt-in.

#### 수동 분류 (기본 모드)

캡처 완료 후 에이전트가 PARA 추천을 제시하고 사용자가 결정한다.

1. 캡처 시 에이전트가 노트 내용 + 현재 PARA 구조 분석
2. 의사결정 트리 적용:
   - 진행 중인 프로젝트에 관련? → Projects 추천
   - 책임 영역에 관련? → Areas 추천
   - 참고자료? → Resources 추천
3. 텔레그램으로 추천 제시:
   > "캡처 완료: {title}\n추천: `resources/ddd-패턴`에 넣을까요?\n다른 곳: `projects/linkdive`, `areas/개발`"
4. 사용자 응답:
   - 승인 → 해당 위치로 이동 + `status: classified` + contexts 설정
   - 거부/수정 → 사용자가 지정한 위치로 이동
   - 무응답 → inbox/에 `status: pending_review`로 유지

**직접 분류 명령**:
- "이 노트를 DDD 리소스로 옮겨줘" → 직접 이동
- "미분류 노트 보여줘" → inbox/ 내 status: raw/pending_review 목록

#### 자동 분류 (opt-in)

별도 기능으로 분리. 사용자가 명시적으로 활성화해야 동작.

- "자동 분류 켜줘" → 이후 캡처 시 추천 없이 바로 분류 + 알림만. `status: auto_classified`로 설정
- "자동 분류 꺼줘" → 수동 모드로 복귀
- 주간 리뷰(F6)에서도 자동 분류 모드일 때만 inbox 노트를 자동 이동. 수동 모드면 목록만 보고

**모드 저장**: 볼트 루트 `_settings.yaml`에 기록. 에이전트가 매 처리 시작 시 읽음.
```yaml
# vault/_settings.yaml
auto_classify: false   # true면 캡처 시 추천 없이 바로 분류
```

**status 값 정의**:

| status | 의미 | 다음 전이 |
|--------|------|----------|
| `raw` | 캡처됨, AI 미처리 | → `pending_review` (수동) 또는 `auto_classified` (자동) |
| `pending_review` | AI 처리 완료, 사용자 리뷰 대기 | → `classified` (사용자 승인) |
| `classified` | 사용자가 분류 승인 | 최종 |
| `auto_classified` | 자동 분류 완료 (opt-in 모드) | 최종 (사용자가 수정 가능) |

> **리서치 대비 변경**: `approved` → `classified`. "승인"보다 "분류 완료"가 행위를 더 정확히 반영.
> **리서치 대비 변경**: frontmatter `url` → `source`. 텍스트 메모는 URL이 없으므로 범용 필드명으로 변경.
> **리서치 대비 변경**: frontmatter `created` → `captured`. 일반적 생성 시점이 아니라 캡처 행위 시점을 명확히 표현.

### F5. 검색/질의

사용자가 질문하면 볼트를 검색해서 답변한다.

**Phase 1a** (현재):
- grep + glob 기반 키워드 검색
- CLAUDE.md에 볼트 구조 설명 → 에이전트가 적절한 폴더에서 검색

**Phase 1d** (후순위):
- QMD 통합 (BM25 + 벡터 + LLM 리랭킹)

**질의 예시**:
- "DDD에서 Value Object가 뭐야?" → resources/ddd 관련 노트 검색 → 답변
- "이번 달 캡처한 거 보여줘" → frontmatter captured 날짜 기준 필터
- "LinkDive 프로젝트 관련 자료 정리해줘" → projects/linkdive + 관련 노트 종합

### F6. 주간 리뷰 (스케줄 태스크)

매주 일요일 09:00 자동 실행. inbox/ 비우기 + 상태 보고. `_settings.yaml`의 `auto_classify` 설정에 따라 동작이 달라진다.

**수동 모드 (auto_classify: false)**:
1. inbox/에서 `status: raw` / `pending_review` 노트 목록 확인
2. 각 노트에 분류 추천만 생성 (이동하지 않음)
3. 텔레그램 발송:
   - "미분류 노트 N개:" + 노트별 "{title} → 추천: `resources/xxx`"
   - 이번 주 캡처 총 개수
4. 사용자가 답장으로 분류 결정

**자동 모드 (auto_classify: true)**:
1. inbox/에서 `status: raw` / `pending_review` 노트 목록 확인
2. 각 노트 자동 분류 + `status: auto_classified`로 이동. confidence 낮으면 이동 안 하고 리뷰 목록에 남김
3. 텔레그램 발송:
   - 자동 분류된 노트 N개 (어디로 이동했는지)
   - 리뷰 필요한 노트 M개 (목록 포함)
   - 이번 주 캡처 총 개수

## Implementation Steps

### Step 1: 볼트 GitHub 레포 초기화

새 GitHub private repo를 생성하고 PARA 구조로 초기화.

- GitHub private repo 생성 + `git init` + remote 추가
- `.gitignore` 생성 (`.obsidian/`, `.DS_Store` 등)
- PARA 디렉토리 생성: `inbox/`, `projects/`, `areas/`, `resources/`, `archive/`
- initial commit + push

### Step 2: second-brain 그룹 등록

**전제조건**: NanoClaw에 `add-telegram` 스킬이 적용되어 있어야 함. 미적용 시 `/add-telegram` 먼저 실행.

메인 텔레그램 채팅에서 "second-brain 그룹 추가해줘" 또는 CLI로 등록.

```
그룹명: second-brain
폴더: second-brain
JID: tg:<채팅ID>
```

### Step 3: 컨테이너 마운트 + GitHub 인증 설정

코어 소스 수정 아님. 설정 파일 변경:

1. **마운트 허용 목록** (`~/.config/nanoclaw/mount-allowlist.json`)에 볼트 경로 추가 (`allowReadWrite: true`)
2. **그룹 등록 시** `containerConfig.additionalMounts`에 볼트 경로 지정
3. **GitHub 인증**: 컨테이너 보안 모듈이 `.ssh`, `.gnupg` 마운트를 차단하므로, 볼트 디렉토리 내에 `.git-credentials` 파일 + git credential helper 설정으로 HTTPS + PAT(Personal Access Token) 방식 사용

**코어 수정 범위**: 0줄 (설정 파일만 변경).

### Step 4: groups/second-brain/CLAUDE.md 작성

에이전트 행동 지시문. 3단 구조 (리서치의 5단 인지 모델에서 축소):

**Identity** — 역할 정의:
- "second-brain 볼트 관리 에이전트" 역할 선언
- 응답 형식, 언어 규칙

**Procedural** — 워크플로우 규칙:
- 캡처 파이프라인 절차 (F3)
- 분류 규칙 + 의사결정 트리 (F4)
- PARA 관리 규칙 — Archive 삭제 불가 등 (F2)
- git commit/push 규칙
- 검색 방법 (F5)

**Semantic** — 도메인 지식:
- 볼트 경로 및 구조 설명
- PARA 정의 + 카테고리별 의미
- contexts vs tags 구분
- frontmatter 스키마

> 나머지 2단(Episodic — 세션 다이제스트, Working — 현재 작업 컨텍스트)은 볼트 규모가 커지면 추가. Scope Out 참조.

### Step 5: 스케줄 태스크 등록

메인 채팅에서 주간 리뷰 태스크 등록:

```
"매주 일요일 09:00에 second-brain 그룹으로 '주간 리뷰 실행해줘' 보내줘"
```

NanoClaw 스케줄러가 cron 또는 interval 형식으로 등록. 실행 시간은 캡처와 겹치지 않도록 오전으로 설정.

### Step 6: 검증

1. 텔레그램에서 URL 전송 → inbox/에 파일 생성 + git push 확인
2. "새 프로젝트 만들어: 테스트" → projects/테스트/ 생성 확인
3. "이 노트 테스트 프로젝트로 옮겨" → 분류 확인
4. "아카이브에서 삭제해줘" → 거부 확인
5. "DDD에 대해 알려줘" → 볼트 검색 확인
6. 스케줄 태스크 → 주간 리뷰 동작 확인

## Scope Out (후순위)

| 항목 | 이유 | 도입 시점 |
|------|------|----------|
| QMD 검색 통합 | grep으로 먼저 검증 | Phase 1d |
| iOS 앱 | 나노클로 검증 후 | Phase 1b |
| 경량 오케스트레이터 (CLI) 전환 | 나노클로로 충분히 써본 후 판단 | 미정 |
| Obsidian 플러그인 연동 | 볼트 구조 안정화 후 | 미정 |
| Progressive Summarization (Distill 단계) | 기본 캡처/분류 검증 후 | 미정 |
| CLAUDE.md Episodic/Working 단계 | 초기에 세션 간 연속성 문제 없음. 볼트 100개+ 되면 재검토 | 볼트 규모 확대 시 |
| 세션 다이제스트 (`digests/YYYY-MM-DD.md`) | 처리량이 적은 초기에 불필요. 다이제스트 없이 CLAUDE.md + frontmatter로 충분 | 볼트 규모 확대 시 |
| 시작 컨텍스트 (처리 전 다이제스트 읽기) | 세션 다이제스트와 세트. 다이제스트 도입 시 함께 | 볼트 규모 확대 시 |
| 크래시 버퍼 (temp 파일 보호) | NanoClaw SQLite 큐가 메시지 유실 방지. AI 추론 중단 시 재처리로 충분 | 처리 실패 빈도 높아지면 |
| `captured_via` frontmatter 필드 | 현재 캡처 채널이 텔레그램 하나. 채널 추가 시 도입 | 두 번째 캡처 채널 추가 시 |
| `.linkdive/config.yaml` + `templates/` | 설정은 CLAUDE.md로 충분. 별도 config 파일은 스킬 공개(1c) 시 검토 | Phase 1c |
| 비동기 지시 폴더 (`_instructions/`) | 텔레그램으로 지시 가능. 파워유저 기능은 필요 느낄 때 | 미정 |
| 파일 첨부 캡처 (PDF, 이미지 등) | Phase 1a는 URL + 텍스트만. 파일은 처리 파이프라인이 다름 | Phase 4 |
| `content_hash` (SHA-256) 멱등성 | URL grep으로 Phase 1a 충분. 같은 URL 내용 변경 감지는 볼트 커진 후 | 볼트 규모 확대 시 |
| SQLite 파생 인덱스 (`note_contexts`, `note_tags`) | grep 검색으로 충분. M:N 쿼리 성능 필요 시 도입 | QMD 통합(Phase 1d) 또는 볼트 규모 확대 시 |

## Risks

| 리스크 | 대응 |
|--------|------|
| 컨테이너에서 git push 인증 실패 | HTTPS + PAT + git credential helper — Step 3. `.ssh` 마운트는 보안 모듈이 차단하므로 사용 불가 |
| Max 구독 rate limit | 캡처 대량 아니면 문제 없음. 모니터링 후 판단 |
| 크롤링 실패 (JS 렌더링 필요) | curl 우선, 실패 시 에이전트 브라우저(Chromium) fallback |
| PARA 분류 품질 | 제목/태그 매칭 기반 판단 + 사용자 리뷰로 보완 |
| 기존 볼트 구조와 PARA 충돌 | 마이그레이션 전까지 공존 허용 |
| Archive 실수로 삭제 | CLAUDE.md에 삭제 거부 규칙 명시 |
| 캡처와 주간 리뷰 동시 실행 시 git 충돌 | NanoClaw GroupQueue가 그룹 내 메시지를 직렬화. 단, 스케줄 태스크는 별도 큐이므로 볼트 내 lock file로 보호하거나, 주간 리뷰를 캡처가 드문 일요일 오전으로 설정해 회피 |
| 대량 링크 연속 캡처 | NanoClaw의 MAX_CONCURRENT_CONTAINERS가 throttle. 초과분은 큐에서 대기 |
| Obsidian 동시 편집 충돌 | `.obsidian/`은 `.gitignore` 처리. 노트 파일은 에이전트가 쓰고 Obsidian은 읽기 전용으로 사용 권장 |
| 폴더명 유니코드 정규화 (macOS NFD) | 폴더명은 ASCII 권장. 한국어 필요 시 NFD/NFC 차이 인지하고 일관성 유지 |
| 메시지 의도 오분류 (캡처 vs 질문) | Message Routing 규칙 적용. 모호한 경우 확인 질문으로 대응. 한국어 메시지 특히 주의 |
