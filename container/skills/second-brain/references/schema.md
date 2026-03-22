# Frontmatter Schema & File Naming

## Frontmatter (canonical)

```yaml
---
title: "Note title"
source: "https://..." # omit for text memos
source_type: web # youtube | twitter | threads | github | reddit | medium | web | memo
captured: 2026-03-15T14:30:00+09:00
processed: 2026-03-15T14:30:05+09:00 # omit if not yet processed
status: pending_review # raw | pending_review | classified | auto_classified
captured_via: telegram # telegram | whatsapp | slack | discord | claude-code
contexts: # M:N PARA path references (logical grouping)
  - resources/ddd
  - projects/linkdive
tags: [ddd, architecture] # free keywords (not PARA paths)
ai_summary: "2-3 sentence summary"
ai_suggested_category: "resources/ddd"
---
```

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
- Status transitions: `raw → pending_review → classified` (manual) or `raw → auto_classified` (auto, high confidence)
- In practice, capture + AI processing happen atomically, so `pending_review` is the initial write status. `raw` only occurs if processing fails mid-way.

## File Naming

`YYYYMMDD-HHMMSS-slug.md`
- Example: `20260315-143000-ux-research-methods.md`
- Timestamp: capture time (KST, +09:00)
- Slug: ASCII alphanumeric + hyphens, max 60 chars
- Korean titles: extract English keywords or date-based fallback (see Gotchas in SKILL.md)

## Crawl Log (`$VAULT/_logs/crawl.jsonl`)

JSONL 형식. 한 줄 = 한 크롤링 시도. 같은 URL에 대해 여러 시도(curl → browser 등)가 있으면 각각 별도 줄.

```json
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
```

필수 필드: `ts`, `url`, `platform`, `method`, `usable`
조건부 필드: `http_status`(curl만), `content_type`(curl만), `reason`(usable=false), `next`(fallback 있을 때), `note`(성공 시), `error`(완전 실패 시)
