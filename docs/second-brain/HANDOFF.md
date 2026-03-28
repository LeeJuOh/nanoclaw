# Handoff: Second Brain CODE Redesign — Phase 1a

## Goal

Split the monolithic `container/skills/second-brain/` skill (373 lines) into two focused skills (`para-pipeline` for Capture+Distill, `para-brain` for Organize+Express) plus a SessionStart hook (`vault-context.sh`), implementing Phase 1a of the CODE redesign.

The implementation plan is **complete and reviewed**. Next step is execution.

## First Action

Read the plan at `docs/superpowers/plans/2026-03-28-second-brain-code-redesign.md` and start executing from **Task 1**. The plan has 14 tasks with checkbox steps — work through them sequentially, committing after each task. Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` as directed in the plan header.

## Context

This session was a **plan review session** (not implementation). We:
1. Wrote the original plan (in a prior session)
2. Ran a thorough review using `/skill-creator-pro` — cross-checking the plan against the spec, existing codebase, and 31 reference projects
3. Found 15+ issues across Critical/Major/Minor severity
4. Applied 8 fixes directly to the plan, added 2 new tasks (Task 11: note migration, Task 12: inbox nudge scheduler)
5. Resolved 3 deferred issues (Express Pull scope, inbox alert redesign, legacy note migration)

The plan is now at **2236 lines, 14 tasks**, and all known issues are addressed. The "Spec deviations" section at the top of the plan documents 5 intentional divergences from the spec that need to be reflected back in the spec after implementation.

Key mental model: This is a **container skill split** — the code runs inside NanoClaw agent containers (Linux VMs), not on the host. Skills are markdown SKILL.md files that teach the container agent how to behave. The vault is a Git-backed Obsidian-compatible folder at `/Users/ljo/Desktop/second_brain/` mounted into containers at `/workspace/extra/vault`.

## Current Progress

### Plan review — DONE
- [x] Read full 1923-line plan
- [x] Verified against spec (`docs/superpowers/specs/2026-03-22-second-brain-code-redesign.md`)
- [x] Verified container-runner.ts line numbers (127-149, 151-161 confirmed accurate)
- [x] Verified existing second-brain skill inventory (9 files, 12 evals, 4 references)
- [x] Analyzed 31 reference projects via `docs/superpowers/specs/2026-03-28-references-analysis.md`
- [x] Deep-analyzed `references/last30days-skill/` for platform crawling patterns (Reddit enrichment 2-phase pattern)
- [x] Analyzed `references/khoj/`, `references/memsearch/`, `references/qmd/` for content extraction patterns
- [x] Checked actual vault state: 96 notes, 56 inbox, legacy frontmatter format

### Plan fixes applied — DONE
- [x] **Threads self-reply**: Added platform-strategies.md extension (Task 1 Step 5), Gotcha (Task 2), eval #9 (Task 4)
- [x] **source_type divergence**: Added spec deviation note in schema.md (Task 1 Step 2)
- [x] **Eval migration mapping**: Added complete old→new mapping table (Task 4)
- [x] **Container-runner test**: Replaced sketch with 2 concrete tests (Task 8 Step 1)
- [x] **Hook registration guard**: Added execution order note + existence check (Task 8 Step 3)
- [x] **git add -A safety**: Changed to `git rm -r` + `git add` (Task 13 Step 4)
- [x] **Express Pull scope**: Documented as intentional Phase 1a inclusion in spec deviations header
- [x] **Inbox nudge**: Added Task 12 with daily scheduled tasks (12:00/18:00 weekday)
- [x] **Note migration**: Added Task 11 with migration script for 96 existing notes

### Plan fixes applied — 캡처 파이프라인 검수 (2026-03-28, 2차)
- [x] **파일 첨부 미지원 안내**: Message Routing에 `[Photo]`/`[Document]` 감지 → 안내 메시지 분기 추가 (Task 2)
- [x] **Readability HTML 전처리**: URL Capture workflow에 step 6 (HTML Preprocessing) 추가. curl raw HTML 대신 Readability로 본문 추출 → 토큰 60-80% 절약 (Task 2)
- [x] **크롤링 캐시**: URL Capture workflow에 step 4 (Crawl Cache Check) 추가. crawl.jsonl 30분 캐시로 재크롤링 방지 (Task 2)
- [x] **Phase 1b 파일 캡처 아키텍처**: 플랜 말미에 아키텍처 노트 추가 — para-pipeline은 NanoClaw 비의존 (워크스페이스 파일만 처리), init에서 채널별 파일 인프라 셋업 (WhatsApp→기존 스킬 머지, 텔레그램→grammy 다운로드 추가)
- [x] **Spec deviations 3건 추가**: 파일 첨부 Phase 1a 안내, Readability 전처리, 크롤링 캐시

### Implementation — NOT STARTED
- [ ] Task 1-14 execution

## What Worked

- **Cross-referencing spec vs plan** caught the Express Pull Phase 1a/1b scope mismatch and source_type divergence
- **Checking actual vault state** revealed the legacy frontmatter gap (article/webinar source_types, string-format related arrays) that would have caused runtime issues
- **last30days-skill analysis** provided the Reddit enrichment 2-phase pattern that directly informed the Threads self-reply crawling strategy
- **container-runner.ts line verification** confirmed the plan's assumptions were accurate, preventing wasted debugging time during implementation

## What Didn't Work

- Initial assumption that `references/last30days-skill/` wasn't in the references directory — it was. Always check before stating.
- Threshold-based inbox alerts (>10 notes) was the wrong design — daily scheduled nudges at lunch/evening is more useful for habit formation

## Next Steps

After the first action (executing the plan):

1. **Execute Tasks 1-14** sequentially, committing after each task
2. **Run evals** after Task 4 (para-pipeline) and Task 7 (para-brain) to validate skill quality
3. **Update the spec** to reflect the 5 documented deviations in the plan header
4. **Test end-to-end** via Telegram: send a Threads URL with self-replies, verify merged capture
5. **Register scheduled tasks** (Task 12) — these require the agent to be running, so do after deployment

### Key files to read first
- `docs/superpowers/plans/2026-03-28-second-brain-code-redesign.md` — THE PLAN (2236 lines, 14 tasks)
- `docs/superpowers/specs/2026-03-22-second-brain-code-redesign.md` — The spec (reference)
- `container/skills/second-brain/SKILL.md` — The existing skill being replaced (373 lines)
- `src/container-runner.ts` — Host-side code to modify (Task 8)
