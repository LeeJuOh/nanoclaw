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
git config --local credential.helper "store --file=.git-credentials"
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
