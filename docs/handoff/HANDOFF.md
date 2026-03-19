# Second Brain on NanoClaw — Handoff

## Goal

NanoClaw 위에 `/add-second-brain` 스킬을 실행하여 개인용 second-brain 에이전트를 구성한다. 텔레그램으로 링크/메모 캡처 → AI 처리 → PARA 분류 → GitHub 저장 파이프라인을 동작시키는 것이 최종 목표.

## First Action

**`/add-second-brain` 스킬을 실행하라.** 스킬이 대화형으로 볼트 경로, Git 설정, 채널 선택, 그룹 등록, CLAUDE.md 배포를 전부 안내한다. GitHub private repo(`https://github.com/LeeJuOh/second-brain`)는 이미 생성되어 있으니 스킬 실행 시 이걸 연결하면 된다.

## Context

이 프로젝트는 discovery → spec → plan → implementation 순서로 진행됐다. Discovery 단계에서 H3'(에이전트가 vault를 능동적으로 활용하면 가치가 있는가?) 가설이 검증됐고, 이제 H1(캡처 습관) 검증을 위한 NanoClaw 기반 Phase 1a를 구축하는 단계.

핵심 설계 결정:
- 코어 코드 수정 0줄. 설정 + CLAUDE.md만으로 구현
- PARA 분류 (Projects/Areas/Resources/Archive), Archive 삭제 불가
- 수동 분류가 기본, 자동 분류는 opt-in (`_settings.yaml`)
- 파일명: `YYYYMMDD-HHMMSS-slug.md`
- frontmatter: `status` 값은 `raw → pending_review → classified` (수동) 또는 `raw → auto_classified` (자동)
- `nonMainReadOnly: false` 필수 — second-brain은 non-main 그룹이라 true면 write 불가

## Current Progress

| 단계 | 상태 | 산출물 |
|------|------|--------|
| 선행 리서치 | 완료 | `second-brain/linkdive_research.md`, `second-brain/discovery_plan.md` |
| 설계 스펙 작성 + 검수 2회 통과 | 완료 | `docs/superpowers/specs/2026-03-15-second-brain-design.md` |
| 스킬 파일 (SKILL.md + template) | 완료 | `.claude/skills/add-second-brain/SKILL.md`, `.claude/skills/add-second-brain/template-claude-md.md` |
| GitHub repo 생성 | 완료 | `https://github.com/LeeJuOh/second-brain` (private, 비어있음) |
| 스킬 실행 (실제 설치) | **미완료** | `/add-second-brain` 실행 필요 |
| E2E 검증 | 미완료 | 스킬 실행 후 테스트 |

## What Worked

- **스펙 검수 루프**: 2회 리뷰를 통해 누락된 결정사항(파일명 규칙, status 값, 라우팅 테이블 등)을 체계적으로 잡아냄
- **선행 문서 대조**: linkdive_research.md의 확정 결정(Section 7)과 대조하여 불일치를 발견 (`approved` → `classified`, `url` → `source`, `created` → `captured` 리네임 등)
- **NanoClaw 코드 분석**: `mount-security.ts`에서 `nonMainReadOnly` 이슈를 사전에 발견 — 안 잡았으면 스킬 실행 후 write 실패

## What Didn't Work

- **수동 실행 플랜 작성**: `docs/superpowers/plans/2026-03-16-second-brain-setup.md`를 만들었지만, 실제로는 `/add-second-brain` 스킬이 이미 존재하여 불필요. 스킬의 존재를 먼저 확인했어야 함. 이 파일은 삭제해도 됨
- **볼트 디렉토리에 직접 git init 시도**: 사용자가 거부 — 스킬이 대화형으로 처리해야 하는 부분

## Next Steps

1. `/add-second-brain` 실행 — 스킬이 안내하는 대로 진행:
   - 볼트 경로: `/Users/ljo/Desktop/vault` (클린 PARA 구조)
   - GitHub repo: `https://github.com/LeeJuOh/second-brain` (이미 생성됨)
   - PAT 생성 필요 (Fine-grained, Contents read/write, second-brain repo만)
   - 채널: telegram
   - `nonMainReadOnly: false` 설정 필수
2. E2E 검증 (스킬의 Phase 5):
   - URL 캡처 → inbox/ 파일 생성 + git push
   - 분류 추천 메시지 수신
   - PARA 관리 (프로젝트 생성, 아카이브 삭제 거부)
   - 볼트 검색
   - 주간 리뷰 수동 트리거
3. 불필요 파일 정리: `docs/superpowers/plans/2026-03-16-second-brain-setup.md` 삭제 검토
