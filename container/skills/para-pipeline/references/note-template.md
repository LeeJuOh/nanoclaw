# Note Format & Obsidian Rules

Read this when creating or modifying notes in the vault.

## URL Capture Note Format

```markdown
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
```

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

```markdown
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
```

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
