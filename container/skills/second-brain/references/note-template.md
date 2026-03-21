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
status: raw
tags: [{tag1}, {tag2}, ...]
contexts: []
ai_summary: "{2-3문장 요약}"
captured_via: telegram
---

# {title}

*출처*: {author/platform} | {date}

---

## 핵심 주장

- {주장 1}: {맥락과 함께 설명}
- {주장 2}: {맥락과 함께 설명}

## 주요 논거 및 근거

- {증거/데이터/사례 1}
- {증거/데이터/사례 2}

## 인사이트

{기존 통념과 다른 시각, 놓치기 쉬운 포인트, 주목할 만한 점}

## 실용적 시사점

- {행동으로 옮길 수 있는 것 1}
- {행동으로 옮길 수 있는 것 2}

## 한계 및 열린 질문

- {저자가 다루지 않은 부분}
- {추가 탐구가 필요한 질문}

## 볼트 연결

- {관련 노트가 있으면 옵시디언 wikilink로 연결}
```

## Text Memo Note Format

Same as URL Capture but:
- No `source` field
- `source_type: memo`
- Title auto-generated from content
- Slug from first ~60 chars of text

## Analysis Depth Guideline

콘텐츠 길이에 비례하여 분석 깊이를 조절한다:
- **짧은 콘텐츠** (~500자 이하, 트윗/짧은 스레드): 핵심 주장 + 인사이트 + 시사점 위주로 간결하게
- **긴 아티클/논문**: 모든 섹션을 충실히 작성
- **짧은 메모** (~200자 이하): 핵심 주장 + 시사점만
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
