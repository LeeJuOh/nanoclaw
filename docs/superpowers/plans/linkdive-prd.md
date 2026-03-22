# LinkDive PRD — AI Second Brain

> **최종 정리**: 2026-03-22
> **상태**: Phase 1a 진행 중 (NanoClaw second-brain 스킬 구현 완료, 개인 사용 검증 중)
> **이전 문서**: linkdive_research.md(리서치/ADR), discovery_plan.md(가설 검증), 2026-03-15-second-brain-design.md(디자인 스펙), 2026-03-16-second-brain-setup.md(셋업 구현 플랜)

---

## 1. 문제 정의

### 페인포인트

- 정보는 넘치는데 다 읽을 시간이 없다
- 저장할 곳이 없다 — 브라우저 북마크, 카톡 나에게 보내기, 메모 앱에 흩어짐
- 저장해도 방치된다 — 분류가 귀찮아서
- AI Agent가 내 지식을 활용할 수 없다 — 사람용 도구와 Agent용 도구가 분리

### 제품 비전

**"캡처는 인간처럼 쉽게, 활용은 Agent처럼 강력하게"**

- Pocket/북마크 앱: 사람이 다시 찾아와야 함 → 방치
- LinkDive: 에이전트가 vault를 능동적으로 활용 → 사람이 안 와도 가치 발생

### 전략 전환

"일반 유저 대상 iOS 앱" → **"본인이 첫 유저 (Mac + Claude Code + NanoClaw)"**

- Phase 0: 자기 자신이 첫 유저, 니즈 검증
- 니즈 충족 시: 서비스화 검토 (iOS 앱 등)

---

## 2. 가설 & 검증

### 가설 구조

```
H3' (에이전트가 vault를 쓸모 있게 활용하는가?)
 |
 +-- Yes --> H1 (캡처 습관이 생기는가?) --> 본격 빌드
 |            +-- H2' (hybrid 분류가 추론 품질을 높이는가?) --> PARA 고도화
 |
 +-- No  --> 피봇 (에이전트 활용 방식 재설계 or 프로젝트 재검토)
```

| # | 가설 | Impact | Uncertainty | 우선순위 |
|---|------|--------|-------------|---------|
| **H3'** | 에이전트가 vault를 능동적으로 활용하면 저장의 가치가 발생한다 | 극높음 | 높음 | **P0** |
| **H1** | 캡처 프릭션 = 0이면 저장 습관이 생긴다 | 높음 | 중간 | **P1** |
| **H2'** | AI 자동 분류 + 사용자 승인 hybrid가 에이전트 추론 품질을 높인다 | 중간 | 중간 | **P2** |

### 검증 실험

**실험 1: H3' — "에이전트가 내 vault를 쓸모 있게 쓰는가?"**

- 준비물: 마크다운 폴더 + Claude Code (순정)
- 기간: 1-2주

| 결과 | 판단 | 다음 행동 |
|------|------|----------|
| 2주간 vault 기반 질문 **10회 이상** 자발적으로 함 | 강한 신호 | H1 검증 → 캡처 파이프라인 구축 |
| 5-9회, 유용했지만 습관은 안 됨 | 약한 신호 | vault 구조나 프롬프트 개선 후 1주 연장 |
| 4회 이하 | 실패 | 피봇 — 에이전트 활용 방식 재설계 |

**실험 2: H1 — "캡처가 쉬우면 습관이 되는가?" (H3' 통과 시)**

- 준비물: NanoClaw + 텔레그램 채널
- 기간: 2주

| 결과 | 판단 | 다음 행동 |
|------|------|----------|
| 일평균 2개 이상 캡처 + vault 활용 유지 | 성공 | H2' 검증 |
| 캡처는 하는데 vault 활용이 줄어듦 | 부분 | 에이전트 활용 워크플로우 개선 |
| 캡처 자체를 안 하게 됨 | 실패 | 캡처 UX 재설계 |

**실험 3: H2' — "PARA 분류가 에이전트 추론을 높이는가?" (H1 통과 시)**

- 방법: A/B 비교 (플랫 구조 vs PARA 분류), 기간 1주

---

## 3. 아키텍처 (방향 F)

> 방향 A(웹앱) → B(하네스) → C(MCP) → D(NanoClaw+앱) → E(NanoClaw+Dashboard) → **F(iOS앱+NanoClaw)** 로 수렴. 이전 방향 상세는 `linkdive_research.md` 섹션 8 참조.

```
+---------------------------+         +-----------+
|  LinkDive iOS App (Swift) | GitHub  |  GitHub   |
|                           |  API    |  vault    |
|  - GitHub 로그인          |-------->|  repo     |
|    (Device Flow -> OAuth) |         | (markdown)|
|  - 공유시트 캡처           |<--------|           |
|  - 인박스 시각화           |  API    +-----------+
|  - 태그/PARA 관리         |               ^
|  - 검색                   |          git pull/push
|  - 채팅 없음              |               |
+---------------------------+      +------------------+
                                   | NanoClaw          |
  텔레그램/왓츠앱 ---------------->| (사용자 로컬 Mac) |
  (채팅 + 간편 캡처)               |                   |
                                   | + second brain    |
                                   |   스킬             |
                                   | - vault repo 폴링  |
                                   | - AI 크롤링/요약   |
                                   | - PARA 분류        |
                                   | - 스케줄 처리       |
                                   | - QMD 검색         |
                                   +------------------+
```

### 핵심 결정

| 영역 | 결정 | 비고 |
|------|------|------|
| 제품 형태 | iOS 네이티브 앱 (Swift) | 캡처(공유시트) + vault 관리. 채팅 없음 |
| AI 엔진 | NanoClaw (그대로 사용) + second brain 스킬 | 텔레그램은 `add-telegram` 스킬 적용 |
| 저장소 | GitHub private repo (markdown) | 파일 primary, SQLite = 재빌드 가능한 캐시 |
| 포맷 | Markdown + YAML frontmatter | `contexts`(M:N 소속) + `tags`(속성) 분리 |
| 분류 | PARA + AI 자동 분류 | 수동(기본) / 자동(opt-in) |
| 검색 | Phase 1a=grep, 1b=GitHub Search API, 1d=QMD | QMD persistent 서버 모드 |
| 인증 (MVP) | GitHub Device Flow | 서버 없음 |
| 동시 쓰기 | status 기반 단일 작성자 | Obsidian은 `approved` 노트만 편집 권장 |
| AI 비용 | Max 구독 월정액 (추가 종량제 0원) | `AIProcessor` 인터페이스로 교체 가능 |
| CLAUDE.md | 3단 구조 (Identity/Procedural/Semantic) | |
| 오프라인 | MVP 미지원 | 오프라인 캐싱은 Phase 2 검토 |

### 저장소 모델: 파일 primary, DB derived

```
GitHub (markdown 파일)  <-- 진실의 원천 (source of truth)
        | git pull/push
로컬 파일시스템          <-- 작업 공간
        | 빌드
SQLite                  <-- 파생 인덱스 (언제든 재빌드 가능)
```

핵심 테스트: SQLite를 삭제하고 `rebuild-index` 한 번 돌리면 100% 복구되는가? Yes면 올바른 구조.

### Write Path (충돌 방지)

| status | 쓰기 권한 | 설명 |
|--------|----------|------|
| `raw` | **NanoClaw만** 수정 | 캡처 직후. 앱은 읽기만 |
| `pending_review` | **앱/사용자만** 수정 | AI 처리 완료. NanoClaw는 읽기만 |
| `classified` | **앱/사용자만** | 사용자 분류 완료 |
| `auto_classified` | **NanoClaw**가 전환 | 자동 분류 완료 (고신뢰도) |

Obsidian 예외: `raw`/`pending_review` 파일은 편집하지 않도록 권장.

### 검색 전략

| vault 규모 | 검색 방법 | 비고 |
|-----------|----------|------|
| ~300개 | Claude Code 순정 (Grep + Read) | 충분. 외부 도구 불필요 |
| 500개+ | QMD (BM25+벡터+LLM 리랭킹+쿼리 확장) | Node.js, MCP 퍼스트클래스, ~2GB |
| PDF/긴 문서 추가 시 | + PageIndex 병용 | LLM 추론 기반, 벡터 DB 불필요 |

### 레퍼런스 프로젝트 역할 요약

| 역할 | 프로젝트 | LinkDive에서 |
|------|---------|-------------|
| 에이전트 플랫폼 | **NanoClaw** | 그대로 사용. 스킬만 추가 |
| 검색 엔진 (Phase 1d) | **QMD** | persistent HTTP 서버 모드 |
| 긴 문서 검색 (Phase 4) | **PageIndex** | PDF 전용 |
| PKM 철학/구조 | **AI4PKM** | PARA, inbox, 스케줄 처리 참고 |
| 제로 프릭션 캡처 | **OpenClaw** | 채팅 캡처 UX 참고 |
| 가장 유사한 기존 제품 | **Khoj** (33k+ star) | 차별점: 데이터 소유(마크다운 vs DB), 인프라 경량성, PARA 분류 |

---

## 4. 제품 스펙

### 메시지 라우팅

| 메시지 유형 | 동작 | 기능 |
|------------|------|------|
| URL만 | 캡처 | F3 |
| URL + 텍스트 | 캡처 (텍스트는 사용자 메모) | F3 |
| 명시적 캡처 ("저장해", "캡처해") + 텍스트 | 텍스트 메모 캡처 | F3 |
| 명시적 PARA 명령 ("새 프로젝트", "아카이브해") | PARA 관리/분류 | F2/F4 |
| 파일 첨부 | 미지원 안내 (Phase 1a Scope Out) | - |
| 그 외 텍스트 | 대화/질의 — 볼트 검색 우선 | F5 |
| 모호한 경우 | 확인 질문 | - |

원칙: URL은 자동 캡처. 텍스트는 명시적 트리거 없으면 대화로 취급.

### F1. 볼트 셋업

최초 1회. PARA 디렉토리 구조 초기화 + GitHub repo 설정 + git credential 설정.

```
vault/
  inbox/              <-- 새 캡처 (raw/pending_review)
  projects/           <-- PARA P (동적 하위 폴더)
  areas/              <-- PARA A
  resources/          <-- PARA R
  archive/            <-- 삭제 불가, 항상 존재
  _settings.yaml      <-- agent config (auto_classify)
  README.md
```

### F2. PARA 관리

| 명령 | 동작 |
|------|------|
| "새 프로젝트/영역/리소스 만들어: {name}" | `{category}/{name}/` 생성 + git commit |
| "{name} 아카이브해" | `archive/{name}/`으로 이동 |
| "프로젝트 목록" | 하위 폴더 나열 |
| "아카이브에서 삭제해줘" | **거부** — "아카이브는 삭제할 수 없어요" |

PARA 정의:

| Category | Definition | Lifecycle |
|---|---|---|
| Projects | 목표 + 마감일이 있는 단기 작업 | 완료/중단 → Archive |
| Areas | 마감 없이 지속 관리하는 책임 영역 | 비활성 → Archive |
| Resources | 참고용 관심사/자료 | 불필요 → Archive |
| Archive | 콜드 스토리지 | **삭제 불가, 항상 존재** |

의사결정 트리: 진행 중 프로젝트? → Projects / 책임 영역? → Areas / 참고자료? → Resources / 끝남? → Archive

### F3. 캡처 파이프라인

**URL 캡처:**
1. URL 감지
2. 크롤링: `curl -sL -m 30` → HTML이면 readable content 추출. 실패 시 `agent-browser` fallback
3. AI 요약 생성: title, summary (2-3문장), tags (3-5개)
4. Frontmatter 작성 (status: `pending_review`)
5. `inbox/YYYYMMDD-HHMMSS-slug.md`에 저장
6. `git add + commit + push` (push 실패 시 로컬 유지, 다음 기회에 재시도)
7. `_settings.yaml` 확인: `auto_classify: false` → 분류 추천 회신 / `true` → 즉시 자동 분류

**텍스트 메모 캡처** ("저장해"/"캡처해" + 텍스트):
- 동일 파이프라인, source 없음, `source_type: memo`

**중복 체크**: `grep -rl "<normalized-url>" /workspace/extra/vault/`
- 중복 시: "이미 캡처되어 있어요: {title} ({path})"
- URL 정규화: trailing slash 제거, www. 제거, hostname 소문자

### F4. 분류

**수동 모드 (기본, `auto_classify: false`):**
1. 캡처 후 기존 PARA 폴더 목록 확인
2. 의사결정 트리로 추천 생성
3. 각 추천 경로가 기존 폴더인지 신규인지 표기
4. 회신:
   > *캡처 완료: {title}*
   > 추천: `resources/{topic}` (기존) — {reason}
   > 다른 옵션: `projects/{name}` (기존), `areas/{name}` (신규)
5. 사용자 응답 → 이동 + `status: classified` / 무응답 → inbox 유지

**자동 모드 (`auto_classify: true`):**
- 즉시 분류 + `status: auto_classified` + 알림만

**모드 토글**: "자동 분류 켜줘/꺼줘" → `_settings.yaml` 업데이트

### F5. 볼트 검색/질의

1. 볼트에서 grep/glob으로 키워드 검색
2. 매칭 노트 읽기 + 답변 합성
3. 볼트에 없으면 일반 지식으로 답변 (명시적으로 안내)

검색 전략:
- 키워드: `grep -ril "keyword" /workspace/extra/vault/`
- 날짜: `grep -rl "captured: 2026-03" .../inbox/`
- 태그: `grep -rl "tags:.*keyword" ...`
- 컨텍스트: `grep -rl "contexts:.*projects/linkdive" ...`

### F6. 주간 리뷰 (스케줄 태스크)

매주 일요일 09:00 자동 실행.

**수동 모드**: inbox/ 미분류 목록 + 분류 추천만 (이동 안 함) + 이번 주 캡처 수
**자동 모드**: 자동 분류 실행 + 확신도 낮은 것만 리뷰 목록 + 이번 주 캡처 수

### Frontmatter 스키마

```yaml
---
title: "Note title"
source: "https://..."           # 텍스트 메모면 생략
source_type: web                # web | memo
captured: 2026-03-15T14:30:00+09:00
processed: 2026-03-15T14:30:05+09:00
status: pending_review          # raw | pending_review | classified | auto_classified
contexts:                       # M:N PARA 경로 (논리적 소속)
  - resources/ddd
  - projects/linkdive
tags: [ddd, architecture]       # 자유 키워드 (PARA와 무관)
ai_summary: "2-3 sentence summary"
ai_suggested_category: "resources/ddd"
---
```

- `contexts` = **소속** (어디에 연결되는가, PARA 경로)
- `tags` = **속성** (무엇에 대한 것인가, 자유 키워드)
- 물리적 위치: contexts 중 파일 경로와 일치하는 항목
- Status 전이: `raw -> pending_review -> classified` (수동) / `raw -> auto_classified` (자동)
- 실제로는 캡처+AI 처리가 원자적이므로 `pending_review`가 초기 상태. `raw`는 처리 실패 시에만 발생

### 파일 명명

`YYYYMMDD-HHMMSS-slug.md` (예: `20260315-143000-ux-research-methods.md`)
- Slug: ASCII 영문+숫자+하이픈, 최대 60자
- 한국어 제목: 영문 키워드 추출 또는 날짜 기반 fallback

### M:N 관계 모델

물리적 배치(PARA 폴더 1곳) + 논리적 연결(contexts) + 검색(QMD 전체 인덱싱) 3층 구조.

```
projects/app-redesign/
  +-- 앱 와이어프레임 초안              <-- 실제 저장
  +-- 스프린트 2 회고                   <-- 실제 저장
  +-- UX 리서치 방법론 가이드           <-- (ref) resources/research-methods/
  +-- React 컴포넌트 패턴              <-- (ref) resources/react/
```

### Git 규칙

- 항상 `cd /workspace/extra/vault` 후 git 작업
- Commit 형식: `capture: {title}`, `classify: {title} -> {target}`, `para: create {category}`, `review: weekly inbox cleanup`
- commit 후 항상 push 시도. 실패 시 다음 작업에서 재시도
- 작업 전 `git pull --rebase`로 동기화

---

## 5. Phase 로드맵

| Phase | 내용 | 검증 가설 |
|-------|------|----------|
| **1a** NanoClaw 셋업 + 개인 사용 | `/add-telegram` + `/add-second-brain` + 개인 사용 검증 | H3' + H1 |
| **1b** iOS 앱 MVP | Device Flow 로그인, 공유시트 캡처, 인박스, pending_review 승인 | H1 + H2 |
| **1c** 스킬 PR | NanoClaw 공식 repo에 `/add-second-brain` 컨트리뷰션 | - |
| **1d** QMD 통합 | persistent HTTP 서버 모드, 하이브리드 시맨틱 검색 | - |
| **2** 앱 고도화 | OAuth(CF Worker), 태그/PARA 편집, 검색 UI, 텍스트 메모 | H3 (듀얼 접근) |
| **3** 토픽 관리 | 토픽 그루핑, Obsidian 그래프 뷰/백링크 | - |
| **4** 멀티모달 | PageIndex + PDF, 이미지 캡처(Vision), 파일 업로드 | - |

Phase 1a 완료 → 1b 순차 진행이 현실적 (1인 개발).

---

## 6. Scope Out

| 항목 | 도입 시점 |
|------|----------|
| QMD 검색 통합 | Phase 1d |
| iOS 앱 | Phase 1b |
| Obsidian 플러그인 연동 | 볼트 구조 안정화 후 |
| Progressive Summarization (Distill) | 캡처/분류 검증 후 |
| 크래시 버퍼 (temp 파일 보호) | 처리 실패 빈도 높아지면 |
| `captured_via` frontmatter | 두 번째 캡처 채널 추가 시 |
| 비동기 지시 폴더 (`_instructions/`) | 필요 느낄 때 |
| 영상 URL 트랜스크립트 추출 | Phase 2 |
| 파일 첨부 캡처 (PDF, 이미지) | Phase 4 |
| SQLite 파생 인덱스 (junction 테이블) | QMD 통합 또는 볼트 확대 시 |

---

## 7. 리스크

| 리스크 | 대응 |
|--------|------|
| 컨테이너 git push 인증 실패 | HTTPS + PAT + git credential helper. `.ssh` 마운트는 보안 모듈이 차단 |
| Claude Max 정책 변경 | `AIProcessor` 인터페이스로 추상화. 대안 LLM 교체 가능 |
| 크롤링 실패 (JS 렌더링 필요) | curl 우선 → agent-browser(Chromium) fallback |
| PARA 분류 품질 | 의사결정 트리 + 사용자 리뷰 보완 |
| GitHub repo 크기 폭발 | 텍스트만이면 당분간 안전. PDF/이미지 시 LFS 전환 검토 |
| Archive 실수 삭제 | CLAUDE.md에 삭제 거부 규칙 명시 |
| 캡처와 주간 리뷰 git 충돌 | NanoClaw GroupQueue 직렬화 + 주간 리뷰를 일요일 오전 배치 |
| NanoClaw 의존성 (PR 거절 등) | 스킬은 fork에서도 동작. CLAUDE.md 기반이라 이식 가능 |
| Khoj/DIY 대안 commodity화 | iOS 앱 + PARA 자동 분류가 차별점. 실행 속도가 관건 |
| 메시지 의도 오분류 (캡처 vs 질문) | 메시지 라우팅 규칙 + 모호하면 확인 질문 |

---

## 8. 미결정 사항

- iOS 앱 세부 UI/UX 설계
- QMD persistent 서버 운영 방식 (별도 프로세스 vs NanoClaw 내부)
- contexts vs tags 구분의 일반 사용자 UX 검증
- 오프라인 캐싱 전략 (Phase 2)
- GitHub repo 크기 관리 정책 (LFS 도입 시점)
- 최소 시스템 요구사항 확정 (RAM 16GB+, 디스크 5GB+ 추정)

---

## 부록: 방향 변천 요약

| 버전 | 방향 | 결과 |
|------|------|------|
| v1-v2 | 웹 앱 SaaS | 스코프 과다 + 차별점 부족 |
| v3 | 에이전트/하네스 | NanoClaw 발견 → 직접 구현 불필요 |
| v4 (D) | NanoClaw + 네이티브 앱 | 텔레그램으로 충분, 앱 불필요 |
| v5 (E) | NanoClaw 스킬 + Dashboard | 앱이 다시 필요해짐 |
| **v6 (F)** | **iOS 앱 + NanoClaw 스킬** | **현재 방향** — 앱=캡처+관리, 텔레그램=채팅 |

상세 의사결정 기록은 `linkdive_research.md` 참조.
