# NanoClaw

Personal Claude assistant. See [README.md](README.md) for philosophy and setup. See [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) for architecture decisions.

## Quick Context

Single Node.js process with skill-based channel system. Channels (WhatsApp, Telegram, Slack, Discord, Gmail) are skills that self-register at startup. Messages route to Claude Agent SDK running in containers (Linux VMs). Each group has isolated filesystem and memory.

## Key Files

| File | Purpose |
|------|---------|
| `src/index.ts` | Orchestrator: state, message loop, agent invocation |
| `src/channels/registry.ts` | Channel registry (self-registration at startup) |
| `src/ipc.ts` | IPC watcher and task processing |
| `src/router.ts` | Message formatting and outbound routing |
| `src/config.ts` | Trigger pattern, paths, intervals |
| `src/container-runner.ts` | Spawns agent containers with mounts |
| `src/task-scheduler.ts` | Runs scheduled tasks |
| `src/db.ts` | SQLite operations |
| `groups/{name}/CLAUDE.md` | Per-group memory (isolated) |
| `container/skills/` | Skills loaded inside agent containers (browser, status, formatting) |

## Secrets / Credentials / Proxy (OneCLI)

API keys, secret keys, OAuth tokens, and auth credentials are managed by the OneCLI gateway — which handles secret injection into containers at request time, so no keys or tokens are ever passed to containers directly. Run `onecli --help`.

## Skills

Four types of skills exist in NanoClaw. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full taxonomy and guidelines.

- **Feature skills** — merge a `skill/*` branch to add capabilities (e.g. `/add-telegram`, `/add-slack`)
- **Utility skills** — ship code files alongside SKILL.md (e.g. `/claw`)
- **Operational skills** — instruction-only workflows, always on `main` (e.g. `/setup`, `/debug`)
- **Container skills** — loaded inside agent containers at runtime (`container/skills/`)

| Skill | When to Use |
|-------|-------------|
| `/setup` | First-time installation, authentication, service configuration |
| `/customize` | Adding channels, integrations, changing behavior |
| `/debug` | Container issues, logs, troubleshooting |
| `/update-nanoclaw` | Bring upstream NanoClaw updates into a customized install |
| `/init-onecli` | Install OneCLI Agent Vault and migrate `.env` credentials to it |
| `/qodo-pr-resolver` | Fetch and fix Qodo PR review issues interactively or in batch |
| `/get-qodo-rules` | Load org- and repo-level coding rules from Qodo before code tasks |
| `/add-second-brain` | Second brain 에이전트 설정 (볼트 + PARA + 캡처 파이프라인) |

## Contributing

Before creating a PR, adding a skill, or preparing any contribution, you MUST read [CONTRIBUTING.md](CONTRIBUTING.md). It covers accepted change types, the four skill types and their guidelines, SKILL.md format rules, PR requirements, and the pre-submission checklist (searching for existing PRs/issues, testing, description format).

## References

`references/` 디렉터리의 프로젝트들은 모두 세컨드 브레인 그룹 개발을 위한 참고 자료.

| Project | Type | Purpose |
|---------|------|---------|
| [khoj](references/khoj) | Python | AI 세컨드 브레인 — 전체 아키텍처, 자동화, 에이전트 설계 참고 |
| [memsearch](references/memsearch) | Python | 시맨틱 메모리 검색 엔진 — 임베딩, 하이브리드 검색(BM25+벡터), CC 플러그인 참고 |
| [qmd](references/qmd) | Bun/TS | 마크다운 문서 쿼리 엔진 — FTS5, sqlite-vec, MCP 서버, 컬렉션 관리 참고 |
| [claudian](references/claudian) | Node/TS | Obsidian Claude Code 플러그인 — 사이드바 UI, SDK 통합, 스킬/에이전트 구조 참고 |
| [openclaw](references/openclaw) | Node/TS | 오픈소스 에이전트 프레임워크 (nanoclaw upstream) — 플러그인 시스템, 채널 아키텍처 참고 |
| [PageIndex](references/PageIndex) | — | Vectorless RAG — 추론 기반 검색, 벡터 없는 접근 방식 참고 |
| [cli-jaw](references/cli-jaw) | Node/TS | 멀티 AI 엔진 CLI 어시스턴트 — 여러 LLM 통합 패턴 참고 |
| [obsidian-skills](references/obsidian-skills) | — | Obsidian 에이전트 스킬 — 스킬 스펙, 구조화된 에이전트 스킬 참고 |
| [symphony](references/symphony) | — | 자율 코딩 에이전트 오케스트레이터 — Linear 연동, 에이전트 스웜 관리 참고 |

전체 31개 프로젝트 목록과 채택/미채택 근거: [references-analysis.md](docs/superpowers/specs/2026-03-28-references-analysis.md)

## Development

Run commands directly—don't tell the user to run them.

```bash
npm run dev          # Run with hot reload
npm run build        # Compile TypeScript
./container/build.sh # Rebuild agent container
```

Service management:
```bash
# macOS (launchd)
launchctl load ~/Library/LaunchAgents/com.nanoclaw.plist
launchctl unload ~/Library/LaunchAgents/com.nanoclaw.plist
launchctl kickstart -k gui/$(id -u)/com.nanoclaw  # restart

# Linux (systemd)
systemctl --user start nanoclaw
systemctl --user stop nanoclaw
systemctl --user restart nanoclaw
```

## Troubleshooting

**WhatsApp not connecting after upgrade:** WhatsApp is now a separate skill, not bundled in core. Run `/add-whatsapp` (or `npx tsx scripts/apply-skill.ts .claude/skills/add-whatsapp && npm run build`) to install it. Existing auth credentials and groups are preserved.

## Container Build Cache

The container buildkit caches the build context aggressively. `--no-cache` alone does NOT invalidate COPY steps — the builder's volume retains stale files. To force a truly clean rebuild, prune the builder then re-run `./container/build.sh`.
