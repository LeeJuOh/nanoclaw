# Frontmatter Schema & File Naming

## Frontmatter (canonical)

```yaml
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
entities: [] # AI가 추출한 핵심 엔티티 (Phase 1a: 빈 배열로 스키마 선행 확보, Phase 1d: AI 추출 활성화)
related: # Reweave로 추가된 역연결
  - path: "resources/ddd/bounded-context.md"
    reason: "동일 도메인, 태그 겹침: aggregate, ddd"
    added: 2026-03-22
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
- `ai_distill_depth`: AI가 캡처 시 자동 생성한 최고 Distill 레이어. 현재는 항상 4 (Layer 1~4 일괄 생성). 향후 부분 Distill 시 변경 가능
- `distill_layer`: 사용자가 확인/승인한 최고 레이어. 캡처 직후 0 (미확인). 갱신 규칙:
  - `0 → 1`: 사용자가 분류를 실행했을 때 (inbox → PARA 경로 이동)
  - `1 → 2`: 사용자가 수동 Distill을 요청했을 때
  - `2 → 4`: 사용자가 Executive Summary를 직접 수정하거나 Layer 4 재정제를 요청했을 때
  - 자동 갱신 금지 — 반드시 사용자 액션에 의해서만 갱신
- `content_hash`: 크롤링된 본문의 SHA-256 해시 (`sha256:` 접두어). URL 캡처에서만 생성, 메모는 생략. 중복 감지 용도. Bash `shasum -a 256`으로 계산
- `entities`: AI가 추출한 핵심 엔티티 배열. Phase 1a에서는 빈 배열(`[]`)로 스키마만 확보. Phase 1d에서 캡처 시 AI가 본문에서 핵심 엔티티를 추출하여 채움. 빈 필드를 선행 추가하는 이유: Phase 1d에서 필드를 새로 추가하면 기존 노트 마이그레이션이 다시 필요
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
