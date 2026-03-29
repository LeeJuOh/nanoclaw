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
