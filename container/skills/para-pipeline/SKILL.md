---
name: para-pipeline
description: >
  Automatic capture and distill pipeline for a PARA knowledge vault.
  Captures URLs and memos, AI-processes them with Progressive Summarization
  (Layer 1-4), detects duplicates via URL and content_hash, generates
  [[wikilinks]] to existing notes, and saves to inbox. Only use this skill
  when the vault path ($VAULT or /workspace/extra/vault) exists.
  Triggers on URLs, "캡처", "저장", "save", "캡처해".
model: sonnet
effort: high
---

# Para Pipeline — Capture & Distill

**사전 확인**: `$VAULT` 경로(`/workspace/extra/vault` 또는 볼트 경로)가 존재하지 않으면 이 스킬을 사용하지 마세요. 사용자에게 "이 그룹에는 vault가 설정되어 있지 않습니다"라고 안내하고 즉시 종료하세요.

## Vault Path

Your vault path is determined by the environment:
- **NanoClaw container**: `/workspace/extra/vault` (mounted by the host)
- **Claude Code local**: The directory specified in CLAUDE.md or the current working directory if it contains PARA folders (`inbox/`, `projects/`, `areas/`, `resources/`, `archive/`)

If you cannot locate the vault, ask the user for the path.

Throughout this skill, `$VAULT` refers to whichever vault path applies.

## Identity

You are the *capture pipeline agent*. Your job:
1. Capture links and memos the user sends
2. Auto-apply Progressive Summarization (Layer 1-4)
3. Detect duplicates via URL normalization and content hash
4. Find vault connections and create `[[wikilinks]]`
5. Save everything to inbox — NEVER classify (move) files

Always respond in the same language the user writes in.

## Gotchas

- **플랫폼별 크롤링 필수**: URL을 받으면 반드시 플랫폼을 먼저 감지하고, 해당 플랫폼 전략으로 크롤링. 모든 URL에 `curl -sL`부터 시도하면 Twitter/X, Threads, Medium 등에서 빈 HTML만 받음. [references/platform-strategies.md](references/platform-strategies.md) 참조
- **크롤링 결과는 반드시 로깅**: 모든 크롤링 시도를 `$VAULT/_logs/crawl.jsonl`에 기록. 로그 없이는 실패 원인 진단 불가. Crawl Diagnostics 섹션 참조
- **curl 타임아웃 & JS-only 사이트**: `curl -sL -m 30`이 빈 HTML이나 403을 반환하면 `agent-browser`로 즉시 fallback. 30초 제한 초과 시에도 동일. 응답이 짧거나(`<1KB`) `<noscript>` 태그만 있으면 browser fallback
- **Threads 로그인 벽**: 일부 Threads 포스트는 비로그인 접근 시 `invalid_post` 오류로 홈 피드 리다이렉트됨. agent-browser로도 실패하면 사용자에게 텍스트 복붙 안내. 크롤 로그에 반드시 실패 사유 기록
- **Threads 셀프 리플라이 필수 수집**: Threads에서는 원작자가 첫 글에 이어 자기 리플라이로 본문을 확장하는 패턴이 빈번 (예: @unclejobs.ai Claude Code 업데이트 글). 원글 URL만 크롤링하면 핵심 콘텐츠가 유실됨. agent-browser로 크롤 시 반드시 원작자 리플라이를 함께 수집하여 본문에 병합. 타인 댓글은 제외. [references/platform-strategies.md](references/platform-strategies.md)의 "Threads 셀프 리플라이 수집" 섹션 참조
- **Twitter/X 스레드 수집**: 단일 트윗 URL이어도 스레드(같은 작성자의 연속 트윗)인지 확인. agent-browser에서 스크롤하여 전체 스레드 수집. curl은 JS shell만 반환하므로 무조건 browser
- **한국어 slug 생성**: 한국어 제목에서 ASCII slug를 만들 때, 영문 키워드가 없으면 날짜 기반 fallback (`20260321-143000-note`). transliteration을 시도하지 말 것
- **push는 스케줄러가 한다**: 캡처 후 로컬 commit만 하고 push하지 않음. 10분 간격 스케줄 태스크가 `git push`를 담당. 캡처 파이프라인에서 push를 시도하면 타임아웃 위험
- **git pull --rebase 충돌**: Obsidian이 로컬에서 파일을 수정했을 수 있음. 충돌 시 `git rebase --abort` 후 `git pull --no-rebase`로 merge
- **캡처 1건마다 즉시 메시지 전송**: 여러 URL을 한번에 받으면 각 캡처 완료 시 `mcp__nanoclaw__send_message`로 즉시 결과 전송. 끝까지 모아서 한번에 보내면 컨테이너 타임아웃(~30분)으로 결과 유실
- **중복 URL 정규화**: 비교 전에 trailing slash 제거, `www.` 제거, hostname 소문자화. query parameter나 fragment는 보존 (같은 URL의 다른 섹션일 수 있음)
- **content_hash 중복**: URL이 다르더라도 크롤링된 본문의 SHA-256이 기존 노트와 같으면 중복. 중복 감지 순서: (1) URL 일치 → 중복, (2) URL 다르지만 content_hash 일치 → 중복 안내 + 기존 노트 경로 제시, (3) URL 같지만 content_hash 다름 → 업데이트 캡처 허용
- **긴 세션 타임아웃**: 컨테이너 세션은 약 45분 후 타임아웃됨. 대량 캡처 시 `mcp__nanoclaw__send_message`로 중간 결과를 먼저 보내고, 마지막에 요약 전송
- **_settings.yaml 부재**: 파일이 없으면 기본값으로 동작. 파일 생성을 시도하되 실패해도 계속 진행
- **캡처는 항상 inbox**: 파일을 inbox 밖으로 이동하지 마세요. 분류 추천만 전송하고, 실제 분류(이동)는 para-brain이 담당
- **복합 메시지**: "이 URL 캡처하고 resources/ddd로 분류해줘" — 캡처를 먼저 완료한 후 분류는 para-brain 스킬에 맡기세요. 캡처 결과 메시지에 분류 추천을 포함하면 사용자가 para-brain으로 분류 진행 가능
- **파일 첨부 미지원 안내**: 메시지에 `[Photo]`, `[Document: ...]` 같은 플레이스홀더가 있으면 채널에서 파일 다운로드가 미구현된 상태. "파일 캡처는 준비 중이에요. 텍스트로 복붙하거나 URL을 보내주세요" 안내. 무시하면 사용자가 캡처가 됐다고 착각
- **Readability로 토큰 절약**: `web` 타입 URL을 curl로 크롤링한 후, raw HTML을 그대로 분석하지 말 것. 컨테이너에 `readability-cli` 설치 시 본문만 추출하여 분석. 미설치 시 agent-browser의 텍스트 추출을 사용하거나, `<article>`/`<main>` 태그 기반으로 수동 추출. raw HTML의 nav, footer, ads, script가 토큰의 60-80% 차지
- **크롤링 캐시 활용**: 같은 URL 재시도 시 `crawl.jsonl`에서 최근 30분 이내 `usable: true` 로그를 확인. 캐시 히트면 해당 로그의 `note` 파일 원본을 재사용하여 재크롤링 스킵. 강제 재크롤링은 사용자가 명시적으로 요청할 때만

## Message Routing

When you receive a message, classify it:

| Message Type | Action |
|---|---|
| URL only | Detect platform → platform-specific capture (see Platform Detection) |
| URL + text | Detect platform → capture — text becomes user memo in frontmatter |
| Explicit capture ("저장해", "캡처해", "save") + text | Text memo capture |
| Crawl diagnostics ("크롤 실패", "크롤링 로그") | Crawl Diagnostics |
| File attachment (`[Photo]`, `[Document: ...]`) | 안내: "파일 캡처는 준비 중이에요. 텍스트로 복붙하거나 URL을 보내주세요" (Phase 1b 지원 예정) |
| Ambiguous | Ask a clarifying question |

*Principle*: URLs auto-capture. Text without explicit trigger = not for this skill.

## Platform Detection

URL을 받으면 크롤링 전에 소스 플랫폼을 먼저 감지한다. 플랫폼에 따라 크롤링 전략이 완전히 다르다.

| URL 패턴 | `source_type` | 크롤링 전략 |
|-----------|---------------|-------------|
| `youtube.com`, `youtu.be` | `youtube` | 메타데이터 + 자막/트랜스크립트 추출 |
| `twitter.com`, `x.com` | `twitter` | agent-browser 필수, 스레드 전체 수집 |
| `threads.net`, `threads.com` | `threads` | agent-browser 필수, 로그인 벽 대비 |
| `github.com` | `github` | API or curl로 README + 레포 메타 |
| `reddit.com` | `reddit` | old.reddit.com 변환 or JSON API |
| `medium.com`, `*.medium.com`, `towardsdatascience.com` | `medium` | agent-browser (페이월 대비) |
| 그 외 전부 | `web` | curl → 실패 시 agent-browser fallback |

각 플랫폼의 상세 크롤링 전략은 [references/platform-strategies.md](references/platform-strategies.md) 참조.

## Workflows

### Capture Pipeline

**URL Capture:**
1. Detect URL in message
2. **Platform Detection**: URL 패턴으로 `source_type` 결정 (Platform Detection 테이블 참조)
3. **Duplicate Check (URL)**: `grep -rl "<normalized-url>" $VAULT/` — if found, reply "이미 캡처되어 있어요: {existing title} ({path})" and stop
4. **Crawl Cache Check**: `crawl.jsonl`에서 같은 URL의 최근 30분 이내 `usable: true` 로그 확인. 캐시 히트면 해당 `note` 파일의 원본 콘텐츠를 재사용하여 step 8로 스킵. 강제 재크롤링은 사용자 명시 요청 시에만
5. **Platform-Specific Crawl**: 감지된 플랫폼의 전략으로 크롤링 ([references/platform-strategies.md](references/platform-strategies.md) 참조). 모든 시도를 Crawl Diagnostics로 로깅
6. **HTML Preprocessing (Readability)**: 크롤링된 콘텐츠가 HTML이면 본문만 추출한 뒤 이후 단계에서 사용. `readability-cli` 설치 시 `readable <file> --low-confidence force` → Markdown 변환. 미설치 시 agent-browser의 텍스트 추출 결과 사용 또는 `<article>`/`<main>` 태그 기반 수동 추출. raw HTML을 그대로 분석하면 토큰 60-80%가 nav/footer/ads/script에 낭비됨
7. **Duplicate Check (content_hash)**: 크롤링된 본문의 SHA-256을 Bash로 계산(`echo -n "$BODY" | shasum -a 256 | cut -d' ' -f1`)하고, `grep -rl "content_hash: \"sha256:{hash}\"" $VAULT/`로 기존 노트와 비교. 일치하면 "같은 콘텐츠가 이미 있어요: {existing title} ({path}). URL은 다르지만 본문이 동일합니다." 안내하고 중단. **주의**: Claude는 해시를 직접 계산할 수 없으므로 반드시 Bash 도구를 사용할 것
8. **Source Analysis** — read the crawled content and produce:
   - `title`: 원문 제목 또는 핵심을 반영한 제목
   - `ai_summary`: 2-3문장 요약
   - `tags`: 3-5개 키워드
   - `content_hash`: `sha256:` + SHA-256 of crawled body text
9. **Deep Analysis + Progressive Summarization** — 본문을 심층 분석하되, Layer 2-4를 동시에 적용:
   - **Layer 4 — Executive Summary**: 노트 최상단에 `> **Executive Summary**: {한 줄 핵심}` 블록
   - **핵심 주장 (Core Claims)**: 저자의 핵심 아이디어 2-3개. 핵심 문장을 **볼드**(Layer 2)로 마킹
   - **주요 논거 및 근거 (Key Arguments)**: 핵심 주장을 뒷받침하는 증거, 데이터, 사례. 최핵심 증거를 ==하이라이트==(Layer 3)로 마킹
   - **인사이트 (Insights)**: 기존 통념과 다른 시각, 놓치기 쉬운 포인트
   - **실용적 시사점 (Actionable Takeaways)**: 실제로 적용하거나 행동으로 옮길 수 있는 것. 핵심 행동을 **볼드**로 마킹
   - **한계 및 열린 질문 (Limitations & Open Questions)**: 저자가 다루지 않은 부분
   - **볼트 연결 (Vault Connections)**: `grep -ril` 로 볼트 내 관련 노트를 검색. 발견하면 `[[폴더/파일명|표시텍스트]] — {연결 사유}` 형식으로 wikilink 생성. 관련 노트가 없으면 이 섹션 생략
   - Progressive Summarization 가이드: [references/distill-layers.md](references/distill-layers.md) 참조
10. Create note using the format in [references/note-template.md](references/note-template.md)
   - frontmatter: `ai_distill_depth: 4`, `distill_layer: 0` 반드시 포함
11. Save to `$VAULT/inbox/YYYYMMDD-HHMMSS-slug.md`
   - Slug: ASCII alphanumeric + hyphens from title, max 60 chars
   - Korean titles: extract English keywords or date-based fallback (see Gotchas)
12. Git: `cd $VAULT && git add inbox/<filename> _logs/crawl.jsonl && git commit -m "capture: {title}"` (push는 스케줄러가 담당)
13. 분류 추천 포함 결과 메시지 전송 (파일은 항상 inbox에 유지):

> *캡처 완료: {title}*
>
> *핵심*: {Executive Summary 한 줄}
> *인사이트*: {가장 주목할 만한 포인트 1줄}
> *시사점*: {실용적 행동 지침 1줄}
>
> 배치: `{ai_suggested_category}` ({기존|신규}) — {reason}
> 연결: {[[wikilink1]], [[wikilink2]] 또는 "없음"}
> (답장으로 분류하거나 나중에 일괄 분류)

캡처 파이프라인은 여기서 종료. **분류(이동)는 para-brain 스킬이 담당**.

### Crawl Diagnostics

모든 크롤링 시도를 `$VAULT/_logs/crawl.jsonl`에 기록한다. 이 로그 없이는 실패 원인 진단이 불가능하다.

**로그 기록 방법:**
```bash
mkdir -p "$VAULT/_logs"
echo '<json>' >> "$VAULT/_logs/crawl.jsonl"
```

**로그 스키마** (한 줄 = 한 크롤링 시도):
```json
{
  "ts": "2026-03-22T14:30:00+09:00",
  "url": "https://x.com/user/status/123",
  "platform": "twitter",
  "method": "curl",
  "http_status": 200,
  "content_length": 847,
  "content_type": "text/html",
  "usable": false,
  "reason": "JS-only shell, no readable content (<1KB)",
  "next": "browser"
}
```

같은 URL에 대해 여러 시도가 있으면 각각 별도 줄로 기록. 최종 성공 시:
```json
{
  "ts": "2026-03-22T14:30:08+09:00",
  "url": "https://x.com/user/status/123",
  "platform": "twitter",
  "method": "browser",
  "content_length": 34500,
  "usable": true,
  "note": "20260322-143010-tweet-ddd-insight.md"
}
```

완전 실패 시 (노트 생성 불가):
```json
{
  "ts": "2026-03-22T14:30:15+09:00",
  "url": "https://threads.com/@user/post/abc",
  "platform": "threads",
  "method": "browser",
  "content_length": 0,
  "usable": false,
  "reason": "invalid_post redirect to home feed, login required",
  "next": "manual",
  "error": "사용자에게 텍스트 복붙 안내"
}
```

**필드 설명:**
| 필드 | 타입 | 설명 |
|------|------|------|
| `ts` | string | ISO 8601 타임스탬프 (+09:00) |
| `url` | string | 크롤링 대상 URL (정규화 전 원본) |
| `platform` | string | 감지된 플랫폼 |
| `method` | string | 크롤링 방법 (`curl`, `browser`, `api`) |
| `http_status` | number | HTTP 상태 코드 (curl만) |
| `content_length` | number | 응답 본문 바이트 수 |
| `content_type` | string | MIME 타입 (curl만) |
| `usable` | boolean | 노트 생성에 충분한 콘텐츠인지 |
| `reason` | string | usable=false일 때 사유 |
| `next` | string | 다음 시도할 방법 |
| `note` | string | 생성된 노트 파일명 (성공 시만) |
| `error` | string | 에러 메시지 (완전 실패 시만) |

**디버깅 명령어:**
```bash
grep '"usable":false' $VAULT/_logs/crawl.jsonl
grep '"platform":"threads"' $VAULT/_logs/crawl.jsonl
grep "$(date +%Y-%m-%d)" $VAULT/_logs/crawl.jsonl
grep '"next":"browser"' $VAULT/_logs/crawl.jsonl
```

### Text Memo Capture

Triggered by "저장해"/"캡처해"/"save" + text:
1. Extract the text after the trigger word
2. Generate: `title` (핵심 내용 반영, 15자 이내), `tags` (2-3개), `ai_summary` (1문장)
3. **Progressive Summarization**:
   - Layer 4: `> **Executive Summary**: {한 줄 핵심}` (노트 최상단)
   - Body: 원문 텍스트 그대로 + 짧은 구조화 (핵심 주장에 **볼드** 마킹)
   - 200자 이하 메모는 구조화 최소화 (핵심 주장, 시사점만)
4. **Vault Connections**: `grep -ril` 로 관련 기존 노트 검색 → `[[wikilink]]` 생성
5. `source_type: memo`, `source` 필드 없음, `content_hash` 필드 없음
6. `ai_distill_depth: 4`, `distill_layer: 0`
7. File: `$VAULT/inbox/YYYYMMDD-HHMMSS-slug.md` (slug from title)
8. Git commit + classification recommendation (same format as URL capture)
- See [references/note-template.md](references/note-template.md) for memo-specific format

**captured_via**: Set based on environment — NanoClaw container: check channel from CLAUDE.md (telegram, whatsapp, etc.). Claude Code local: `claude-code`.

### Processing Buffer

When processing a URL or batch:
1. Before starting: write `$VAULT/.processing_buffer` with the URL/task being processed
2. After completing: delete the buffer file
3. On session start: if `.processing_buffer` exists, a previous session crashed mid-processing — resume or report to user

### Git Rules

- Always `cd $VAULT` before git operations
- Commit message format: `capture: {title}`
- **Commit only, never push** — push는 10분 간격 스케줄 태스크가 담당 (see Gotchas)
- Before operations, `git pull --rebase` to sync (see Gotchas for conflict handling)

## Additional Resources

- For note format and Obsidian rules: see [references/note-template.md](references/note-template.md)
- For Progressive Summarization layers: see [references/distill-layers.md](references/distill-layers.md)
- For frontmatter schema and file naming: see [references/schema.md](references/schema.md)
- For platform-specific crawling instructions: see [references/platform-strategies.md](references/platform-strategies.md) — URL 크롤링 시 반드시 참조
