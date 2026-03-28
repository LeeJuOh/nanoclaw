# Second Brain CODE Redesign — Phase 1a Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the monolithic `second-brain` skill into two focused skills (`para-pipeline` for Capture+Distill, `para-brain` for Organize+Express) plus a SessionStart hook, implementing Phase 1a of the CODE redesign spec.

**Architecture:** Approach C (2-split by automation boundary). `para-pipeline` handles automatic Capture+Distill (URL→inbox, no user interaction). `para-brain` handles interactive Organize+Express (classification, search, reviews). `vault-context.sh` SessionStart hook injects vault awareness into every agent session (Express Ambient). Container-runner registers the hook in each container's `settings.json`.

**Tech Stack:** Node.js/TypeScript (container-runner), Markdown/YAML (SKILL.md, references), Bash (vault-context.sh), Vitest (unit tests), Claude Code evals (skill testing)

**Spec:** `docs/superpowers/specs/2026-03-22-second-brain-code-redesign.md`

**Spec deviations (검수 결과 반영):**
- **Express Pull → Phase 1a로 당김**: 스펙은 Phase 1b이지만, grep 기반 구현 비용이 낮고 없으면 "찾아줘" 요청에 응답 불가. 스펙 §4.4 Phase 테이블 업데이트 필요.
- **source_type 세분화**: 스펙은 `url | pdf | image | conversation`이지만, 플랫폼별 크롤링 전략 분기를 위해 `youtube | twitter | threads | ...`로 세분화. 스펙 §7.3 업데이트 필요.
- **Threads 셀프 리플라이**: 스펙에 미언급. platform-strategies.md에 수집 전략 추가.
- **Inbox 정리 유도**: 스펙의 "inbox > 10 threshold alert" 대신 일일 스케줄 넛지 (점심/퇴근)로 구현.
- **기존 노트 마이그레이션**: 스펙에 미언급. 96개 기존 노트의 frontmatter 정규화 태스크 추가.
- **파일 첨부 Phase 1a 안내**: 스펙은 PDF를 Phase 1b, 이미지를 Phase 1d로 연기. Phase 1a에서는 파일 첨부 감지 시 미지원 안내 메시지로 최소 UX 제공. Phase 1b 구현 시 `/add-second-brain` init에서 채널별 파일 인프라 셋업 (WhatsApp→기존 `/add-pdf-reader`, `/add-image-vision` 스킬 머지 유도, 텔레그램→파일 다운로드 코드 직접 추가). para-pipeline 자체는 워크스페이스에 도착한 파일만 처리 (채널 무관, NanoClaw 비의존).
- **Readability HTML 전처리**: 스펙에 미언급. curl 크롤링 결과를 Claude에 넘기기 전에 Readability 알고리즘으로 본문 추출하여 토큰 절약 + 품질 향상. `references/reader` 프로젝트의 Mozilla Readability + Turndown (HTML→MD) 패턴 참고.
- **크롤링 캐시**: 스펙에 미언급. crawl.jsonl 기반 단기 캐시(30분)로 재시도 시 불필요한 재크롤링 방지.

---

## File Structure

### New files to create

```
container/skills/para-pipeline/
  SKILL.md                         ← Capture + auto Distill skill (~350 lines)
  scripts/
    vault-context.sh               ← SessionStart hook: vault awareness injection (~20 lines)
  references/
    note-template.md               ← Updated: Progressive Summarization layers + wikilinks
    schema.md                      ← Updated: new frontmatter fields (ai_distill_depth, distill_layer, content_hash, related)
    platform-strategies.md         ← Copied unchanged from second-brain
    distill-layers.md              ← New: Progressive Summarization reference
  evals/
    evals.json                     ← Migrated capture evals + new Distill/hash/wikilink evals
    files/
      sample-vault-note-1.md       ← Copied from second-brain (updated frontmatter)
      sample-vault-note-2.md       ← Copied from second-brain
      sample-settings.yaml         ← Updated to object schema

container/skills/para-brain/
  SKILL.md                         ← Organize + Express Pull skill (~200 lines)
  references/
    para.md                        ← Copied unchanged from second-brain
    express-patterns.md            ← New: Express patterns reference
  evals/
    evals.json                     ← Migrated organize evals + new Reweave/Distill evals
    files/
      sample-vault-note-1.md       ← Copied from second-brain (updated frontmatter)
      sample-vault-note-2.md       ← Copied from second-brain
      sample-vault-note-3.md       ← New: classified note for Reweave testing
      sample-settings.yaml         ← Updated to object schema
```

### Files to modify

```
src/container-runner.ts            ← Add SessionStart hook registration logic
groups/telegram_second-brain/CLAUDE.md  ← Update skill references
```

### Files to delete (atomic swap)

```
container/skills/second-brain/     ← Entire directory (replaced by para-pipeline + para-brain)
```

### External file to migrate

```
/Users/ljo/Desktop/second_brain/_settings.yaml  ← Convert boolean → object schema
```

---

## Task 1: Create para-pipeline reference files

**Files:**
- Create: `container/skills/para-pipeline/references/schema.md`
- Create: `container/skills/para-pipeline/references/note-template.md`
- Create: `container/skills/para-pipeline/references/distill-layers.md`
- Copy: `container/skills/para-pipeline/references/platform-strategies.md`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p container/skills/para-pipeline/references
mkdir -p container/skills/para-pipeline/scripts
mkdir -p container/skills/para-pipeline/evals/files
```

- [ ] **Step 2: Write updated schema.md**

This file extends the current `container/skills/second-brain/references/schema.md` with new frontmatter fields from the spec §7.3.

```markdown
# Frontmatter Schema & File Naming

## Frontmatter (canonical)

\`\`\`yaml
---
title: "Note title"
source: "https://..." # omit for text memos
source_type: web # youtube | twitter | threads | github | reddit | medium | web | memo
# NOTE: 스펙(§7.3)은 source_type을 url | pdf | image | conversation으로 정의.
# 이 플랜에서는 크롤링 전략 분기를 위해 플랫폼별로 세분화함 (의도적 divergence).
# pdf/image/conversation은 Phase 1b+에서 추가 예정.
# 스펙 §7.3도 이에 맞게 업데이트 필요.
captured: 2026-03-15T14:30:00+09:00
processed: 2026-03-15T14:30:05+09:00 # omit if not yet processed
status: pending_review # raw | pending_review | classified | auto_classified
captured_via: telegram # telegram | whatsapp | slack | discord | claude-code
ai_distill_depth: 4 # AI가 생성한 최고 레이어 (캡처 시 항상 4)
distill_layer: 0 # 사용자가 확인/승인한 최고 레이어 (0=미확인, 1~4)
content_hash: "sha256:a1b2c3..." # 크롤링 본문 SHA-256 (중복 감지용, URL 캡처만)
contexts: # M:N PARA path references (logical grouping)
  - resources/ddd
  - projects/linkdive
tags: [ddd, architecture] # free keywords (not PARA paths)
related: # Reweave로 추가된 역연결
  - path: "resources/ddd/bounded-context.md"
    reason: "동일 도메인, 태그 겹침: aggregate, ddd"
    added: 2026-03-22
ai_summary: "2-3 sentence summary"
ai_suggested_category: "resources/ddd"
---
\`\`\`

## Field Semantics

- `source_type`: URL의 소스 플랫폼을 식별. 플랫폼에 따라 크롤링 전략이 달라진다:
  - `youtube` — youtube.com, youtu.be
  - `twitter` — twitter.com, x.com (트윗/스레드)
  - `threads` — threads.net, threads.com (Meta Threads)
  - `github` — github.com (레포, 이슈, PR, Discussion)
  - `reddit` — reddit.com (포스트 + 댓글)
  - `medium` — medium.com, *.medium.com, towardsdatascience.com
  - `web` — 위에 해당 안 되는 일반 웹페이지
  - `memo` — URL 없는 텍스트 메모
- `captured_via`: 캡처를 시작한 *채널* (telegram, whatsapp, slack, discord, claude-code). `source_type`과는 별개 — `source_type`은 URL의 플랫폼, `captured_via`는 사용자가 보낸 채널
- `contexts` = **where this note belongs** (PARA paths, M:N). First entry = physical location (matches file path), rest = logical connections
- `tags` = **what this note is about** (free keywords)
- `ai_distill_depth`: AI가 캡처 시 자동 생성한 최고 Distill 레이어. 현재는 항상 4 (Layer 1~4 일괄 생성). 향후 부분 Distill 시 변경 가능
- `distill_layer`: 사용자가 확인/승인한 최고 레이어. 캡처 직후 0 (미확인). 갱신 규칙:
  - `0 → 1`: 사용자가 분류를 실행했을 때 (inbox → PARA 경로 이동)
  - `1 → 2`: 사용자가 수동 Distill을 요청했을 때
  - `2 → 4`: 사용자가 Executive Summary를 직접 수정하거나 Layer 4 재정제를 요청했을 때
  - 자동 갱신 금지 — 반드시 사용자 액션에 의해서만 갱신
- `content_hash`: 크롤링된 본문의 SHA-256 해시 (`sha256:` 접두어). URL 캡처에서만 생성, 메모는 생략. 중복 감지 용도
- `related`: Reweave로 추가된 역연결. 각 엔트리에 `path` (노트 경로), `reason` (연결 사유), `added` (추가일) 포함
- Status transitions: `raw → pending_review → classified` (manual) or `raw → auto_classified` (auto, high confidence)
- In practice, capture + AI processing happen atomically, so `pending_review` is the initial write status. `raw` only occurs if processing fails mid-way.

## Backward Compatibility

- `ai_distill_depth` 없는 기존 노트: AI Distill 미수행으로 간주
- `distill_layer` 없는 기존 노트: 0 (미확인)으로 간주
- `content_hash` 없는 기존 노트: URL 기반 중복 감지만 사용
- `related` 없는 기존 노트: 역연결 없음으로 간주
- 기존 `ai_summary` 필드: 그대로 호환

## File Naming

`YYYYMMDD-HHMMSS-slug.md`
- Example: `20260315-143000-ux-research-methods.md`
- Timestamp: capture time (KST, +09:00)
- Slug: ASCII alphanumeric + hyphens, max 60 chars
- Korean titles: extract English keywords or date-based fallback (see Gotchas in SKILL.md)

## Crawl Log (`$VAULT/_logs/crawl.jsonl`)

JSONL 형식. 한 줄 = 한 크롤링 시도. 같은 URL에 대해 여러 시도(curl → browser 등)가 있으면 각각 별도 줄.

\`\`\`json
{
  "ts": "2026-03-22T14:30:00+09:00",
  "url": "https://x.com/user/status/123",
  "platform": "twitter",
  "method": "curl | browser | api",
  "http_status": 200,
  "content_length": 847,
  "content_type": "text/html",
  "usable": false,
  "reason": "JS-only shell, <1KB readable content",
  "next": "browser | api | manual",
  "note": "20260322-143010-slug.md",
  "error": "에러 메시지 (완전 실패 시)"
}
\`\`\`

필수 필드: `ts`, `url`, `platform`, `method`, `usable`
조건부 필드: `http_status`(curl만), `content_type`(curl만), `reason`(usable=false), `next`(fallback 있을 때), `note`(성공 시), `error`(완전 실패 시)
```

- [ ] **Step 3: Write updated note-template.md**

This file extends the current template with Progressive Summarization layers (bold/highlight/executive summary) and `[[wikilink]]` conventions.

```markdown
# Note Format & Obsidian Rules

Read this when creating or modifying notes in the vault.

## URL Capture Note Format

\`\`\`markdown
---
title: "{title}"
source: "{url}"
source_type: web
captured: YYYY-MM-DDTHH:MM:SS+09:00
processed: YYYY-MM-DDTHH:MM:SS+09:00
status: pending_review
ai_distill_depth: 4
distill_layer: 0
content_hash: "sha256:{hash}"
tags: [{tag1}, {tag2}, ...]
contexts: []
ai_summary: "{2-3문장 요약}"
ai_suggested_category: "{resources/topic}"
captured_via: telegram
---

> **Executive Summary**: {한 줄 핵심 요약 — Layer 4}

# {title}

*출처*: {author/platform} | {date}

---

## 핵심 주장

- **{주장 1}**: {맥락과 함께 설명}
- **{주장 2}**: {맥락과 함께 설명}

## 주요 논거 및 근거

- {증거/데이터/사례 1}
- ==가장 핵심적인 증거나 데이터는 하이라이트==

## 인사이트

{기존 통념과 다른 시각, 놓치기 쉬운 포인트, 주목할 만한 점}

## 실용적 시사점

- **{행동으로 옮길 수 있는 것 1}**
- {행동으로 옮길 수 있는 것 2}

## 한계 및 열린 질문

- {저자가 다루지 않은 부분}
- {추가 탐구가 필요한 질문}

## 볼트 연결

- [[기존노트제목]] — {연결 사유}
\`\`\`

### Progressive Summarization Layers

캡처 시 AI가 Layer 1~4를 한 번에 자동 생성한다. 자세한 가이드는 [distill-layers.md](distill-layers.md) 참조.

- **Layer 1 (토양)**: 전체 원본 텍스트 (노트 본문 전체)
- **Layer 2 (기름)**: 핵심 문장을 `**볼드**`로 마킹 (본문 전체에 걸쳐)
- **Layer 3 (금)**: 볼드 중 최핵심을 `==하이라이트==`로 마킹 (노트당 2-3개)
- **Layer 4 (보석)**: `> **Executive Summary**: ...` 블록으로 한 줄 요약 (노트 최상단)

### `[[wikilink]]` 규칙

- 볼트 내 기존 노트와 연결할 때 `[[노트제목]]` 사용
- 볼트 연결 섹션: `[[폴더/파일명|표시텍스트]] — 연결 사유` 형식
- AI가 캡처 시 `grep -ril` 로 관련 기존 노트를 찾아 wikilink 생성
- 관련 노트가 없으면 볼트 연결 섹션 생략

## Text Memo Note Format

\`\`\`markdown
---
title: "{auto-generated from content}"
source_type: memo
captured: YYYY-MM-DDTHH:MM:SS+09:00
processed: YYYY-MM-DDTHH:MM:SS+09:00
status: pending_review
ai_distill_depth: 4
distill_layer: 0
tags: [{tag1}, {tag2}]
contexts: []
ai_summary: "{1문장 요약}"
ai_suggested_category: "{category}"
captured_via: telegram
---

> **Executive Summary**: {한 줄 핵심}

# {title}

{원문 텍스트}

---

## 핵심 주장

- **{메모에서 추출한 핵심 아이디어}**

## 실용적 시사점

- {행동으로 옮길 수 있는 것}

## 볼트 연결

- [[관련노트]] — {연결 사유}
\`\`\`

Differences from URL capture:
- No `source` field
- No `content_hash` field (메모는 크롤링이 아니므로)
- `source_type: memo`
- Title auto-generated (15자 이내, 핵심 반영)
- Body: 원문 텍스트 먼저, 구조화 분석은 뒤에
- 200자 이하 짧은 메모: 핵심 주장 + 시사점만 (다른 섹션 생략)
- 볼트 연결은 관련 노트가 있을 때만

## Analysis Depth Guideline

콘텐츠 길이에 비례하여 분석 깊이를 조절한다:
- **짧은 콘텐츠** (~500자 이하, 트윗/짧은 스레드): 핵심 주장 + 인사이트 + 시사점 위주로 간결하게. 하이라이트(Layer 3) 1개면 충분
- **긴 아티클/논문**: 모든 섹션을 충실히 작성. 하이라이트 2-3개
- **짧은 메모** (~200자 이하): 핵심 주장 + 시사점만. 하이라이트 생략 가능
- 빈 섹션은 생략

## Obsidian Compatibility Rules

- **Links**: 볼트 내부 노트 연결 시 반드시 옵시디언 wikilink `[[노트이름]]` 사용. 외부 URL은 마크다운 링크 `[텍스트](url)` 사용
  - 같은 폴더: `[[파일명]]` (확장자 생략)
  - 다른 폴더: `[[폴더/파일명]]` (볼트 루트 기준 상대 경로)
  - 표시 텍스트 변경: `[[파일명|표시할 텍스트]]`
  - 이미지 임베드: `![[이미지파일.png]]`
- **Tags**: frontmatter YAML 배열 `tags: [tag1, tag2]` 사용. 본문에서 인라인 태그 `#tag` 사용하지 않음
- **Frontmatter**: YAML `---` 블록으로 감싸고, 옵시디언이 인식하는 필드(title, tags, aliases) 포함. 커스텀 필드(ai_summary, contexts 등)도 옵시디언 Properties에서 표시됨
- **File names**: ASCII 알파벳 + 하이픈 + 숫자. 특수문자(`/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`) 사용 금지
- **contexts vs tags**: `contexts`는 PARA 폴더 경로(구조적 소속), `tags`는 자유 키워드. 역할이 다르므로 둘 다 유지
- **Highlight marker**: `==텍스트==`는 Obsidian에서 네이티브 렌더링됨. 에이전트가 검색/분석 시 `==`를 하이라이트 마커로 인식할 것
```

- [ ] **Step 4: Write new distill-layers.md**

```markdown
# Progressive Summarization — Distill Layers

캡처 시 AI가 4개 레이어를 한 번에 생성하는 가이드. para-pipeline(자동 Distill)과 para-brain(수동 재정제) 양쪽에서 참조.

## Layer 정의

| Layer | 이름 | 마커 | 위치 | 설명 |
|-------|------|------|------|------|
| 1 | 토양 (Soil) | 없음 | 노트 본문 전체 | 원본 콘텐츠를 구조화한 전체 분석 |
| 2 | 기름 (Oil) | `**볼드**` | 본문 전체에 걸쳐 | 핵심 문장을 볼드 마킹 |
| 3 | 금 (Gold) | `==하이라이트==` | 볼드 중 선택 | 최핵심 구절 (노트당 2-3개) |
| 4 | 보석 (Gem) | `> **Executive Summary**:` | 노트 최상단 | 한 줄 핵심 요약 |

## 자동 Distill (캡처 시)

para-pipeline이 캡처할 때 Layer 1~4를 한 번에 생성:

1. **Layer 1**: 본문 전체를 구조화 분석 (핵심 주장, 논거, 인사이트, 시사점, 한계)
2. **Layer 2**: 분석 과정에서 핵심 문장을 `**볼드**`로 마킹 — 섹션별 1-2개
3. **Layer 3**: 볼드 중 가장 인사이트가 큰 구절을 `==하이라이트==`로 마킹 — 전체 노트에서 2-3개
4. **Layer 4**: 노트 최상단에 `> **Executive Summary**: {한 줄 핵심}` 추가

생성 후 frontmatter: `ai_distill_depth: 4`, `distill_layer: 0` (사용자 미확인)

## 수동 재정제 (para-brain)

사용자가 "이 노트 다시 정리해줘" / "핵심만 뽑아줘" 요청 시:

1. 현재 `distill_layer` 확인
2. Layer 2~4를 재생성 (AI가 다시 볼드/하이라이트/요약 수행)
3. `distill_layer` 갱신 (1→2 또는 2→4)

## 콘텐츠 길이별 적용

- **짧은 콘텐츠** (~500자): Layer 3 하이라이트 1개, Executive Summary 간결하게
- **긴 아티클**: Layer 3 하이라이트 2-3개, Executive Summary 충실하게
- **짧은 메모** (~200자): Layer 3 생략 가능, Executive Summary만

## 마커 파싱 가이드

- `**볼드**`: 표준 Markdown, 모든 파서 지원
- `==하이라이트==`: Obsidian 전용 구문. Markdown 표준 아님. 검색/분석 시 `==`를 하이라이트 마커로 인식할 것
- `> **Executive Summary**:`: blockquote 안의 볼드. 노트 최상단(frontmatter 다음 첫 줄)에 위치
```

- [ ] **Step 5: Copy and extend platform-strategies.md**

```bash
cp container/skills/second-brain/references/platform-strategies.md \
   container/skills/para-pipeline/references/platform-strategies.md
```

After copying, **append** the following to the Threads section in the copied file. This addresses the critical gap where Threads self-replies (author continuing content in their own replies) are not captured. Pattern inspired by `references/last30days-skill/scripts/lib/reddit_enrich.py` (Search+Enrich 2-phase architecture).

```markdown
### Threads 셀프 리플라이 수집

Threads 특성상 원작자가 첫 글은 짧게 쓰고 자기 리플라이로 본문을 이어가는
패턴이 빈번함. 원글만 캡처하면 핵심 콘텐츠의 상당 부분이 유실됨.

**크롤링 전략 (agent-browser):**
1. 원글 페이지 로드
2. **셀프 리플라이 감지**: 리플라이 섹션에서 원작자(같은 @핸들)의 리플라이 확인
   - "View replies" / "답글 보기" 버튼 클릭
   - 리플라이 작성자 핸들 ↔ 원글 작성자 핸들 비교
3. **원작자 리플라이만 수집**: 타인 댓글은 제외 — 원작자의 콘텐츠 연장만 해당
4. 병합 순서: 원글 → 셀프 리플라이 1 → 셀프 리플라이 2 → ...
5. 노트 본문에 구분 표시: `---` (구분선) + `*셀프 리플라이 {N}*` 라벨
6. 셀프 리플라이가 없으면 원글만으로 노트 생성 (기존 동작)

**실패 시 (로그인 벽):**
- 사용자에게 안내: "원글 + 셀프 리플라이를 함께 복사해서 보내주세요"
- 크롤 로그: `reason: "login_required, self_replies_not_crawled"`
```

Also add a **수집 범위 요약** section at the end of the file to make crawl depth explicit per platform:

```markdown
## 플랫폼별 수집 범위 요약

| 플랫폼 | 수집 범위 | 미수집 |
|--------|----------|--------|
| YouTube | 메타데이터 + 자막/트랜스크립트 | 댓글, 챕터 |
| Twitter/X | 원글 + 같은 작성자 전체 스레드 + 인용 트윗 | 타인 리플라이 |
| Threads | 원글 + **같은 작성자 셀프 리플라이** | 타인 댓글 |
| GitHub | README + 레포 메타 (이슈/PR은 본문만) | PR 리뷰 스레드, 링크된 이슈 |
| Reddit | 포스트 본문 + 상위 5개 댓글 | 전체 댓글 트리, 하위 댓글 |
| Medium | 전체 아티클 본문 | 댓글, 하이라이트 |
| Web | 메인 콘텐츠 | 사이드바, 광고, 댓글 |
```

- [ ] **Step 6: Verify reference files**

```bash
ls -la container/skills/para-pipeline/references/
```

Expected: `schema.md`, `note-template.md`, `distill-layers.md`, `platform-strategies.md` — 4 files.

- [ ] **Step 7: Commit**

```bash
git add container/skills/para-pipeline/references/
git commit -m "feat(para-pipeline): add reference files for capture+distill skill

Updated schema.md with new frontmatter fields (ai_distill_depth,
distill_layer, content_hash, related). Updated note-template.md with
Progressive Summarization layers and wikilink conventions. Added new
distill-layers.md reference. Copied platform-strategies.md unchanged."
```

---

## Task 2: Write para-pipeline SKILL.md

**Files:**
- Create: `container/skills/para-pipeline/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

```markdown
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
7. **Duplicate Check (content_hash)**: 크롤링된 본문의 SHA-256을 계산하고, `grep -rl "content_hash: \"sha256:{hash}\"" $VAULT/`로 기존 노트와 비교. 일치하면 "같은 콘텐츠가 이미 있어요: {existing title} ({path}). URL은 다르지만 본문이 동일합니다." 안내하고 중단
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
\`\`\`bash
mkdir -p "$VAULT/_logs"
echo '<json>' >> "$VAULT/_logs/crawl.jsonl"
\`\`\`

**로그 스키마** (한 줄 = 한 크롤링 시도):
\`\`\`json
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
\`\`\`

같은 URL에 대해 여러 시도가 있으면 각각 별도 줄로 기록. 최종 성공 시:
\`\`\`json
{
  "ts": "2026-03-22T14:30:08+09:00",
  "url": "https://x.com/user/status/123",
  "platform": "twitter",
  "method": "browser",
  "content_length": 34500,
  "usable": true,
  "note": "20260322-143010-tweet-ddd-insight.md"
}
\`\`\`

완전 실패 시 (노트 생성 불가):
\`\`\`json
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
\`\`\`

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
\`\`\`bash
grep '"usable":false' $VAULT/_logs/crawl.jsonl
grep '"platform":"threads"' $VAULT/_logs/crawl.jsonl
grep "$(date +%Y-%m-%d)" $VAULT/_logs/crawl.jsonl
grep '"next":"browser"' $VAULT/_logs/crawl.jsonl
\`\`\`

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
```

- [ ] **Step 2: Verify line count**

```bash
wc -l container/skills/para-pipeline/SKILL.md
```

Expected: ~200-250 lines (tighter than original 373 because classification/organize sections removed).

- [ ] **Step 3: Commit**

```bash
git add container/skills/para-pipeline/SKILL.md
git commit -m "feat(para-pipeline): add capture+distill skill

Implements Capture+Distill pipeline from CODE redesign spec §4.5.
Key additions over old second-brain skill:
- Progressive Summarization (Layer 1-4 auto-generation)
- content_hash SHA-256 duplicate detection
- [[wikilink]] generation for vault connections
- Vault guard (description + early return)
- Classification logic removed (now in para-brain)"
```

---

## Task 3: Create vault-context.sh SessionStart hook

**Files:**
- Create: `container/skills/para-pipeline/scripts/vault-context.sh`

- [ ] **Step 1: Write vault-context.sh**

```bash
#!/bin/bash
# para-pipeline/scripts/vault-context.sh
# SessionStart hook — injects vault awareness into every agent session (Express Ambient)
# Registered via container-runner.ts in settings.json hooks.SessionStart
VAULT="${VAULT:-/workspace/extra/vault}"
if [ -d "$VAULT" ]; then
  TOTAL=$(find "$VAULT" -name '*.md' ! -name '_*' | wc -l | tr -d ' ')
  INBOX=$(find "$VAULT/inbox" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  PARA_DIRS=$(find "$VAULT" -mindepth 1 -maxdepth 2 -type d ! -name '.*' ! -name inbox ! -name _logs | head -20 | sed "s|$VAULT/||" | tr '\n' ', ')
  RECENT_TAGS=$(grep -rh '^tags:' "$VAULT/inbox/" 2>/dev/null | sed 's/tags: *\[//;s/\]//;s/, /\n/g' | sort | uniq -c | sort -rn | head -10 | awk '{print $2}' | tr '\n' ', ')

  cat <<CONTEXT
[Vault Awareness] 이 그룹에 지식 저장소(vault)가 있습니다.
경로: $VAULT
노트 수: ${TOTAL}개 (inbox: ${INBOX}개)
PARA 경로: ${PARA_DIRS%,}
최근 빈출 태그: ${RECENT_TAGS%,}
질문에 답할 때 \`grep -ril "키워드" $VAULT/\`로 관련 노트를 먼저 찾아보세요.
관련 노트가 있으면 인용해서 답변하고, 없으면 일반 지식으로 답변하세요.
vault 결과와 일반 지식을 명확히 구분해서 제시하세요.
CONTEXT
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x container/skills/para-pipeline/scripts/vault-context.sh
```

- [ ] **Step 3: Verify script runs without error**

```bash
VAULT=/Users/ljo/Desktop/second_brain bash container/skills/para-pipeline/scripts/vault-context.sh
```

Expected: Output starting with `[Vault Awareness]` followed by vault stats.

- [ ] **Step 4: Commit**

```bash
git add container/skills/para-pipeline/scripts/vault-context.sh
git commit -m "feat(para-pipeline): add vault-context.sh SessionStart hook

Express Ambient implementation — injects vault stats (note count,
PARA paths, frequent tags) into every agent session start.
Skips silently when vault path doesn't exist."
```

---

## Task 4: Write para-pipeline evals

**Files:**
- Create: `container/skills/para-pipeline/evals/evals.json`
- Create: `container/skills/para-pipeline/evals/files/sample-vault-note-1.md`
- Create: `container/skills/para-pipeline/evals/files/sample-vault-note-2.md`
- Create: `container/skills/para-pipeline/evals/files/sample-settings.yaml`

- [ ] **Step 1: Copy sample files from existing skill and update**

```bash
cp container/skills/second-brain/evals/files/sample-vault-note-2.md \
   container/skills/para-pipeline/evals/files/sample-vault-note-2.md
```

- [ ] **Step 2: Write updated sample-vault-note-1.md with new frontmatter fields**

```markdown
---
title: "Domain-Driven Design의 Aggregate 패턴"
source: "https://martinfowler.com/bliki/DDD_Aggregate.html"
source_type: web
captured: 2026-03-10T14:30:00+09:00
processed: 2026-03-10T14:30:05+09:00
status: classified
ai_distill_depth: 4
distill_layer: 1
content_hash: "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
captured_via: telegram
contexts:
  - resources/ddd-patterns
tags: [ddd, aggregate, domain-modeling, consistency-boundary]
related: []
ai_summary: "Aggregate는 트랜잭션 일관성 경계를 정의하는 DDD의 핵심 전술 패턴. Entity와 Value Object의 클러스터로 구성되며, 외부에서는 Aggregate Root를 통해서만 접근해야 한다."
ai_suggested_category: "resources/ddd-patterns"
---

> **Executive Summary**: Aggregate는 트랜잭션 경계를 정의하는 DDD 핵심 패턴으로, 작게 유지하고 ID 참조로 연결하는 것이 실전 핵심.

# Domain-Driven Design의 Aggregate 패턴

*출처*: Martin Fowler | 2026-03-10

---

## 핵심 주장

- **Aggregate는 트랜잭션 일관성 경계를 정의하는 클러스터**: 하나의 트랜잭션에서 하나의 Aggregate만 수정해야 한다
- **외부 참조는 Aggregate Root를 통해서만**: 내부 Entity에 직접 접근하면 일관성이 깨진다

## 주요 논거 및 근거

- Aggregate를 작게 유지해야 ==동시성 충돌이 줄어든다==
- 다른 Aggregate는 ID로만 참조 — 객체 참조 금지

## 인사이트

DDD에서 가장 흔한 실수는 Aggregate를 너무 크게 잡는 것. 거대한 Aggregate는 락 경합의 원인이 된다.

## 실용적 시사점

- **하나의 트랜잭션 = 하나의 Aggregate 수정** 원칙을 준수
- Aggregate 간에는 ID 참조만 사용

## 한계 및 열린 질문

- 어디까지가 "하나의 트랜잭션"인지 도메인마다 다름
- 이벤추얼 컨시스턴시와의 트레이드오프
```

- [ ] **Step 3: Write updated sample-settings.yaml**

```yaml
auto_classify:
  enabled: false
  trigger: on_capture
```

- [ ] **Step 4: Write evals.json**

Write the complete eval file with migrated capture evals plus new evals for Progressive Summarization, content_hash dedup, wikilinks, and Threads self-reply.

**Eval migration mapping (기존 → 신규):**

| 기존 ID | 내용 | → 신규 스킬 | 신규 ID |
|---------|------|------------|---------|
| 1 | URL capture | para-pipeline | #1 (확장: Progressive Summarization, wikilinks) |
| 2 | Duplicate URL | para-pipeline | #2 |
| 6 | Text memo | para-pipeline | #4 |
| 9 | Twitter/X | para-pipeline | #5 |
| 10 | Threads failure | para-pipeline | #6 |
| 11 | YouTube | para-pipeline | #7 |
| 12 | Crawl diagnostics | para-pipeline | #8 |
| — | (new) content_hash dedup | para-pipeline | #3 |
| — | (new) Threads self-reply | para-pipeline | #9 |
| 3 | Archive deletion | para-brain | #3 |
| 4 | Manual move | para-brain | #1 |
| 5 | Vault search | para-brain | #4 |
| 7 | Weekly review | para-brain | #5 |
| 8 | Auto-classify | para-brain | #7 |
| — | (new) Reweave bidirectional | para-brain | #2 |
| — | (new) Manual Distill | para-brain | #6 |

```json
{
  "skill_name": "para-pipeline",
  "evals": [
    {
      "id": 1,
      "prompt": "You are the para-pipeline capture agent. The vault is at ./test-vault/ (already set up with PARA structure and the sample notes below).\n\nExisting vault contents:\n- resources/ddd-patterns/20260310-143000-ddd-aggregate-pattern.md (see sample-vault-note-1.md)\n- inbox/20260312-100000-react-server-components-guide.md (see sample-vault-note-2.md)\n- _settings.yaml (see sample-settings.yaml)\n- Existing PARA subfolders: resources/ddd-patterns/, areas/frontend/\n\nUser message: https://martinfowler.com/bliki/ValueObject.html\n\nSimulate the capture pipeline. Create the note file content (frontmatter + deep analysis body with Progressive Summarization) and the classification recommendation message. Do NOT actually run curl — instead use this as the crawled content:\n\n\"A Value Object is a small object that represents a simple entity whose equality is not based on identity. Two Value Objects are equal when they have the same value, not necessarily being the same object. Examples include Money, Date Range, and Address. Value Objects should be immutable. In DDD, Value Objects are often used within Aggregates to model concepts that don't need their own identity. They simplify the model by reducing the number of Entities.\"",
      "expected_output": "A markdown note with correct frontmatter (including ai_distill_depth: 4, distill_layer: 0, content_hash) plus a structured body with Progressive Summarization (bold, highlights, Executive Summary) and wikilink to the existing DDD Aggregate note.",
      "files": [
        "evals/files/sample-vault-note-1.md",
        "evals/files/sample-vault-note-2.md",
        "evals/files/sample-settings.yaml"
      ],
      "expectations": [
        "Note frontmatter includes ai_distill_depth: 4 and distill_layer: 0",
        "Note frontmatter includes content_hash with sha256: prefix",
        "Note body starts with > **Executive Summary**: line (Layer 4)",
        "Note body contains **bold** text marking key claims (Layer 2)",
        "Note body contains ==highlight== text marking the most critical insight (Layer 3)",
        "볼트 연결 section contains [[wikilink]] referencing the existing DDD Aggregate note",
        "File name follows YYYYMMDD-HHMMSS-slug.md pattern with ASCII-only slug",
        "Classification recommendation labels resources/ddd-patterns as (기존)",
        "Describes writing a crawl log entry to $VAULT/_logs/crawl.jsonl"
      ]
    },
    {
      "id": 2,
      "prompt": "You are the para-pipeline capture agent. The vault is at ./test-vault/.\n\nExisting vault contents:\n- resources/ddd-patterns/20260310-143000-ddd-aggregate-pattern.md (has source: \"https://martinfowler.com/bliki/DDD_Aggregate.html\")\n- inbox/20260312-100000-react-server-components-guide.md\n\nUser message: https://martinfowler.com/bliki/DDD_Aggregate.html\n\nThis URL has already been captured. Demonstrate the duplicate detection behavior.",
      "expected_output": "Agent detects the duplicate URL and replies with existing note info. Does NOT create a new note.",
      "files": [
        "evals/files/sample-vault-note-1.md"
      ],
      "expectations": [
        "Agent detects the URL is already captured by matching the normalized URL",
        "Reply includes the existing note title and its path",
        "Agent does NOT create a new note file"
      ]
    },
    {
      "id": 3,
      "prompt": "You are the para-pipeline capture agent. The vault is at ./test-vault/.\n\nExisting vault contents:\n- resources/ddd-patterns/20260310-143000-ddd-aggregate-pattern.md (content_hash: \"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\")\n\nUser message: https://example.com/ddd-aggregate-repost\n\nSimulate: This is a DIFFERENT URL but the crawled content is identical to the existing note (same text about DDD Aggregates). The computed SHA-256 hash of the crawled body matches the existing note's content_hash. Demonstrate content_hash duplicate detection.",
      "expected_output": "Agent detects the content_hash duplicate despite different URL. Informs user that identical content already exists at existing path.",
      "files": [
        "evals/files/sample-vault-note-1.md"
      ],
      "expectations": [
        "Agent computes or simulates content_hash of crawled body",
        "Agent searches for matching content_hash in existing vault notes",
        "Agent detects duplicate via content_hash match (not URL match)",
        "Reply mentions that the URL is different but content is identical",
        "Reply includes the existing note path",
        "Agent does NOT create a new note"
      ]
    },
    {
      "id": 4,
      "prompt": "You are the para-pipeline capture agent. The vault is at ./test-vault/.\n\nExisting vault contents:\n- resources/ddd-patterns/20260310-143000-ddd-aggregate-pattern.md\n- areas/frontend/ (has notes)\n\nUser message: 저장해 — 마이크로서비스에서 Saga 패턴은 분산 트랜잭션의 대안이다. 각 서비스가 로컬 트랜잭션을 실행하고, 실패 시 보상 트랜잭션으로 롤백한다. Choreography(이벤트 기반)와 Orchestration(중앙 조율) 두 가지 방식이 있다.",
      "expected_output": "Text memo capture with Progressive Summarization layers, no source field, no content_hash.",
      "files": [
        "evals/files/sample-vault-note-1.md"
      ],
      "expectations": [
        "Note has source_type: memo and NO source URL field",
        "Note has NO content_hash field (memos don't have crawled content)",
        "Note has ai_distill_depth: 4 and distill_layer: 0",
        "Note body starts with > **Executive Summary**: line",
        "Note body contains the original text as-is",
        "Note body has **bold** marking on key claims",
        "File name follows YYYYMMDD-HHMMSS-slug.md pattern",
        "Classification recommendation is provided"
      ]
    },
    {
      "id": 5,
      "prompt": "You are the para-pipeline capture agent. The vault is at ./test-vault/.\n\nExisting vault contents:\n- resources/ddd-patterns/ (has notes)\n- areas/frontend/ (has notes)\n\nUser message: https://x.com/kelseyhightower/status/1234567890\n\nSimulate: curl returns JS shell (847 bytes, <noscript> only). agent-browser returns:\n\n\"The best way to learn Kubernetes is to break it. Deploy something, watch it fail, read the logs, fix it. Repeat. Books and courses give you knowledge. Breaking things gives you understanding.\"\n\nSingle tweet (not a thread). Show complete pipeline with Progressive Summarization.",
      "expected_output": "Twitter capture with platform detection, crawl logging, Progressive Summarization layers, and content_hash.",
      "files": [],
      "expectations": [
        "Agent detects platform as twitter from x.com URL",
        "Note frontmatter has source_type: twitter",
        "Note frontmatter has ai_distill_depth: 4, distill_layer: 0, content_hash",
        "Note body starts with > **Executive Summary**: line",
        "Agent describes logging curl attempt (usable: false) and browser attempt (usable: true) to crawl.jsonl",
        "Crawl log entries include platform: twitter"
      ]
    },
    {
      "id": 6,
      "prompt": "You are the para-pipeline capture agent. The vault is at ./test-vault/.\n\nExisting vault contents:\n- resources/ddd-patterns/ (has notes)\n\nUser message: https://www.threads.com/@techleader/post/ABC123\n\nSimulate: curl returns empty HTML (login wall). agent-browser gets redirected to Threads home feed (invalid_post). Content could not be retrieved.",
      "expected_output": "Agent logs both failures and asks user to copy-paste the content as text.",
      "files": [],
      "expectations": [
        "Agent detects platform as threads",
        "Agent describes logging curl attempt with usable: false, reason mentioning login wall",
        "Agent describes logging browser attempt with usable: false, reason mentioning redirect",
        "Browser crawl log has next: manual",
        "Agent asks user to copy-paste content as text for memo capture",
        "Agent does NOT create a note file"
      ]
    },
    {
      "id": 7,
      "prompt": "You are the para-pipeline capture agent. The vault is at ./test-vault/.\n\nExisting vault contents:\n- areas/ai-engineering/ (has notes)\n\nUser message: https://www.youtube.com/watch?v=dQw4w9WgXcQ\n\nSimulate: curl returns HTML with og:title: \"Understanding Transformer Architecture\", og:description: \"In this video, we explore the transformer architecture...\", Channel: \"AI Engineering Hub\", Published: 2026-03-15. yt-dlp is NOT available.",
      "expected_output": "YouTube capture from metadata only, with Progressive Summarization layers.",
      "files": [],
      "expectations": [
        "Agent detects platform as youtube",
        "Note frontmatter has source_type: youtube, ai_distill_depth: 4, distill_layer: 0",
        "Note body starts with > **Executive Summary**: line",
        "Agent notes yt-dlp is unavailable and proceeds without transcript",
        "Classification recommendation suggests areas/ai-engineering as (기존)"
      ]
    },
    {
      "id": 8,
      "prompt": "You are the para-pipeline capture agent. The vault is at ./test-vault/ with _logs/ directory.\n\nUser message: 최근에 크롤링 실패한 URL들 보여줘\n\nSimulate: $VAULT/_logs/crawl.jsonl exists with these entries:\n{\"ts\":\"2026-03-20T10:00:00+09:00\",\"url\":\"https://threads.com/@user1/post/XYZ\",\"platform\":\"threads\",\"method\":\"curl\",\"http_status\":200,\"content_length\":423,\"usable\":false,\"reason\":\"login wall, empty content\",\"next\":\"browser\"}\n{\"ts\":\"2026-03-20T10:00:05+09:00\",\"url\":\"https://threads.com/@user1/post/XYZ\",\"platform\":\"threads\",\"method\":\"browser\",\"content_length\":0,\"usable\":false,\"reason\":\"invalid_post redirect to home feed\",\"next\":\"manual\",\"error\":\"사용자에게 텍스트 복붙 안내\"}\n{\"ts\":\"2026-03-21T14:30:00+09:00\",\"url\":\"https://x.com/someone/status/999\",\"platform\":\"twitter\",\"method\":\"browser\",\"content_length\":28500,\"usable\":true,\"note\":\"20260321-143010-kubernetes-insight.md\"}\n{\"ts\":\"2026-03-22T09:00:00+09:00\",\"url\":\"https://medium.com/@author/great-article\",\"platform\":\"medium\",\"method\":\"curl\",\"http_status\":200,\"content_length\":890,\"usable\":false,\"reason\":\"paywall, content truncated\",\"next\":\"browser\"}\n{\"ts\":\"2026-03-22T09:00:08+09:00\",\"url\":\"https://medium.com/@author/great-article\",\"platform\":\"medium\",\"method\":\"browser\",\"content_length\":15200,\"usable\":true,\"note\":\"20260322-090015-great-article.md\"}",
      "expected_output": "Agent reads crawl.jsonl, filters failures, summarizes patterns by platform.",
      "files": [],
      "expectations": [
        "Agent reads $VAULT/_logs/crawl.jsonl for failed entries",
        "Identifies failed crawl attempts (Threads, Medium curl)",
        "Notes Threads 100% failure rate",
        "Notes Medium curl failed but browser succeeded",
        "Presents results in readable format",
        "Does NOT attempt to re-crawl"
      ]
    },
    {
      "id": 9,
      "prompt": "You are the para-pipeline capture agent. The vault is at ./test-vault/.\n\nExisting vault contents:\n- resources/ddd-patterns/ (has notes)\n\nUser message: https://www.threads.net/@unclejobs.ai/post/ABC123\n\nSimulate: agent-browser successfully loads the page. Content found:\n- Original post by @unclejobs.ai: \"Claude Code 3.0 업데이트 요약\" (80자, 개요만)\n- Self-reply 1 by @unclejobs.ai: \"먼저 가장 큰 변화는 멀티 에이전트 지원입니다. 각 에이전트가 독립 컨텍스트를 갖고...\" (350자)\n- Self-reply 2 by @unclejobs.ai: \"두 번째로 MCP 서버 자동 탐색 기능이 추가됐어요. 프로젝트 루트에...\" (300자)\n- Self-reply 3 by @unclejobs.ai: \"마지막으로 성능 개선. 토큰 사용량이 40% 줄었고...\" (200자)\n- Comment by @otheruser: \"와 대박\" (10자)\n- Comment by @anotheruser: \"감사합니다\" (15자)\n\nShow complete pipeline with self-reply merging and Progressive Summarization.",
      "expected_output": "Agent merges original + 3 self-replies into single note, excludes other users' comments, applies Progressive Summarization to merged content.",
      "files": [],
      "expectations": [
        "Agent detects platform as threads from threads.net URL",
        "Agent identifies and collects self-replies by @unclejobs.ai (same author as original)",
        "Agent excludes comments by @otheruser and @anotheruser (different authors)",
        "Note body contains merged content: original + 3 self-replies in order",
        "Self-replies are visually separated in note body (--- divider or label)",
        "Progressive Summarization applied to FULL merged content (not just original)",
        "Note frontmatter has source_type: threads, ai_distill_depth: 4, distill_layer: 0",
        "Crawl log entry includes platform: threads, usable: true",
        "Classification recommendation is provided"
      ]
    }
  ]
}
```

- [ ] **Step 5: Commit**

```bash
git add container/skills/para-pipeline/evals/
git commit -m "test(para-pipeline): add eval suite

9 evals: URL capture with Progressive Summarization (1), URL dedup (2),
content_hash dedup (3), text memo capture (4), Twitter capture (5),
Threads failure (6), YouTube capture (7), crawl diagnostics (8),
Threads self-reply merging (9)."
```

---

## Task 5: Create para-brain directory and reference files

**Files:**
- Create: `container/skills/para-brain/references/para.md`
- Create: `container/skills/para-brain/references/express-patterns.md`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p container/skills/para-brain/references
mkdir -p container/skills/para-brain/evals/files
```

- [ ] **Step 2: Copy para.md unchanged**

```bash
cp container/skills/second-brain/references/para.md \
   container/skills/para-brain/references/para.md
```

- [ ] **Step 3: Write new express-patterns.md**

```markdown
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
```

- [ ] **Step 4: Commit**

```bash
git add container/skills/para-brain/references/
git commit -m "feat(para-brain): add reference files for organize+express skill

Copied para.md unchanged. Added express-patterns.md with Pull/Ambient/Push
strategies and grep-based search patterns for Phase 1a."
```

---

## Task 6: Write para-brain SKILL.md

**Files:**
- Create: `container/skills/para-brain/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

```markdown
---
name: para-brain
description: >
  Interactive knowledge organization and retrieval for a PARA vault.
  Classifies notes (manual/auto), manages PARA categories, performs Reweave
  (bidirectional linking), manual Distill (re-summarization), vault search,
  and weekly reviews. Only use this skill when the vault path
  ($VAULT or /workspace/extra/vault) exists.
  Triggers on "분류", "정리", "아카이브", "검색", "찾아", "주간 리뷰",
  "프로젝트 만들어", "미분류", "자동분류", "다시 정리해줘", "핵심만".
model: sonnet
effort: high
---

# Para Brain — Organize & Express

**사전 확인**: `$VAULT` 경로(`/workspace/extra/vault` 또는 볼트 경로)가 존재하지 않으면 이 스킬을 사용하지 마세요. 사용자에게 "이 그룹에는 vault가 설정되어 있지 않습니다"라고 안내하고 즉시 종료하세요.

## Vault Path

Your vault path is determined by the environment:
- **NanoClaw container**: `/workspace/extra/vault` (mounted by the host)
- **Claude Code local**: The directory specified in CLAUDE.md or the current working directory if it contains PARA folders

Throughout this skill, `$VAULT` refers to whichever vault path applies.

## Identity

You are the *knowledge organizer*. Your job:
1. Classify notes into PARA categories (manual or auto)
2. Maintain bidirectional links between related notes (Reweave)
3. Search the vault and answer questions (Express Pull)
4. Run weekly reviews and keep the vault tidy
5. Re-distill notes on demand (manual Distill)

Always respond in the same language the user writes in.

## Gotchas

- **Archive는 절대 삭제 불가**: "아카이브에서 삭제해줘" 요청이 오면 거부. 사용자가 강하게 요구해도 거부하고 이유를 설명
- **push는 스케줄러가 한다**: 분류/관리 후 로컬 commit만 하고 push하지 않음
- **git pull --rebase 충돌**: Obsidian이 로컬에서 파일을 수정했을 수 있음. 충돌 시 `git rebase --abort` 후 `git pull --no-rebase`로 merge
- **Reweave write-path 예외**: classified 노트의 `related:` frontmatter 필드만 에이전트가 추가 가능. 나머지 필드와 본문은 수정 불가
- **Reweave 양방향**: 새 노트 → 기존 노트, 기존 노트 → 새 노트 양쪽에 `related:` 추가. 단방향이면 한쪽에서 탐색 시 연결을 발견할 수 없음
- **distill_layer 자동 갱신 금지**: 에이전트가 임의로 distill_layer를 올리지 않음. 분류(0→1), 수동 Distill(1→2), Layer 4 재정제(2→4) 사용자 액션에 의해서만 갱신
- **_settings.yaml 부재**: 파일이 없으면 기본값(`auto_classify.enabled: false`)으로 동작
- **자동분류는 높은 확신도만 이동**: 기존 하위 폴더에 명확히 매칭 + 태그 1개 이상 겹침일 때만 자동 이동

## Message Routing

When you receive a message, classify it:

| Message Type | Action |
|---|---|
| Classification ("분류해줘", "미분류 정리해줘", "이 노트를 {target}으로") | Classification workflow |
| PARA management ("새 프로젝트", "아카이브해", "목록") | PARA Management |
| Manual Distill ("다시 정리해줘", "핵심만 뽑아줘", "요약 다시") | Manual Distill |
| Vault search ("vault에서 찾아줘", "~에 대해 알려줘", "관련 노트") | Vault Search (Express Pull) |
| Weekly review ("주간 리뷰") | Weekly Review |
| Auto-classify commands ("자동 분류 켜줘/꺼줘", "자동분류 실행해") | Auto-Classification |
| Session clear ("세션 클리어", "컨텍스트 초기화") | Session Clear |
| Vault setup ("볼트 셋업해줘") | Vault Setup |

## Workflows

### Classification (독립 워크플로우)

분류는 캡처와 분리된 독립 워크플로우. 실제 분류(파일 이동)는 이 스킬만 수행.

**트리거:**
- 캡처 추천 메시지에 답장 (승인/변경)
- "분류해줘" / "미분류 정리해줘" → inbox 전체 배치 분류
- "이 노트를 {target}으로 옮겨줘" → 단건 직접 분류
- 주간 리뷰 (Weekly Review 참조)

**분류 실행 흐름:**

1. 대상 노트의 `ai_suggested_category`, `tags`, `contexts` 분석
2. PARA 의사결정 트리 적용 ([references/para.md](references/para.md))
3. 기존 PARA 폴더 확인 (`ls $VAULT/projects/ $VAULT/areas/ $VAULT/resources/`) → **(기존)** / **(신규)** 라벨링
4. **M:N contexts**: 물리적 배치(파일이 이동할 곳) 1개 + 논리적 연결(contexts에 추가될 관련 경로) N개를 함께 추천
5. 사용자 응답 처리:
   - 승인 → `git mv inbox/{file} {target}/{file}`, frontmatter 업데이트: `status: classified`, `contexts: [target, ...related]`, `distill_layer: 1` (0→1: 분류 = 사용자 확인)
   - 다른 위치 지정 → 해당 위치로 이동, contexts 조정
   - 무응답 → inbox에 `status: pending_review`로 유지
6. **Reweave**: 분류 완료 후 Reweave 워크플로우 실행 (아래 참조)

**배치 분류 ("분류해줘"):**

1. `ls $VAULT/inbox/` → `pending_review` 노트 목록
2. 각 노트에 대해 분류 추천 생성
3. 요약 메시지 전송:
   > *미분류 노트 {N}개:*
   > • {title} → `{suggested}` ({기존|신규}) — {reason}
   > • ...
   > (번호로 승인하거나 "전체 승인", "N번 → {다른위치}" 형식으로 변경)
4. 사용자 응답에 따라 일괄 이동 + 각 노트에 Reweave 실행

**직접 명령:**
- "이 노트를 {target}으로 옮겨줘" → move + update frontmatter + Reweave
- "미분류 노트 보여줘" → list inbox/ notes with status raw/pending_review

### Reweave (역연결)

분류 완료 후 자동 실행. 새 노트와 기존 노트 사이에 양방향 `related:` 링크를 추가한다.

**실행 조건**: 분류(Classification)가 실행될 때마다 자동으로 Reweave 수행.

**Reweave 흐름:**

1. 새로 분류된 노트의 `tags`와 대상 PARA 경로 확인
2. 같은 PARA 경로의 기존 노트 목록 조회: `ls $VAULT/{target}/`
3. 각 기존 노트의 `tags` 확인 (frontmatter 읽기)
4. **연결 조건**: 같은 PARA 경로 + 태그 1개 이상 겹침
5. 조건 충족 시 양방향 `related:` 추가:

   **새 노트 → 기존 노트** (본문 wikilink + frontmatter):
   - 새 노트의 `related:` frontmatter에 엔트리 추가
   - 새 노트 본문의 볼트 연결 섹션에 `[[기존노트]]` wikilink 추가

   **기존 노트 → 새 노트** (frontmatter만, write-path 예외):
   - 기존 노트의 `related:` frontmatter에만 엔트리 추가
   - 기존 노트의 본문은 수정하지 않음 (write-path 규칙)

6. `related:` 엔트리 형식:
   ```yaml
   related:
     - path: "resources/ddd/20260322-aggregate-design.md"
       reason: "동일 도메인, 태그 겹침: aggregate, ddd"
       added: 2026-03-22
   ```
7. Git commit: `git add {new-note} {modified-existing-notes} && git commit -m "reweave: {new-note-title} ↔ {N}개 연결"`

**연결이 없을 때**: 같은 PARA 경로에 기존 노트가 없거나 태그 겹침이 0개이면 Reweave 스킵. 메시지에 "연결된 기존 노트가 없습니다" 안내.

### Auto-Classification (별도 기능)

자동분류는 캡처와 독립적인 별도 기능. `_settings.yaml`로 설정.

```yaml
# $VAULT/_settings.yaml
auto_classify:
  enabled: false          # 기본 꺼짐
  trigger: on_capture     # on_capture | scheduled | manual_only
  schedule: "sunday 09:00" # trigger: scheduled일 때만
```

| trigger | 동작 |
|---------|------|
| `manual_only` | "자동분류 실행해" 명령 시에만 배치 실행 |
| `on_capture` | 캡처 완료 후 별도 세션에서 자동분류 시도 (높은 확신도만) |
| `scheduled` | 설정된 시간에 inbox 일괄 자동분류 |

**확신도 판단:**
- **High** (기존 하위 폴더에 명확히 매칭 + 태그 1개 이상 겹침): 자동 이동 + `status: auto_classified` + Reweave 실행
- **Low** (새 하위 폴더 필요, 여러 카테고리에 걸침, 태그 겹침 없음): inbox 유지 + `pending_review`, 추천만 전송

**자동분류 후 메시지:**
- High: "*자동분류: {title}* → `{target}` | *핵심*: {1-2줄}"
- Low: 수동 분류와 동일한 추천 형식

**설정 명령:**
- "자동 분류 켜줘" → `auto_classify.enabled: true`, trigger 확인 후 설정
- "자동 분류 꺼줘" → `auto_classify.enabled: false`
- "캡처할 때 자동분류해줘" → `trigger: on_capture`
- "매주 일요일에 자동분류해줘" → `trigger: scheduled`, `schedule: "sunday 09:00"`

### PARA Management

Commands:
- "새 프로젝트/영역/리소스 만들어: {name}" → create `{category}/{name}/` + .gitkeep + git commit
- "{name} 아카이브해" → move to `archive/{name}/` + git commit
- "프로젝트/영역/리소스 목록" → list subdirectories
- "아카이브에서 삭제해줘" → *REFUSE*. Say: "아카이브는 삭제할 수 없어요. 콜드 스토리지로 영구 보관됩니다."
- Archive → P/A/R restoration is allowed

### Manual Distill (수동 재정제)

사용자가 기존 노트의 Progressive Summarization을 다시 실행하도록 요청할 때.

**트리거:** "이 노트 다시 정리해줘", "핵심만 뽑아줘", "요약 다시 해줘"

**흐름:**
1. 대상 노트 읽기
2. 현재 `distill_layer` 확인
3. Layer 2~4를 재생성:
   - Layer 2: 본문에서 핵심 문장을 `**볼드**`로 재마킹
   - Layer 3: 볼드 중 최핵심을 `==하이라이트==`로 재마킹
   - Layer 4: `> **Executive Summary**: ...` 재생성
4. Frontmatter 업데이트: `distill_layer` 갱신 (1→2 또는 2→4)
5. Git commit: `git commit -m "distill: re-summarize {title}"`

### Vault Search (Express Pull)

When the user asks a question with vault search intent:
1. Search the vault using grep/glob for relevant keywords (see [references/express-patterns.md](references/express-patterns.md))
2. Read matching note contents (최대 5개)
3. Synthesize an answer based on vault contents, with source attribution
4. If vault has no relevant notes, answer from general knowledge (but mention "볼트에는 관련 자료가 없어서 일반 지식으로 답변합니다")
5. Clearly distinguish vault-sourced information from general knowledge

### Weekly Review

주간 리뷰는 inbox 현황 보고 + 분류 추천. 자동분류가 켜져 있어도 주간 리뷰 자체는 항상 추천만 전송.

1. List inbox/ notes with status: raw or pending_review
2. For each, generate a classification recommendation (do NOT move)
3. Send summary:
   > *주간 리뷰*
   > 미분류 노트 {N}개:
   > • {title} → 추천: `{category}` ({기존|신규})
   > • ...
   > 이번 주 캡처: {total}개
   > 미확인 노트: distill_layer: 0인 노트 {M}개
   > ("전체 승인" 또는 번호로 개별 분류)
4. Wait for user to classify via replies (Classification 워크플로우 실행)

자동분류가 켜져 있으면 주간 리뷰 후 추가 안내:
> *자동분류 대상 {M}개 (높은 확신도) — "자동분류 실행해"로 일괄 처리 가능*

### Vault Setup

If the user says "볼트 셋업해줘" or similar, check `$VAULT`:
1. If PARA directories exist → "이미 셋업되어 있어요"
2. If not → create `inbox/`, `projects/`, `areas/`, `resources/`, `archive/`, README.md
3. Git init + initial commit + push
4. Confirm to user

### Session Clear

When the user asks to reset context ("컨텍스트 초기화", "세션 클리어"):
- **NanoClaw**: Call `mcp__nanoclaw__clear_session` to reset the SDK session
- **Claude Code**: Tell the user to start a new session

Reply: "세션을 초기화했어요. 다음 메시지부터 새로운 대화로 시작합니다."

### Git Rules

- Always `cd $VAULT` before git operations
- Commit message format: `classify: {title} → {target}`, `reweave: {title} ↔ {N}개 연결`, `para: create {category}`, `review: weekly inbox cleanup`, `distill: re-summarize {title}`
- **Commit only, never push**
- Before operations, `git pull --rebase` to sync

## Additional Resources

- For PARA definitions and decision tree: see [references/para.md](references/para.md)
- For Express patterns and search strategies: see [references/express-patterns.md](references/express-patterns.md)
```

- [ ] **Step 2: Verify line count**

```bash
wc -l container/skills/para-brain/SKILL.md
```

Expected: ~200-220 lines.

- [ ] **Step 3: Commit**

```bash
git add container/skills/para-brain/SKILL.md
git commit -m "feat(para-brain): add organize+express skill

Implements Organize+Express from CODE redesign spec §4.5.
Key features:
- Classification with Reweave (bidirectional linking)
- Auto-classification with new _settings.yaml schema
- Manual Distill (re-summarization on demand)
- Vault Search (Express Pull with grep)
- Weekly Review with distill_layer reporting
- Vault guard (description + early return)"
```

---

## Task 7: Write para-brain evals

**Files:**
- Create: `container/skills/para-brain/evals/evals.json`
- Create: `container/skills/para-brain/evals/files/sample-vault-note-1.md`
- Create: `container/skills/para-brain/evals/files/sample-vault-note-2.md`
- Create: `container/skills/para-brain/evals/files/sample-vault-note-3.md`
- Create: `container/skills/para-brain/evals/files/sample-settings.yaml`

- [ ] **Step 1: Copy sample files**

```bash
cp container/skills/para-pipeline/evals/files/sample-vault-note-1.md \
   container/skills/para-brain/evals/files/sample-vault-note-1.md
cp container/skills/second-brain/evals/files/sample-vault-note-2.md \
   container/skills/para-brain/evals/files/sample-vault-note-2.md
cp container/skills/para-pipeline/evals/files/sample-settings.yaml \
   container/skills/para-brain/evals/files/sample-settings.yaml
```

- [ ] **Step 2: Write sample-vault-note-3.md (classified note for Reweave testing)**

```markdown
---
title: "Bounded Context와 도메인 경계 설정"
source: "https://martinfowler.com/bliki/BoundedContext.html"
source_type: web
captured: 2026-03-08T10:00:00+09:00
processed: 2026-03-08T10:00:05+09:00
status: classified
ai_distill_depth: 4
distill_layer: 1
content_hash: "sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
captured_via: telegram
contexts:
  - resources/ddd-patterns
tags: [ddd, bounded-context, domain-modeling, microservices]
related: []
ai_summary: "Bounded Context는 DDD에서 모델의 적용 범위를 명시적으로 정의하는 패턴. 같은 용어가 다른 컨텍스트에서 다른 의미를 가질 수 있음을 인정하고, 컨텍스트 간 통합은 명시적 번역 레이어를 통해 수행."
ai_suggested_category: "resources/ddd-patterns"
---

> **Executive Summary**: Bounded Context는 모델의 적용 범위를 정의하여, 같은 용어의 다른 의미를 체계적으로 관리하는 DDD 핵심 전략 패턴.

# Bounded Context와 도메인 경계 설정

*출처*: Martin Fowler | 2026-03-08

---

## 핵심 주장

- **모든 모델은 컨텍스트 안에서만 유효하다**: 경계 밖에서 같은 용어가 다른 의미를 가질 수 있음
- **컨텍스트 간 통합은 반드시 명시적 번역을 거쳐야 한다**

## 주요 논거 및 근거

- ==대규모 시스템에서 단일 통합 모델을 유지하려는 시도는 반드시 실패한다==
- 마이크로서비스 아키텍처는 Bounded Context의 물리적 구현

## 실용적 시사점

- **서비스 경계 = Bounded Context 경계** 원칙으로 마이크로서비스 분리
- Anti-Corruption Layer로 레거시 통합
```

- [ ] **Step 3: Write evals.json**

```json
{
  "skill_name": "para-brain",
  "evals": [
    {
      "id": 1,
      "prompt": "You are the para-brain knowledge organizer. The vault is at ./test-vault/.\n\nExisting vault contents:\n- inbox/20260312-100000-react-server-components-guide.md (status: pending_review, tags: [react, server-components, frontend]) (see sample-vault-note-2.md)\n- resources/ddd-patterns/ (has notes about Aggregates and Bounded Context)\n- areas/frontend/ (exists but empty)\n- _settings.yaml (see sample-settings.yaml)\n\nUser message: 미분류 노트 보여줘\n\nThen the user says: 그 RSC 노트를 frontend 영역으로 옮겨줘",
      "expected_output": "First: list pending inbox notes. Second: move note to areas/frontend/, update frontmatter with status: classified, distill_layer: 1, and contexts. Execute Reweave (but areas/frontend/ is empty, so no connections).",
      "files": [
        "evals/files/sample-vault-note-2.md",
        "evals/files/sample-settings.yaml"
      ],
      "expectations": [
        "Agent lists inbox notes with pending_review status",
        "Agent moves the file from inbox/ to areas/frontend/",
        "Agent updates frontmatter status to classified",
        "Agent updates distill_layer from 0 to 1 (classification = user confirmation)",
        "Agent adds areas/frontend to contexts array",
        "Agent creates a git commit for the classification",
        "Agent mentions Reweave result (no connections since areas/frontend/ is empty)"
      ]
    },
    {
      "id": 2,
      "prompt": "You are the para-brain knowledge organizer. The vault is at ./test-vault/.\n\nExisting vault contents:\n- inbox/20260322-143000-value-object.md (status: pending_review, tags: [ddd, value-object, domain-modeling, immutability], ai_suggested_category: resources/ddd-patterns)\n- resources/ddd-patterns/20260310-143000-ddd-aggregate-pattern.md (see sample-vault-note-1.md, tags: [ddd, aggregate, domain-modeling, consistency-boundary])\n- resources/ddd-patterns/20260308-100000-bounded-context.md (see sample-vault-note-3.md, tags: [ddd, bounded-context, domain-modeling, microservices])\n\nUser message: Value Object 노트를 resources/ddd-patterns로 분류해줘",
      "expected_output": "Agent classifies the note and executes Reweave — both existing DDD notes share tags (ddd, domain-modeling) with the new note, so bidirectional related: entries should be added.",
      "files": [
        "evals/files/sample-vault-note-1.md",
        "evals/files/sample-vault-note-3.md",
        "evals/files/sample-settings.yaml"
      ],
      "expectations": [
        "Agent moves value-object note from inbox/ to resources/ddd-patterns/",
        "Agent updates status to classified, distill_layer to 1",
        "Agent executes Reweave after classification",
        "Reweave finds both existing notes (Aggregate and Bounded Context) share tags with new note",
        "Agent adds related: entries to the new note pointing to both existing notes",
        "Agent adds related: entries to both existing notes pointing to the new note (bidirectional)",
        "Each related: entry includes path, reason (mentioning overlapping tags), and added date",
        "Agent does NOT modify existing notes' body content (only frontmatter related: field)",
        "Git commit mentions reweave"
      ]
    },
    {
      "id": 3,
      "prompt": "You are the para-brain knowledge organizer. The vault is at ./test-vault/.\n\nExisting PARA structure:\n- projects/ (empty)\n- areas/frontend/ (has notes)\n- resources/ddd-patterns/ (has notes)\n- archive/ (empty)\n\nUser message: 아카이브에서 삭제해줘",
      "expected_output": "Agent refuses the deletion request.",
      "files": [],
      "expectations": [
        "Agent refuses the archive deletion request",
        "Reply explains archive is permanent cold storage",
        "Agent does NOT attempt any file deletion"
      ]
    },
    {
      "id": 4,
      "prompt": "You are the para-brain knowledge organizer. The vault is at ./test-vault/.\n\nExisting vault contents:\n- resources/ddd-patterns/20260310-143000-ddd-aggregate-pattern.md (about DDD Aggregates, see sample-vault-note-1.md)\n- areas/frontend/20260312-100000-react-server-components-guide.md (about RSC)\n- inbox/ (empty)\n\nUser message: DDD에서 Aggregate 경계를 설정할 때 주의할 점이 뭐야?",
      "expected_output": "Agent searches vault, finds DDD note, synthesizes answer grounded in vault contents.",
      "files": [
        "evals/files/sample-vault-note-1.md"
      ],
      "expectations": [
        "Agent searches the vault for DDD/Aggregate keywords",
        "Answer references specific content from the vault note",
        "Agent grounds answer in vault contents, not just general knowledge",
        "Agent does NOT attempt to capture the question as a note"
      ]
    },
    {
      "id": 5,
      "prompt": "You are the para-brain knowledge organizer. The vault is at ./test-vault/.\n\nExisting vault contents:\n- inbox/20260320-090000-saga-pattern.md (status: pending_review, tags: [microservices, saga, distributed-transactions])\n- inbox/20260321-143000-value-object.md (status: pending_review, tags: [ddd, value-object], distill_layer: 0)\n- resources/ddd-patterns/ (has 1 note)\n- areas/frontend/ (has 1 note)\n- _settings.yaml (see sample-settings.yaml)\n\nUser message: 주간 리뷰 실행해줘",
      "expected_output": "Weekly review: list pending notes, classification recommendations, distill_layer: 0 count.",
      "files": [
        "evals/files/sample-vault-note-1.md",
        "evals/files/sample-settings.yaml"
      ],
      "expectations": [
        "Lists both inbox notes with titles and tags",
        "Provides classification recommendation for each note",
        "Labels existing subfolders as (기존)",
        "Does NOT move any notes",
        "Reports distill_layer: 0 count (미확인 노트 수)",
        "Shows total inbox count"
      ]
    },
    {
      "id": 6,
      "prompt": "You are the para-brain knowledge organizer. The vault is at ./test-vault/.\n\nExisting vault contents:\n- resources/ddd-patterns/20260310-143000-ddd-aggregate-pattern.md (see sample-vault-note-1.md, distill_layer: 1)\n\nUser message: Aggregate 패턴 노트 다시 정리해줘",
      "expected_output": "Manual Distill: re-run Progressive Summarization on the note, update distill_layer from 1 to 2.",
      "files": [
        "evals/files/sample-vault-note-1.md"
      ],
      "expectations": [
        "Agent finds and reads the Aggregate pattern note",
        "Agent re-generates Layer 2 (bold), Layer 3 (highlights), Layer 4 (Executive Summary)",
        "Agent updates distill_layer from 1 to 2",
        "Agent creates a git commit with message mentioning distill",
        "Agent shows the updated summary to the user"
      ]
    },
    {
      "id": 7,
      "prompt": "You are the para-brain knowledge organizer. The vault is at ./test-vault/.\n\nExisting vault contents:\n- inbox/20260321-143000-value-object.md (status: pending_review, tags: [ddd, value-object, domain-modeling, immutability])\n- resources/ddd-patterns/20260310-143000-ddd-aggregate-pattern.md (tags: [ddd, aggregate, domain-modeling])\n- areas/frontend/ (has notes)\n- _settings.yaml: auto_classify: { enabled: true, trigger: on_capture }\n\nThe user has just captured a new DDD note. Simulate auto-classify mode. The note clearly matches resources/ddd-patterns (existing folder, tags ddd + domain-modeling overlap).",
      "expected_output": "Auto-classify with high confidence: move to resources/ddd-patterns, status: auto_classified, execute Reweave.",
      "files": [
        "evals/files/sample-vault-note-1.md"
      ],
      "expectations": [
        "Agent auto-classifies to resources/ddd-patterns (high confidence)",
        "Status is set to auto_classified",
        "Reweave is executed after auto-classification",
        "Reply uses compact auto-classify format",
        "Contexts array includes resources/ddd-patterns"
      ]
    }
  ]
}
```

- [ ] **Step 4: Commit**

```bash
git add container/skills/para-brain/evals/
git commit -m "test(para-brain): add eval suite

7 evals: classification + distill_layer update (1), Reweave bidirectional
linking (2), archive deletion refusal (3), vault search (4), weekly review
with distill_layer (5), manual Distill (6), auto-classification (7)."
```

---

## Task 8: Update container-runner.ts for SessionStart hook

**Files:**
- Modify: `src/container-runner.ts:127-149`
- Modify: `src/container-runner.test.ts`

- [ ] **Step 1: Write the failing test**

Add a test to `src/container-runner.test.ts` that verifies SessionStart hook registration. The test uses the existing mock patterns in the file (`vi.mock('fs', async () => ...)` with `existsSync`, `readFileSync`, `writeFileSync` as `vi.fn()`):

```typescript
describe('SessionStart hook registration', () => {
  it('should add vault-context.sh hook to settings.json when para-pipeline skill exists', async () => {
    const fs = (await import('fs')).default;

    // Setup: settings.json exists with env only, skill script exists
    (fs.existsSync as ReturnType<typeof vi.fn>).mockImplementation((p: string) => {
      if (p.includes('settings.json')) return true;
      if (p.includes('para-pipeline/scripts/vault-context.sh')) return true;
      if (p.includes('container/skills')) return true;
      return false;
    });
    (fs.readFileSync as ReturnType<typeof vi.fn>).mockReturnValue(
      JSON.stringify({ env: { CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: '1' } })
    );
    (fs.readdirSync as ReturnType<typeof vi.fn>).mockReturnValue(['para-pipeline']);
    (fs.statSync as ReturnType<typeof vi.fn>).mockReturnValue({ isDirectory: () => true });

    // ... invoke the function that triggers hook registration ...
    // (adapt to the actual export — may need to call runContainerAgent or
    // extract the hook registration into a testable function)

    // Verify writeFileSync was called with hooks.SessionStart containing the hook
    expect(fs.writeFileSync).toHaveBeenCalledWith(
      expect.stringContaining('settings.json'),
      expect.stringContaining('"SessionStart"'),
    );

    // Parse the written JSON and verify hook structure
    const writtenJson = JSON.parse(
      (fs.writeFileSync as ReturnType<typeof vi.fn>).mock.calls
        .find((c: string[]) => c[0].includes('settings.json'))![1]
    );
    expect(writtenJson.hooks.SessionStart).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: 'command',
          command: expect.stringContaining('vault-context.sh'),
        }),
      ])
    );
  });

  it('should not duplicate hook if already registered', async () => {
    const fs = (await import('fs')).default;

    const existingSettings = {
      env: {},
      hooks: {
        SessionStart: [{
          type: 'command',
          command: 'bash ~/.claude/skills/para-pipeline/scripts/vault-context.sh',
        }],
      },
    };
    (fs.existsSync as ReturnType<typeof vi.fn>).mockReturnValue(true);
    (fs.readFileSync as ReturnType<typeof vi.fn>).mockReturnValue(
      JSON.stringify(existingSettings)
    );
    (fs.readdirSync as ReturnType<typeof vi.fn>).mockReturnValue(['para-pipeline']);
    (fs.statSync as ReturnType<typeof vi.fn>).mockReturnValue({ isDirectory: () => true });

    // ... invoke hook registration ...

    // Verify the hook array still has exactly 1 entry (no duplicates)
    const writtenJson = JSON.parse(
      (fs.writeFileSync as ReturnType<typeof vi.fn>).mock.calls
        .find((c: string[]) => c[0].includes('settings.json'))![1]
    );
    expect(writtenJson.hooks.SessionStart).toHaveLength(1);
  });
});
```

Note: The exact function invocation depends on how hook registration is exposed. Read `container-runner.ts` to determine if it needs to be extracted into a separate testable function or tested via `runContainerAgent`. The mock patterns above match the existing test file's `vi.mock('fs', async () => ...)` setup.

- [ ] **Step 2: Run test to verify it fails**

```bash
npx vitest run src/container-runner.test.ts --reporter=verbose 2>&1 | tail -20
```

Expected: New test fails (hook registration logic not yet implemented).

- [ ] **Step 3: Implement SessionStart hook registration**

In `src/container-runner.ts`, after the existing `settings.json` creation block (lines 127-149) and after skill sync (lines 151-161), add hook registration logic:

Note: This code runs AFTER settings.json creation (lines 127-149) AND after skill sync (lines 151-161). The settings.json file is guaranteed to exist at this point because the creation block writes it if missing. The skill sync copies para-pipeline/ to the group's skills dir, so `existsSync` on the script path will check the group-local copy.

```typescript
// Register SessionStart hooks from skills that provide scripts
// Currently: para-pipeline/scripts/vault-context.sh (Express Ambient)
// ORDERING: settings.json created (L127-149) → skills synced (L151-161) → hooks registered (here)
const settingsPath = path.join(groupSessionsDir, 'settings.json');
if (!fs.existsSync(settingsPath)) return; // safety: should not happen, but guard
const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
if (!settings.hooks) settings.hooks = {};
if (!settings.hooks.SessionStart) settings.hooks.SessionStart = [];

const vaultContextScript = path.join(
  skillsDst,
  'para-pipeline',
  'scripts',
  'vault-context.sh',
);
if (fs.existsSync(vaultContextScript)) {
  const hookCommand = 'bash ~/.claude/skills/para-pipeline/scripts/vault-context.sh';
  const alreadyRegistered = settings.hooks.SessionStart.some(
    (h: { command?: string }) => h.command === hookCommand,
  );
  if (!alreadyRegistered) {
    settings.hooks.SessionStart.push({
      type: 'command',
      command: hookCommand,
    });
  }
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
```

This code:
1. Reads the existing `settings.json`
2. Ensures `hooks.SessionStart` array exists
3. Checks if `para-pipeline/scripts/vault-context.sh` exists in the synced skills
4. Adds the hook entry if not already registered (idempotent)
5. Writes back the updated settings

- [ ] **Step 4: Run test to verify it passes**

```bash
npx vitest run src/container-runner.test.ts --reporter=verbose 2>&1 | tail -20
```

Expected: All tests pass.

- [ ] **Step 5: Build check**

```bash
npm run build 2>&1 | tail -5
```

Expected: No TypeScript errors.

- [ ] **Step 6: Commit**

```bash
git add src/container-runner.ts src/container-runner.test.ts
git commit -m "feat(container-runner): register SessionStart hook for vault-context.sh

After syncing skills, reads settings.json and adds a SessionStart hook
entry for para-pipeline/scripts/vault-context.sh if the script exists.
Idempotent — skips if already registered. Enables Express Ambient
(vault awareness injection) in every container session."
```

---

## Task 9: Update group CLAUDE.md

**Files:**
- Modify: `groups/telegram_second-brain/CLAUDE.md`

- [ ] **Step 1: Read current file**

```bash
cat groups/telegram_second-brain/CLAUDE.md
```

- [ ] **Step 2: Update skill references**

Replace all references to `second-brain` skill with the new skill names:

```markdown
# Second Brain Agent

You are a personal knowledge vault manager. You capture, classify, and connect knowledge using the PARA method.

## Identity

- Name: Second Brain Agent
- Role: 개인 지식 관리 에이전트. 사용자의 세컨드 브레인 볼트를 관리
- Personality: 간결하고 정확함. 캡처 결과는 빠르게, 분석은 깊게
- Language: 사용자가 쓰는 언어로 응답 (한국어 우선)
- Channel: Telegram

## Procedural — How You Work

### Session Start
1. Check `$VAULT/.processing_buffer` — if exists, previous session crashed. Report to user
2. Skim `$VAULT/inbox/` for unprocessed notes (count + titles)

### Core Workflows
Knowledge management logic is split across two skills:
- **`para-pipeline`** — URL/memo capture + Progressive Summarization (auto Distill). Refer to it for: URL capture pipeline, text memo capture, crawl diagnostics, processing buffer
- **`para-brain`** — Organization + vault utilization. Refer to it for: PARA classification (manual/auto), Reweave (bidirectional linking), manual Distill, vault search, weekly review, session clear

### Multi-URL Batches
When processing multiple URLs, send each result immediately via `mcp__nanoclaw__send_message`. Never accumulate results — container timeout (~30min) will kill the session.

## Semantic — What You Know

### Vault Path
`$VAULT` = `/workspace/extra/vault`

### Git Sync
- **Commit only, never push** — a scheduled task handles `git push` every 10 minutes
- Before operations: `git pull --rebase` to sync
- Commit messages: `capture: {title}`, `classify: {title} → {target}`, `reweave: {title} ↔ {N}개 연결`, `para: create {category}`, `review: weekly inbox cleanup`, `distill: re-summarize {title}`

### PARA Structure
| Folder | Purpose |
|--------|---------|
| `inbox/` | New captures (pending_review) |
| `projects/` | Goal + deadline |
| `areas/` | Ongoing responsibilities |
| `resources/` | Reference material |
| `archive/` | Cold storage — NEVER delete |

## Episodic — Session Memory

The `conversations/` folder contains searchable history from previous sessions. Use this to recall context.

## Working — Environment

### Communication
Your output is sent to the user via Telegram.

Use `mcp__nanoclaw__send_message` to send a message immediately while still working.

#### Internal thoughts
Wrap internal reasoning in `<internal>` tags — these are logged but not sent to the user.

### Message Formatting
NEVER use markdown headings (##). *single asterisks* for bold (NEVER **double**), _underscores_ for italic, • bullet points, ```triple backticks``` for code

### Container Mounts
| Container Path | Host Path | Access |
|---|---|---|
| `/workspace/group` | `groups/telegram_second-brain/` | read-write |
| `/workspace/extra/vault` | `/Users/ljo/Desktop/second_brain` | read-write |

### Platform Tools
These MCP tools are available only in the NanoClaw container:

- `mcp__nanoclaw__send_message` — Send a message to the user immediately
- `mcp__nanoclaw__clear_session` — Reset the SDK session
- `mcp__nanoclaw__schedule_task` — Schedule recurring/one-time tasks
- `mcp__nanoclaw__list_tasks` — List scheduled tasks

### URL Crawl Fallback
If `curl` fails to fetch a URL, use `agent-browser` (available via Bash) as fallback.
```

- [ ] **Step 3: Commit**

```bash
git add groups/telegram_second-brain/CLAUDE.md
git commit -m "docs(second-brain): update group CLAUDE.md for skill split

Replace single second-brain skill reference with para-pipeline and
para-brain. Add new commit message formats (reweave, distill)."
```

---

## Task 10: Migrate _settings.yaml

**Files:**
- Modify: `/Users/ljo/Desktop/second_brain/_settings.yaml`

- [ ] **Step 1: Read current file**

```bash
cat /Users/ljo/Desktop/second_brain/_settings.yaml
```

Expected: `auto_classify: false`

- [ ] **Step 2: Convert to object schema**

```yaml
auto_classify:
  enabled: false
  trigger: on_capture
```

- [ ] **Step 3: Commit in vault repo**

```bash
cd /Users/ljo/Desktop/second_brain && \
  git add _settings.yaml && \
  git commit -m "chore: migrate _settings.yaml to object schema

Convert auto_classify from boolean (false) to object
({ enabled: false, trigger: on_capture }) for CODE redesign."
```

---

## Task 11: Migrate existing vault notes frontmatter

**Files:**
- Modify: All `.md` files in `/Users/ljo/Desktop/second_brain/`

Existing 96 notes have outdated frontmatter that will cause issues with the new skills:
- `source_type: article` / `webinar` → not in new enum (new skills expect `web`)
- `related:` uses string arrays → new skills expect object arrays with `path`, `reason`, `added`
- Missing fields: `ai_distill_depth`, `distill_layer`, `content_hash`, `captured_via`
- Classified notes (~40) should get `distill_layer: 1` (user confirmed via classification)

- [ ] **Step 1: Survey current state**

```bash
cd /Users/ljo/Desktop/second_brain && \
echo "=== source_type values ===" && \
grep -rh '^source_type:' --include='*.md' | sort | uniq -c | sort -rn && \
echo "=== related format sample ===" && \
grep -A2 '^related:' --include='*.md' -r | head -20 && \
echo "=== notes missing ai_distill_depth ===" && \
find . -name '*.md' ! -path './_*' | wc -l
```

- [ ] **Step 2: Write migration script**

Create a one-time migration script. Run in vault repo, not nanoclaw repo.

```bash
#!/bin/bash
# migrate-frontmatter.sh — one-time migration for CODE redesign Phase 1a
# Run from vault root: bash migrate-frontmatter.sh

VAULT="$(pwd)"
COUNT=0

for note in $(find "$VAULT" -name '*.md' ! -path '*/_*' ! -path '*/.*'); do
  CHANGED=false

  # 1. Normalize source_type: article/webinar/etc → web
  if grep -q '^source_type: article' "$note" || \
     grep -q '^source_type: webinar' "$note"; then
    sed -i '' 's/^source_type: article/source_type: web/' "$note"
    sed -i '' 's/^source_type: webinar/source_type: web/' "$note"
    CHANGED=true
  fi

  # 2. Add missing fields after status: line (if frontmatter exists)
  if grep -q '^status:' "$note"; then
    # Add ai_distill_depth if missing
    if ! grep -q '^ai_distill_depth:' "$note"; then
      sed -i '' '/^status:/a\
ai_distill_depth: 0' "$note"
      CHANGED=true
    fi

    # Add distill_layer based on status
    if ! grep -q '^distill_layer:' "$note"; then
      if grep -q '^status: classified' "$note" || grep -q '^status: auto_classified' "$note"; then
        sed -i '' '/^ai_distill_depth:/a\
distill_layer: 1' "$note"
      else
        sed -i '' '/^ai_distill_depth:/a\
distill_layer: 0' "$note"
      fi
      CHANGED=true
    fi

    # Add captured_via if missing
    if ! grep -q '^captured_via:' "$note"; then
      sed -i '' '/^distill_layer:/a\
captured_via: telegram' "$note"
      CHANGED=true
    fi
  fi

  if [ "$CHANGED" = true ]; then
    COUNT=$((COUNT + 1))
  fi
done

echo "Migrated $COUNT notes"
```

Note: `related:` string→object conversion is complex with sed. Handle it in para-brain SKILL.md instead — when Reweave reads `related:` and finds a string entry, convert it to `{path: string, reason: "legacy migration", added: "2026-03-28"}` in place.

- [ ] **Step 3: Run migration**

```bash
cd /Users/ljo/Desktop/second_brain && bash migrate-frontmatter.sh
```

- [ ] **Step 4: Verify**

```bash
cd /Users/ljo/Desktop/second_brain && \
echo "=== source_type check ===" && \
grep -rh '^source_type:' --include='*.md' | sort | uniq -c | sort -rn && \
echo "=== new fields check ===" && \
grep -c 'ai_distill_depth' $(find . -name '*.md' ! -path '*/_*' | head -5)
```

- [ ] **Step 5: Commit in vault repo**

```bash
cd /Users/ljo/Desktop/second_brain && \
  git add -A && \
  git commit -m "chore: migrate frontmatter for CODE redesign Phase 1a

Normalize source_type (article/webinar → web).
Add missing fields: ai_distill_depth, distill_layer, captured_via.
Classified notes get distill_layer: 1, pending notes get 0."
```

---

## Task 12: Register inbox nudge scheduled task

**Files:**
- Modify: `groups/telegram_second-brain/CLAUDE.md` (add scheduled task documentation)

The inbox nudge is a **NanoClaw scheduled task** (not a skill feature). It runs daily at lunch and after work to remind the user to classify pending inbox notes. Uses `mcp__nanoclaw__schedule_task` registered in the group.

- [ ] **Step 1: Register scheduled tasks after deployment**

After all skills are deployed and working, register these scheduled tasks via the agent:

```
# Lunch nudge (weekday 12:00 KST)
mcp__nanoclaw__schedule_task({
  name: "inbox-nudge-lunch",
  schedule: "0 12 * * 1-5",
  prompt: "inbox에 미분류 노트가 몇 개인지 확인해. 0개면 아무것도 보내지 마. 1개 이상이면 사용자에게 메시지를 보내:\n\n📥 점심시간 inbox 정리\n미분류 {N}개:\n• {최근 3개 노트 제목, 각각 한 줄}\n\n'분류해줘'로 일괄 처리 가능"
})

# Evening nudge (weekday 18:00 KST)
mcp__nanoclaw__schedule_task({
  name: "inbox-nudge-evening",
  schedule: "0 18 * * 1-5",
  prompt: "inbox에 미분류 노트가 몇 개인지 확인해. 0개면 아무것도 보내지 마. 1개 이상이면 사용자에게 메시지를 보내:\n\n📥 퇴근 전 inbox 정리\n미분류 {N}개:\n• {최근 3개 노트 제목}\n\n오늘 캡처한 것: {오늘 날짜 기준 captured 노트 수}개\n'분류해줘'로 일괄 처리"
})
```

- [ ] **Step 2: Document in group CLAUDE.md**

Add to the Scheduled Tasks section of the group CLAUDE.md written in Task 9:

```markdown
### Scheduled Tasks
- **git push**: every 10 minutes — sync vault to remote
- **inbox-nudge-lunch**: weekday 12:00 KST — inbox 미분류 정리 유도
- **inbox-nudge-evening**: weekday 18:00 KST — 퇴근 전 inbox 정리 유도
```

- [ ] **Step 3: Commit**

```bash
git add groups/telegram_second-brain/CLAUDE.md
git commit -m "docs(second-brain): add inbox nudge scheduled tasks

Register daily lunch (12:00) and evening (18:00) inbox cleanup
reminders as NanoClaw scheduled tasks. Sends count + recent titles
only when inbox has pending notes."
```

---

## Task 13: Atomic swap — delete old skill

**Files:**
- Delete: `container/skills/second-brain/` (entire directory)

- [ ] **Step 1: Verify new skills are complete**

```bash
echo "=== para-pipeline ===" && \
ls -R container/skills/para-pipeline/ && \
echo "=== para-brain ===" && \
ls -R container/skills/para-brain/
```

Expected: Both skills have SKILL.md, references/, evals/ directories with all files.

- [ ] **Step 2: Delete old skill**

```bash
rm -rf container/skills/second-brain/
```

- [ ] **Step 3: Verify deletion**

```bash
ls container/skills/ | sort
```

Expected: `agent-browser`, `capabilities`, `para-brain`, `para-pipeline`, `slack-formatting`, `status` (no `second-brain`).

- [ ] **Step 4: Commit atomic swap**

```bash
git rm -r container/skills/second-brain/
git add container/skills/para-pipeline/ container/skills/para-brain/
git commit -m "refactor: atomic swap — replace second-brain with para-pipeline + para-brain

Delete monolithic second-brain skill (373 lines). Replace with:
- para-pipeline: Capture + auto Distill (Progressive Summarization,
  content_hash dedup, wikilinks)
- para-brain: Organize + Express Pull (classification, Reweave,
  manual Distill, vault search, weekly review)

Phase 1a of CODE redesign (spec §4.5)."
```

---

## Task 14: Build verification and integration check

**Files:** None (verification only)

- [ ] **Step 1: TypeScript build**

```bash
npm run build 2>&1 | tail -10
```

Expected: No errors.

- [ ] **Step 2: Run all tests**

```bash
npx vitest run --reporter=verbose 2>&1 | tail -30
```

Expected: All tests pass, including the new container-runner SessionStart hook test.

- [ ] **Step 3: Verify final directory structure**

```bash
echo "=== Skills ===" && \
find container/skills/para-pipeline container/skills/para-brain -type f | sort && \
echo "=== No second-brain ===" && \
test ! -d container/skills/second-brain && echo "OK: deleted" || echo "FAIL: still exists"
```

Expected:
```
=== Skills ===
container/skills/para-brain/SKILL.md
container/skills/para-brain/evals/evals.json
container/skills/para-brain/evals/files/sample-settings.yaml
container/skills/para-brain/evals/files/sample-vault-note-1.md
container/skills/para-brain/evals/files/sample-vault-note-2.md
container/skills/para-brain/evals/files/sample-vault-note-3.md
container/skills/para-brain/references/express-patterns.md
container/skills/para-brain/references/para.md
container/skills/para-pipeline/SKILL.md
container/skills/para-pipeline/evals/evals.json
container/skills/para-pipeline/evals/files/sample-settings.yaml
container/skills/para-pipeline/evals/files/sample-vault-note-1.md
container/skills/para-pipeline/evals/files/sample-vault-note-2.md
container/skills/para-pipeline/references/distill-layers.md
container/skills/para-pipeline/references/note-template.md
container/skills/para-pipeline/references/platform-strategies.md
container/skills/para-pipeline/references/schema.md
container/skills/para-pipeline/scripts/vault-context.sh
=== No second-brain ===
OK: deleted
```

- [ ] **Step 4: Verify vault-context.sh runs**

```bash
VAULT=/Users/ljo/Desktop/second_brain bash container/skills/para-pipeline/scripts/vault-context.sh
```

Expected: Output starting with `[Vault Awareness]`.

- [ ] **Step 5: Verify SKILL.md line counts**

```bash
wc -l container/skills/para-pipeline/SKILL.md container/skills/para-brain/SKILL.md
```

Expected: para-pipeline ~200-250 lines, para-brain ~200-220 lines.

---

## Phase 1b 파일 캡처 아키텍처 노트

> Phase 1a 범위 밖이나, 구현 방향을 미리 기록. Phase 1b 구현 시 참고.

### 원칙: para-pipeline은 NanoClaw에 비의존

파일 캡처는 2개 레이어로 분리:

1. **채널 레이어 (NanoClaw 호스트)**: 파일 다운로드 → 컨테이너 워크스페이스에 전달
2. **스킬 레이어 (para-pipeline)**: 워크스페이스에 도착한 파일 → Claude Read로 직접 읽기 → 일반 캡처 플로우 진입

para-pipeline SKILL.md는 "워크스페이스에 파일이 있으면 읽는다"만 알면 됨. 파일이 어떤 채널에서 왔는지, 어떤 NanoClaw 스킬이 다운로드했는지 몰라도 동작.

### 채널별 파일 인프라 셋업 (`/add-second-brain` init에서 처리)

| 채널 | 파일 다운로드 방법 | 비고 |
|------|-------------------|------|
| WhatsApp | `/add-pdf-reader`, `/add-image-vision` 기존 스킬 머지 유도 | 이미 구현됨, 브랜치 머지만 하면 됨 |
| 텔레그램 | grammy `ctx.getFile()` + Bot API 다운로드 (~20줄) | init에서 `telegram.ts`에 추가 |
| Slack | Slack API `files.info` + 다운로드 | 해당 채널 추가 시 구현 |
| Discord | Discord API attachment URL 다운로드 | 해당 채널 추가 시 구현 |

### para-pipeline 파일 처리 분기 (Phase 1b에 추가)

```
| Message Type | Action |
| 워크스페이스 파일 (PDF) | Claude Read로 PDF 직접 읽기 → source_type: pdf, 일반 캡처 플로우 |
| 워크스페이스 파일 (이미지) | Claude Read로 이미지 직접 보기 → OCR/설명 추출 → source_type: image, 일반 캡처 플로우 |
```

Claude는 PDF와 이미지를 네이티브로 읽을 수 있으므로 `pdftotext`, `sharp` 같은 외부 도구 불필요. 외부 도구는 선택적 최적화 (속도/비용)로만 고려.

### 참고 프로젝트

- `references/reader` (Jina Reader): PDF 구조 보존 (`pdfjs-dist` 문자 높이 기반 헤딩 감지), 이미지 VLM 캡션 생성 패턴. API 의존은 미채택이나 추출 로직 패턴 참고 가치 높음.
- `references/khoj`: `TextToEntries` 추상 클래스 → 멀티포맷 프로세서 인터페이스 설계 참고.
- NanoClaw 기존 스킬: `/add-pdf-reader` (WhatsApp + pdftotext), `/add-image-vision` (WhatsApp + sharp + Claude Vision). 텔레그램 등가물 미존재 — Phase 1b에서 텔레그램용 구현 필요.
