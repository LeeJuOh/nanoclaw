# Second Brain on NanoClaw — Implementation Plan (v2)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/add-second-brain` 스킬을 만들어, 누구든 NanoClaw 위에 second-brain 에이전트를 인터랙티브하게 설정할 수 있게 한다.

**Architecture:** 코어 코드 수정 0줄. `/add-second-brain` 스킬(SKILL.md)이 볼트 경로 질문 → 기존 레포 감지 → PARA 구조 생성 → 마운트/그룹 등록 → CLAUDE.md 배포 → 스케줄 설정까지 인터랙티브로 처리.

**Tech Stack:** NanoClaw (Node.js), Claude Agent SDK, Git/GitHub (HTTPS+PAT), Any messaging channel

**Spec:** `docs/superpowers/specs/2026-03-15-second-brain-design.md`

### v1 → v2 변경 사항

| v1 (구 플랜) | v2 (현 플랜) |
|---|---|
| 경로/레포명 하드코딩 | 인터랙티브 질문으로 수집 |
| 새 GitHub 레포만 가정 | 기존 레포/디렉토리 감지 + 분기 처리 |
| 텔레그램 전용 | 설치된 채널 자동 감지 |
| 수동 스텝 나열 | `/add-second-brain` 스킬로 패키징 |
| 재실행 불가 | 멱등성 — 이미 설정된 항목은 스킵 |
| 10+4+4+2+2+10 = 32 스텝 | 스킬 1개 작성 → 실행 → 검증 |

---

## Chunk 1: `/add-second-brain` 스킬 작성

### Task 1: SKILL.md 작성

스킬 디렉토리에 SKILL.md + 지원 파일을 생성한다.

**Files:**
- Create: `.claude/skills/add-second-brain/SKILL.md`
- Create: `.claude/skills/add-second-brain/template-claude-md.md`

- [ ] **Step 1: SKILL.md 생성**

````markdown
---
name: add-second-brain
description: Add Second Brain knowledge management. Sets up a PARA-based vault agent that captures links/memos via messaging, AI-processes them, classifies using PARA, and stores to a Git-backed repository. Works with any messaging channel.
---

# Add Second Brain

This skill sets up a second-brain agent on NanoClaw. The agent captures links/memos, processes them with AI, classifies using PARA, and syncs to a Git-backed vault.

**Code changes: 0 lines.** Configuration + CLAUDE.md only.

## Phase 1: Pre-flight

### Check if already set up

```bash
sqlite3 store/messages.db "SELECT jid, folder FROM registered_groups WHERE folder LIKE '%second-brain%'"
```

If a group exists:

AskUserQuestion: second-brain 그룹이 이미 등록되어 있습니다 (`{folder}`). 어떻게 할까요?
- **재설정**: Phase 2부터 다시 진행
- **검증만**: Phase 5로 이동

### Check channel availability

```bash
ls src/channels/*.ts | grep -v test | grep -v registry | grep -v index
```

At least one channel must exist. If none → tell user to run a channel skill first (e.g., `/add-telegram`, `/add-whatsapp`).

## Phase 2: Vault Setup

### Ask vault path

AskUserQuestion: 볼트(저장소)로 사용할 디렉토리 경로를 알려주세요. 기존 디렉토리도 사용 가능합니다. (예: ~/second-brain, ~/Desktop/my-vault)

Store the path as `VAULT_PATH`. Expand `~` to absolute path for all subsequent operations.

### Detect existing state

```bash
[ -d "<VAULT_PATH>" ] && echo "DIR_EXISTS" || echo "NO_DIR"
[ -d "<VAULT_PATH>/.git" ] && echo "GIT_EXISTS" || echo "NO_GIT"
cd "<VAULT_PATH>" 2>/dev/null && git remote -v 2>/dev/null
```

**Case A: .git + remote configured**
→ "기존 Git 저장소 감지: `{remote_url}`. 이 저장소를 그대로 사용합니다."
→ Skip repo creation

**Case B: .git exists, no remote**

AskUserQuestion: Git 초기화는 되어있지만 remote이 없습니다. 어떻게 할까요?
- **GitHub URL 입력**: 기존 GitHub 저장소 연결
- **새로 생성**: GitHub private repo 생성
- **로컬만**: remote 없이 로컬 git만 사용

- URL → `git remote add origin <URL>`
- 새로 생성 → `gh repo create <name> --private --source=. --push`
- 로컬만 → skip (no push)

**Case C: Directory exists, no .git**

AskUserQuestion: 이 디렉토리를 볼트로 사용합니다. Git 저장소를 설정할까요?
- **새 GitHub repo 생성**: 추천
- **기존 GitHub URL 연결**
- **로컬만**

- 새로 생성 → `git init && gh repo create <name> --private --source=. --push`
- URL → `git init && git remote add origin <URL>`
- 로컬만 → `git init`

**Case D: Directory doesn't exist**
→ `mkdir -p <VAULT_PATH>` + same question as Case C

### PARA directory structure

Check each directory, create only if missing:

```bash
cd "<VAULT_PATH>"
for dir in inbox projects areas resources archive; do
  [ -d "$dir" ] || mkdir -p "$dir"
  [ -f "$dir/.gitkeep" ] || touch "$dir/.gitkeep"
done
```

### Create vault files (if missing)

**.gitignore** — create if not exists, or append missing entries:

```
.obsidian/
.DS_Store
.Trash/
*.tmp
.git-credentials
```

**_settings.yaml** — create if not exists:

```yaml
auto_classify: false   # true면 캡처 시 추천 없이 바로 분류
```

**README.md** — create if not exists:

```markdown
# Second Brain Vault

PARA 기반 개인 지식 저장소.

## 구조

| 폴더 | 용도 |
|------|------|
| `inbox/` | 새 캡처 (미분류) |
| `projects/` | 목표 + 마감일이 있는 단기 작업 |
| `areas/` | 마감 없이 지속 관리하는 영역 |
| `resources/` | 참고용 관심사/자료 |
| `archive/` | 완료/비활성 — 삭제 불가 |
```

### Git credential for container

컨테이너는 `.ssh` 마운트가 차단되므로 HTTPS+PAT 방식 필요. **remote이 없으면 이 단계 스킵.**

Check if credential already configured:

```bash
cd "<VAULT_PATH>"
git config credential.helper 2>/dev/null
[ -f .git-credentials ] && echo "CRED_EXISTS"
```

If already configured → skip.

If not:

AskUserQuestion: 컨테이너에서 git push를 하려면 GitHub PAT(Personal Access Token)가 필요합니다.
1. GitHub Settings > Developer settings > Fine-grained tokens
2. 권한: Contents (read/write) — 해당 repo만
토큰을 알려주시면 설정합니다. 나중에 하려면 "skip"이라고 해주세요.

If token provided:

```bash
cd "<VAULT_PATH>"
# GitHub username 자동 감지
GH_USER=$(gh api user --jq '.login' 2>/dev/null || git remote get-url origin 2>/dev/null | sed -n 's|.*github.com[:/]\([^/]*\)/.*|\1|p')
echo "https://${GH_USER}:<PAT>@github.com" > .git-credentials
chmod 600 .git-credentials
git config --local credential.helper "store --file=$(pwd)/.git-credentials"
```

### Initial commit (if needed)

```bash
cd "<VAULT_PATH>"
if [ -n "$(git status --porcelain)" ]; then
  git add .
  git commit -m "init: PARA vault structure"
  git push -u origin main 2>/dev/null || true  # OK if no remote
fi
```

## Phase 3: NanoClaw Configuration

### Update mount allowlist

Read `~/.config/nanoclaw/mount-allowlist.json`.

Check if `VAULT_PATH` already in `allowedRoots`. If not, add:

```json
{
  "path": "<VAULT_PATH>",
  "allowReadWrite": true,
  "description": "Second Brain vault"
}
```

**Preserve existing entries** — read the file, merge, write back.

**`nonMainReadOnly`**: must be `false`. If currently `true`, change it and inform the user:

> `nonMainReadOnly`를 `false`로 변경합니다. second-brain은 non-main 그룹이므로 write 권한이 필요합니다. 이 변경은 다른 non-main 그룹의 writable 마운트에도 영향을 줍니다.

### Select channel

Detect available channels:

```bash
ls src/channels/*.ts | grep -v test | grep -v registry | grep -v index | sed 's|.*/||;s|\.ts||'
```

AskUserQuestion: 어떤 채널로 second-brain을 연결할까요? 감지된 채널: {channels}

Store as `CHANNEL`.

### Get chat ID

Channel-specific instructions:

| Channel | Instructions |
|---------|-------------|
| telegram | 봇과의 개인 채팅에서 `/chatid` 전송. 형식: `tg:123456789` |
| whatsapp | 메인 채팅에서 "사용 가능한 채팅 목록 보여줘"로 JID 확인 |
| slack | Slack에서 채널 우클릭 > Copy link > 채널 ID 추출 |
| discord | Discord Developer Mode > 채널 우클릭 > Copy ID |

AskUserQuestion: {해당 채널의 instructions}. 채팅 ID를 알려주세요.

Store as `CHAT_JID`.

### Register group

```bash
FOLDER="${CHANNEL}_second-brain"
npx tsx setup/index.ts --step register -- \
  --jid "<CHAT_JID>" \
  --name "second-brain" \
  --folder "$FOLDER" \
  --trigger "@Andy" \
  --channel <CHANNEL> \
  --no-trigger-required
```

### Add vault mount to group

`setup/register.ts` CLI는 additionalMounts를 지원하지 않으므로, 등록 후 직접 업데이트:

```bash
sqlite3 store/messages.db "UPDATE registered_groups SET container_config = '{\"additionalMounts\":[{\"hostPath\":\"<VAULT_PATH>\",\"containerPath\":\"vault\",\"readonly\":false}]}' WHERE folder = '<FOLDER>'"
```

**주의**: 이 변경은 NanoClaw restart 후에만 반영됩니다. `index.ts`가 `registeredGroups`를 메모리에 캐싱하므로, restart 없이는 마운트가 적용되지 않음.

Verify:

```bash
sqlite3 store/messages.db "SELECT folder, container_config FROM registered_groups WHERE folder = '<FOLDER>'"
```

### Restart NanoClaw (필수 — 위 sqlite3 변경 반영)

```bash
# macOS
launchctl kickstart -k gui/$(id -u)/com.nanoclaw
# Linux
# systemctl --user restart nanoclaw
```

mount-security.ts가 프로세스 시작 시 allowlist를 캐싱하므로 재시작 필요.

## Phase 4: Deploy CLAUDE.md

Read the template from `${CLAUDE_SKILL_DIR}/template-claude-md.md`, replace the following variables, and write to `groups/<FOLDER>/CLAUDE.md`:

- `{{CHANNEL}}` → channel name (e.g., Telegram)
- `{{FOLDER}}` → group folder (e.g., telegram_second-brain)
- `{{VAULT_HOST_PATH}}` → vault host path (e.g., ~/Desktop/vault)
- `{{FORMATTING_RULES}}` → channel-specific rules from the table below

### Channel formatting rules

| Channel | Rules |
|---------|-------|
| telegram | NEVER use markdown headings (##). *single asterisks* for bold (NEVER \*\*double\*\*), _underscores_ for italic, • bullet points, \`\`\`triple backticks\`\`\` for code |
| whatsapp | NEVER use markdown headings. *single asterisks* for bold, _underscores_ for italic, • bullet points |
| slack | Use mrkdwn format. *asterisks* for bold, _underscores_ for italic, • bullet points, \`\`\`code\`\`\` |
| discord | Standard markdown. **double asterisks** for bold, *single* for italic, - bullet points, \`\`\`code\`\`\` |

### Commit CLAUDE.md

```bash
cd <NANOCLAW_ROOT>
git add groups/<FOLDER>/CLAUDE.md
git commit -m "feat: add second-brain group CLAUDE.md"
```

## Phase 5: Schedule + Verify

### Weekly review schedule (optional)

AskUserQuestion: 주간 리뷰 스케줄을 설정할까요? 매주 일요일 09:00에 미분류 노트를 정리합니다. (yes / no / 다른 시간)

If yes:

Tell the user to send this in their **main** chat:

> second-brain 그룹에 스케줄 등록해줘:
> - 프롬프트: "주간 리뷰 실행해줘"
> - 스케줄: cron, 매주 일요일 09:00 (0 9 * * 0)
> - 대상 그룹: second-brain의 JID

### Verify

Tell the user:

> second-brain 채팅에 URL을 하나 보내보세요. 에이전트가 캡처 후 분류 추천을 보내면 성공입니다.

Check logs if needed:

```bash
tail -f logs/nanoclaw.log
```

### Verify checklist

- [ ] URL 전송 → inbox/에 파일 생성 + git commit
- [ ] 분류 추천 메시지 수신
- [ ] "새 프로젝트 만들어: 테스트" → projects/ 생성
- [ ] "아카이브에서 삭제해줘" → 거부 응답

## Troubleshooting

### 에이전트가 응답하지 않음

1. 서비스 확인: `launchctl list | grep nanoclaw` (macOS) / `systemctl --user status nanoclaw` (Linux)
2. 그룹 등록 확인: `sqlite3 store/messages.db "SELECT * FROM registered_groups WHERE folder LIKE '%second-brain%'"`
3. 채널 토큰 확인: `.env`에 해당 채널 토큰이 있고, `data/env/env`에 sync되어 있는지
4. 로그: `tail -f logs/nanoclaw.log`

### git push 실패

1. credential 확인: `cd <VAULT_PATH> && git config credential.helper`
2. `.git-credentials` 존재 + 권한 확인: `ls -la .git-credentials`
3. PAT 권한 확인: Contents (read/write) 필요
4. remote 확인: `git remote -v`

### 볼트 파일이 생성되지 않음

1. 마운트 확인: `sqlite3 store/messages.db "SELECT container_config FROM registered_groups WHERE folder LIKE '%second-brain%'"`
2. allowlist 확인: `cat ~/.config/nanoclaw/mount-allowlist.json`
3. `nonMainReadOnly`가 `false`인지 확인 — `true`면 write 불가

## Removal

1. 그룹 삭제: `sqlite3 store/messages.db "DELETE FROM registered_groups WHERE folder = '<FOLDER>'"`
2. 그룹 폴더 삭제: `rm -rf groups/<FOLDER>`
3. mount-allowlist에서 볼트 항목 제거 (선택)
4. 스케줄 태스크 제거 (있는 경우)
5. 볼트 자체는 유지됨 (GitHub repo + 로컬 파일 보존)
6. 서비스 재시작: `launchctl kickstart -k gui/$(id -u)/com.nanoclaw`
````

- [ ] **Step 2: template-claude-md.md 생성**

`${CLAUDE_SKILL_DIR}/template-claude-md.md` — Phase 4에서 변수 치환 후 배포되는 CLAUDE.md 템플릿.

```markdown
# Second Brain Agent

You are a personal knowledge management agent. You manage a second brain vault using the PARA method. Your vault is mounted at `/workspace/extra/vault`.

## Communication

Your output is sent to the user via {{CHANNEL}}.

You also have `mcp__nanoclaw__send_message` which sends a message immediately while you're still working.

### Internal thoughts

Wrap internal reasoning in `<internal>` tags — these are logged but not sent to the user.

## Message Formatting

{{FORMATTING_RULES}}

## Container Mounts

| Container Path | Host Path | Access |
|---|---|---|
| `/workspace/group` | `groups/{{FOLDER}}/` | read-write |
| `/workspace/extra/vault` | `{{VAULT_HOST_PATH}}` | read-write |

## Memory

The `conversations/` folder contains searchable history. Use this to recall context from previous sessions.

---

## Identity

You are the *second-brain vault manager*. Your job:
1. Capture links and memos the user sends
2. Organize them using PARA classification
3. Answer questions by searching the vault
4. Keep the vault tidy with weekly reviews

Always respond in the same language the user writes in.

---

## Procedural — Workflows

### Message Routing

When you receive a message, classify it:

| Message Type | Action |
|---|---|
| URL only | Capture (F3) |
| URL + text | Capture — text becomes user memo in frontmatter |
| Explicit capture ("저장해", "캡처해", "save") + text | Text memo capture (F3) |
| Explicit PARA command ("새 프로젝트", "아카이브해", "분류해줘") | PARA management (F2/F4) |
| File attachment (PDF, image) | Reply: "파일 캡처는 아직 미지원이에요. URL이나 텍스트로 보내주세요." |
| Other text | Conversation/query — search vault first, then general knowledge (F5) |
| Ambiguous | Ask a clarifying question |

*Principle*: URLs auto-capture. Text without explicit trigger = conversation.

### F1. Vault Setup

If the user says "볼트 셋업해줘" or similar, check `/workspace/extra/vault`:
1. If PARA directories exist → "이미 셋업되어 있어요"
2. If not → create `inbox/`, `projects/`, `areas/`, `resources/`, `archive/`, README.md
3. Git init + initial commit + push
4. Confirm to user

### F2. PARA Management

Commands:
- "새 프로젝트/영역/리소스 만들어: {name}" → create `{category}/{name}/` + .gitkeep + git commit
- "{name} 아카이브해" → move to `archive/{name}/` + git commit
- "프로젝트/영역/리소스 목록" → list subdirectories
- "아카이브에서 삭제해줘" → *REFUSE*. Say: "아카이브는 삭제할 수 없어요. 콜드 스토리지로 영구 보관됩니다."
- Archive → P/A/R restoration is allowed

### F3. Capture Pipeline

**URL Capture:**
1. Detect URL in message
2. Crawl: `curl -sL -m 30 <url>` → if HTML, extract readable content. If curl fails, use `agent-browser` as fallback
3. Generate: title, summary (2-3 sentences), tags (3-5 keywords)
4. Create frontmatter (AI 처리 완료 후 작성하므로 `pending_review`로 시작 — `raw` 상태는 처리 실패/중단 시에만 발생):
   ```yaml
   ---
   title: "extracted title"
   source: "https://..."
   source_type: web
   captured: YYYY-MM-DDTHH:MM:SS+09:00
   processed: YYYY-MM-DDTHH:MM:SS+09:00
   status: pending_review
   contexts: []
   tags: [tag1, tag2, tag3]
   ai_summary: "2-3 sentence summary"
   ai_suggested_category: "resources/topic-name"
   ---
   ```
5. Save to `inbox/YYYYMMDD-HHMMSS-slug.md`
   - Slug: ASCII alphanumeric + hyphens from title, max 60 chars
   - Korean titles: extract English keywords or date-based fallback
6. Git: `cd /workspace/extra/vault && git add inbox/<filename> && git commit -m "capture: {title}" && git push`
   - Push failure: keep local commit, retry on next capture or weekly review
7. Read `_settings.yaml` for auto_classify mode:
   - `auto_classify: false` → Reply with classification recommendation (see F4 manual mode)
   - `auto_classify: true` → Auto-classify immediately (see F4 auto mode)

**Text Memo Capture** (triggered by "저장해"/"캡처해" + text):
- Same pipeline but: no source field, source_type: "memo", title auto-generated from content
- Slug from first ~60 chars of text

**Duplicate Check:**
Before saving, search existing notes: `grep -rl "<normalized-url>" /workspace/extra/vault/`
- If found: reply "이미 캡처되어 있어요: {existing title} ({path})"
- URL normalization: strip trailing slash, remove www., lowercase hostname

### F4. Classification

**Manual Mode (auto_classify: false — default):**
After capture, recommend a PARA category:

Decision tree:
1. Related to an active project? → `projects/{name}`
2. Related to an ongoing area of responsibility? → `areas/{name}`
3. Reference material? → `resources/{topic}`
4. None of the above → stay in `inbox/`

Reply format:
> *캡처 완료: {title}*
> 추천: `resources/{topic}` — {reason}
> 다른 옵션: `projects/{name}`, `areas/{name}`
> (답장으로 선택하거나 직접 지정해주세요)

On user response:
- Approval → `git mv inbox/{file} {target}/{file}`, update frontmatter: `status: classified`, add `contexts`
- Different location → move there instead
- No response → keep in inbox as `status: pending_review`

**Auto Mode (auto_classify: true):**
- Classify immediately using decision tree
- Move file + set `status: auto_classified`
- Reply: "*캡처+분류 완료: {title}* → `{target}`"

**Direct commands:**
- "이 노트를 {target}으로 옮겨줘" → move + update frontmatter
- "미분류 노트 보여줘" → list inbox/ notes with status raw/pending_review

**Mode toggle:**
- "자동 분류 켜줘" → update `_settings.yaml`: `auto_classify: true`, confirm
- "자동 분류 꺼줘" → update `_settings.yaml`: `auto_classify: false`, confirm

### F5. Vault Search/Query

When the user asks a question:
1. Search the vault using grep/glob for relevant keywords
2. Read matching note contents
3. Synthesize an answer based on vault contents
4. If vault has no relevant notes, answer from general knowledge (but mention "볼트에는 관련 자료가 없어서 일반 지식으로 답변합니다")

Search strategies:
- Keyword: `grep -ril "keyword" /workspace/extra/vault/`
- By date: `grep -rl "captured: 2026-03" /workspace/extra/vault/inbox/`
- By tag: `grep -rl "tags:.*keyword" /workspace/extra/vault/`
- By context: `grep -rl "contexts:.*projects/linkdive" /workspace/extra/vault/`

### F6. Weekly Review (when triggered by scheduler)

Read `_settings.yaml` to determine mode.

**Manual mode (auto_classify: false):**
1. List inbox/ notes with status: raw or pending_review
2. For each, generate a classification recommendation (do NOT move)
3. Send summary:
   > *주간 리뷰*
   > 미분류 노트 {N}개:
   > • {title} → 추천: `{category}`
   > • ...
   > 이번 주 캡처: {total}개
4. Wait for user to classify via replies

**Auto mode (auto_classify: true):**
1. List inbox/ notes with status: raw or pending_review
2. Auto-classify each (move + status: auto_classified). Low confidence → keep in inbox
3. Send summary:
   > *주간 리뷰*
   > 자동 분류: {N}개
   > • {title} → `{category}`
   > 리뷰 필요: {M}개
   > • {title} (확신도 낮음)
   > 이번 주 캡처: {total}개

### Git Rules

- Always `cd /workspace/extra/vault` before git operations
- Commit message format: `capture: {title}`, `classify: {title} → {target}`, `para: create {category}`, `review: weekly inbox cleanup`
- Always try `git push` after commit. On failure, log and continue — retry on next operation
- Before operations, `git pull --rebase` to sync

---

## Semantic — Domain Knowledge

### Vault Structure

```
/workspace/extra/vault/
├── inbox/              ← new captures (raw/pending_review)
├── projects/           ← goal + deadline (dynamic subfolders)
├── areas/              ← ongoing responsibilities (dynamic subfolders)
├── resources/          ← reference material (dynamic subfolders)
├── archive/            ← completed/inactive — NEVER DELETE
├── _settings.yaml      ← agent config (auto_classify)
└── README.md
```

### PARA Definitions

| Category | Definition | Lifecycle |
|---|---|---|
| Projects | Short-term efforts with a goal and deadline | Done/abandoned → Archive |
| Areas | Ongoing responsibilities with no end date | Inactive → Archive |
| Resources | Reference material for interests/topics | Unneeded → Archive |
| Archive | Cold storage for completed P/A/R | **Cannot be deleted. Always exists.** |

### Decision Tree (for classifying notes)

1. Is it for an active project? → Projects
2. Is it for an ongoing area of responsibility? → Areas
3. Is it reference material? → Resources
4. Is it done or no longer needed? → Archive

### Frontmatter Schema (canonical)

```yaml
---
title: "Note title"
source: "https://..." # omit for text memos
source_type: web # web | memo
captured: 2026-03-15T14:30:00+09:00
processed: 2026-03-15T14:30:05+09:00 # omit if not yet processed
status: pending_review # raw | pending_review | classified | auto_classified
contexts: # M:N PARA path references (logical grouping)
  - resources/ddd
  - projects/linkdive
tags: [ddd, architecture] # free keywords (not PARA paths)
ai_summary: "2-3 sentence summary"
ai_suggested_category: "resources/ddd"
---
```

- `contexts` = **where this note belongs** (PARA paths, M:N)
- `tags` = **what this note is about** (free keywords)
- Physical location: the contexts entry matching the file's actual path
- Status transitions: `raw → pending_review → classified` (manual) or `raw → auto_classified` (auto)
- In practice, capture + AI processing happen atomically, so `pending_review` is the initial write status. `raw` only occurs if processing fails mid-way.

### File Naming

`YYYYMMDD-HHMMSS-slug.md`
- Example: `20260315-143000-ux-research-methods.md`
- Timestamp: capture time (KST, +09:00)
- Slug: ASCII alphanumeric + hyphens, max 60 chars
```

- [ ] **Step 3: Commit**

```bash
cd <NANOCLAW_ROOT>
git add .claude/skills/add-second-brain/SKILL.md .claude/skills/add-second-brain/template-claude-md.md
git commit -m "feat: add /add-second-brain skill"
```

---

### Task 2: CLAUDE.md 스킬 테이블 업데이트

프로젝트 루트 `CLAUDE.md`의 Skills 테이블에 항목 추가.

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 스킬 테이블에 추가**

Skills 테이블에 다음 행 추가:

```
| `/add-second-brain` | Second brain 에이전트 설정 (볼트 + PARA + 캡처 파이프라인) |
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add /add-second-brain to skills table"
```

---

## Chunk 2: 실행 + 검증

### Task 3: 스킬 실행

- [ ] **Step 1: `/add-second-brain` 실행**

```
/add-second-brain
```

스킬의 Phase 1-5를 인터랙티브하게 따라간다. 각 AskUserQuestion에 응답하며 진행.

- [ ] **Step 2: 설정 완료 확인**

```bash
# 그룹 등록 확인
sqlite3 store/messages.db "SELECT folder, container_config FROM registered_groups WHERE folder LIKE '%second-brain%'"

# 마운트 허용 확인
cat ~/.config/nanoclaw/mount-allowlist.json

# CLAUDE.md 배포 확인
ls groups/*second-brain*/CLAUDE.md
```

---

### Task 4: E2E 검증

second-brain 채팅에서 기능별 테스트. 채널은 설정 시 선택한 것을 사용.

- [ ] **Step 1: URL 캡처**

```
https://martinfowler.com/bliki/ValueObject.html
```

Expected: inbox/에 파일 생성, frontmatter 포함, git commit, 분류 추천 회신.

- [ ] **Step 2: 텍스트 메모 캡처**

```
저장해 DDD에서 Aggregate Root는 트랜잭션 경계를 정의한다.
```

Expected: inbox/에 메모 파일, source_type: memo.

- [ ] **Step 3: PARA 관리**

```
새 리소스 만들어: DDD 패턴
```

Expected: `resources/ddd-패턴/` 생성 + git commit.

- [ ] **Step 4: 분류**

```
방금 캡처한 Value Object 노트를 DDD 패턴 리소스로 옮겨줘
```

Expected: inbox → resources 이동, status: classified.

- [ ] **Step 5: Archive 삭제 거부**

```
아카이브에서 삭제해줘
```

Expected: 거부 + "아카이브는 삭제할 수 없어요" 응답.

- [ ] **Step 6: 볼트 검색**

```
DDD에서 Value Object가 뭐야?
```

Expected: 볼트 기반 답변.

- [ ] **Step 7: 중복 캡처**

```
https://martinfowler.com/bliki/ValueObject.html
```

Expected: "이미 캡처되어 있어요" 응답.

- [ ] **Step 8: 주간 리뷰 수동 트리거**

```
주간 리뷰 실행해줘
```

Expected: 미분류 노트 목록 + 분류 추천 + 이번 주 캡처 수.

- [ ] **Step 9: 전체 완료**

모든 테스트 통과 시:

```bash
cd <NANOCLAW_ROOT>
git add -A
git commit -m "feat: second-brain setup complete"
```

실패 시: CLAUDE.md 수정 후 해당 테스트 재실행.
