# Second Brain Agent — NanoClaw Adapter

This agent uses the `second-brain` skill for all PARA knowledge management logic. This file only configures the NanoClaw-specific environment.

## Vault Path

`$VAULT` = `/workspace/extra/vault`

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

## Platform Tools

These MCP tools are available only in the NanoClaw container:

- `mcp__nanoclaw__send_message` — Send a message to the user immediately
- `mcp__nanoclaw__clear_session` — Reset the SDK session (for "세션 클리어", "컨텍스트 초기화")
- `mcp__nanoclaw__schedule_task` — Schedule recurring/one-time tasks
- `mcp__nanoclaw__list_tasks` — List scheduled tasks

## URL Crawl Fallback

If `curl` fails to fetch a URL, use `agent-browser` (available via Bash) as fallback.
