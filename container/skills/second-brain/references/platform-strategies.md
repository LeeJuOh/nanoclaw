# Platform-Specific Crawling Strategies

Read this when crawling a URL. Match the platform from the URL, follow that platform's strategy. Every attempt MUST be logged to `$VAULT/_logs/crawl.jsonl` (see Crawl Diagnostics in SKILL.md).

## YouTube (`youtube.com`, `youtu.be`)

**Goal**: 영상 메타데이터 + 자막/트랜스크립트 추출

1. `curl -sL -m 30 <url>` → HTML에서 메타데이터 추출:
   - `<title>`, `og:title` → 영상 제목
   - `og:description` → 설명
   - `og:image` → 썸네일 (기록만, 다운로드 불필요)
   - JSON-LD (`@type: VideoObject`) → 게시일, 채널명, 길이
2. 자막 추출 시도:
   ```bash
   # yt-dlp이 있으면 자막 추출
   which yt-dlp && yt-dlp --write-auto-sub --sub-lang ko,en --skip-download --print-to-file subtitle "%(.subtitle)s" -o "/tmp/yt-%(id)s" "<url>" 2>/dev/null
   ```
   - `yt-dlp` 없으면 자막 없이 진행 (메타데이터 + 설명만으로 노트 생성)
   - 자막이 있으면 노트 본문에 `## 트랜스크립트` 섹션 추가 (핵심 부분 발췌, 전체 복사 금지)
3. 크롤 로그: `method: "curl"` (메타 추출), `method: "yt-dlp"` (자막)

**Gotcha**: 비공개/연령제한 영상은 메타데이터만 가능. 자막 실패해도 메타+설명으로 노트 생성 진행.

## Twitter/X (`twitter.com`, `x.com`)

**Goal**: 트윗 본문 + 스레드 전체 수집

1. **curl 사용하지 마라** — JS shell만 반환됨 (빈 `<noscript>` + React 앱)
2. `agent-browser`로 URL 열기:
   - 페이지 로드 대기
   - 트윗 본문 텍스트 추출
   - 이미지/미디어 URL 기록 (다운로드 불필요)
3. **스레드 감지**: 같은 작성자의 연속 트윗이 있는지 확인
   - "Show this thread" 또는 연결된 트윗이 보이면 스크롤하여 전체 수집
   - 모든 트윗 텍스트를 순서대로 연결
4. 크롤 로그: `method: "browser"`, `content_length`는 추출된 텍스트 바이트

**Gotcha**:
- 로그인 필요 콘텐츠: "This post is from a suspended account" 등 → 로그에 `reason` 기록, 사용자에게 안내
- 비공개 계정: 접근 불가 → `usable: false`, `reason: "private account"`
- 인용 트윗(QRT): 원본 트윗 내용도 함께 캡처

## Threads (`threads.net`, `threads.com`)

**Goal**: 포스트 본문 추출

1. **curl 사용하지 마라** — 로그인 벽 또는 빈 HTML 반환
2. `agent-browser`로 URL 열기:
   - 페이지 로드 대기
   - 포스트 본문 텍스트 추출
3. **실패 가능성 높음**: `invalid_post` 오류로 홈 피드 리다이렉트 발생 가능
   - 홈 피드로 리다이렉트됐는지 확인 (URL 변경 또는 피드 UI 감지)
   - 리다이렉트 시 → `usable: false`, `reason: "invalid_post redirect, login required"`
4. 완전 실패 시 사용자에게 안내:
   > "이 Threads 포스트는 로그인 없이 접근이 안 돼요. 포스트 내용을 복사해서 텍스트로 보내주시면 메모로 캡처할게요."

**Gotcha**: Threads는 비로그인 접근 제한이 심함. 성공률 낮은 플랫폼이므로 실패 안내 UX가 중요.

## GitHub (`github.com`)

**Goal**: README + 레포 메타데이터

**레포 URL** (`github.com/{owner}/{repo}`):
1. API로 레포 메타 가져오기:
   ```bash
   curl -sL -m 15 "https://api.github.com/repos/{owner}/{repo}" \
     -H "Accept: application/vnd.github.v3+json"
   ```
   → `description`, `stargazers_count`, `language`, `topics`, `created_at`, `updated_at`
2. README 가져오기:
   ```bash
   curl -sL -m 15 "https://raw.githubusercontent.com/{owner}/{repo}/HEAD/README.md"
   ```
   → README가 너무 길면 (>5000자) 상위 섹션만 사용
3. 크롤 로그: `method: "api"`

**이슈/PR/Discussion URL**:
- `curl -sL` → HTML에서 제목, 본문, 댓글 추출
- 실패 시 `agent-browser` fallback

**Gotcha**: API rate limit (비인증 60req/h). 429 응답 시 `curl -sL` fallback으로 HTML 파싱.

## Reddit (`reddit.com`)

**Goal**: 포스트 본문 + 주요 댓글

**방법 1 — JSON API** (추천):
```bash
curl -sL -m 15 -H "User-Agent: SecondBrain/1.0" "<url>.json"
```
→ 포스트 제목, 본문(selftext), 점수, 상위 댓글 5개

**방법 2 — old.reddit.com** (JSON 실패 시):
```bash
curl -sL -m 15 -H "User-Agent: SecondBrain/1.0" "https://old.reddit.com/..."
```
→ 단순 HTML, JS 불필요

**방법 3 — agent-browser** (위 두 방법 모두 실패 시 최후 수단)

**노트 구성**: 포스트 본문 + 인사이트 있는 상위 댓글 (단순 반응/밈 제외)

**Gotcha**:
- User-Agent 필수 — 없으면 429
- NSFW/private 서브레딧: 접근 불가 → `usable: false`
- 크로스포스트: 원본 포스트 URL 추적

## Medium (`medium.com`, `*.medium.com`, `towardsdatascience.com`)

**Goal**: 아티클 본문 전체

1. `curl -sL -m 30 <url>` 시도 — 페이월 전 콘텐츠가 HTML에 포함될 수 있음
   - 본문이 충분히 길면 (>2000자) 성공 처리
2. 본문이 짧거나 페이월 메시지 감지 시 → `agent-browser` fallback
   - browser에서 전체 아티클 텍스트 추출
3. 크롤 로그: curl 성공 시 `method: "curl"`, fallback 시 `method: "browser"`

**Gotcha**: Medium 페이월은 비회원 3회 무료 후 차단. agent-browser에서도 페이월이 걸릴 수 있음. 그 경우 부분 콘텐츠로 노트 생성 + 사용자에게 알림.

## Generic Web (위 플랫폼에 해당 안 되는 모든 URL)

**Goal**: 페이지 본문 추출

1. `curl -sL -m 30 -o /tmp/crawl_result.html -w "%{http_code} %{size_download} %{content_type}" <url>`
   - HTTP 상태, 응답 크기, Content-Type을 크롤 로그에 기록
2. **Usability 판정**:
   - 응답 < 1KB → `usable: false`, `reason: "response too short"`
   - `<noscript>` 태그만 있고 본문 없음 → `usable: false`, `reason: "JS-only site"`
   - HTTP 4xx/5xx → `usable: false`, `reason: "HTTP {status}"`
   - Content-Type이 HTML이 아님 (PDF 등) → 별도 처리
3. 실패 시 `agent-browser` fallback → 같은 usability 판정 반복
4. browser도 실패 시 → 사용자에게 안내

---

## 공통 규칙

- **모든 크롤링 시도는 로깅 필수**: 성공이든 실패든 `$VAULT/_logs/crawl.jsonl`에 기록
- **Fallback 체인**: 각 플랫폼의 primary 방법 → fallback 방법 → 사용자 안내 (최대 3단계)
- **타임아웃**: curl은 `-m 30` (30초), agent-browser는 페이지 로드 60초 대기 후 포기
- **콘텐츠 크기 제한**: 크롤링된 원본이 100KB 초과 시 상위 내용만 사용 (AI 분석 컨텍스트 한계)
