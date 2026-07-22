# AI agents — machine notes (2026-07-22)

## Installed coding agents
| Command        | Tool                | Location |
|----------------|---------------------|----------|
| `claude`       | Claude Code         | `~/.local/bin/claude` |
| `kimi`         | Kimi Code           | `~/.kimi-code/bin/kimi` |
| `codex`        | OpenAI Codex CLI    | mise node bin |
| `gemini`       | Google Gemini CLI   | mise node bin |
| `opencode`     | OpenCode            | `/usr/bin/opencode` |
| `qwen`         | Qwen Code CLI       | mise node bin |
| `agent`        | Grok CLI (xAI)      | `~/.grok/bin/agent` |
| `cursor-agent` | Cursor CLI          | `~/.local/share/cursor-agent/...` |
| `aider`        | Aider               | `~/.local/bin/aider` |
| `q`            | Amazon Q Developer  | `~/.local/bin/q` |

## The `agent` name clash (Grok vs Cursor)
Both Grok and Cursor install a binary called `agent`. Cursor's installer
overwrites `~/.local/bin/agent`. Current setup:
- `agent`        -> Grok  (restored; original state)
- `cursor-agent` -> Cursor (use this to launch Cursor)

Flip `agent` to launch Cursor instead:
```
ln -sf ~/.local/share/cursor-agent/versions/2026.07.17-3e2a980/cursor-agent ~/.local/bin/agent
```
Restore `agent` back to Grok:
```
ln -sf ~/.grok/bin/agent ~/.local/bin/agent
```

## Logins (interactive, per agent — not scriptable)
- `codex`    — run `codex` (ChatGPT/OpenAI account or API key)
- `gemini`   — run `gemini` (Google account or API key)
- `opencode` — `opencode auth login`
- `qwen`     — DashScope / ModelStudio API key
- `agent`    — run `agent` (Grok / xAI account); Cursor: `cursor-agent login`
- `aider`    — set `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`
- `q`        — `q login` (AWS Builder ID or IAM Identity Center)

## Reinstall / verify everything
```
~/conf/install-ai-agents.sh          # safe to re-run; idempotent
```
Full reference: `~/conf/install-ai-agents.md`
