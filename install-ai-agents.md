# AI Coding Agent CLIs — install reference

Terminal-based AI coding agents (Claude Code / Kimi Code alternatives) and how each one is installed.

| Agent                   | Method                              |
|-------------------------|-------------------------------------|
| OpenAI Codex CLI        | `npm install -g @openai/codex`      |
| Google Gemini CLI       | `npm install -g @google/gemini-cli` |
| OpenCode                | `npm install -g opencode-ai`        |
| Qwen Code CLI (Alibaba) | `npm install -g @qwen-code/qwen-code` |
| Grok CLI (xAI, `agent`) | `curl -fsSL https://x.ai/cli/install.sh \| bash` |
| Cursor CLI (`agent`)    | official `curl \| bash` installer (skipped — clashes with Grok's `agent`) |
| Aider                   | `pipx install aider-chat`           |
| Amazon Q Developer CLI  | AWS's zip + `install.sh`            |

## Design notes (script is meant to run AFK)

- **One sudo prompt, up front** — needed only for `pacman` system packages. Everything else runs as your real user.
- **npm globals run as *you*, not root** — your `npm` is mise-managed (`~/.local/share/mise/...`), so `sudo npm -g` wouldn't find it. Global installs go through your user shell so they land in the mise bin dir like your existing agents.
- **Home-dir installers run as your user too** — Cursor's `curl | bash`, `pipx`, and Aider run via your login shell (never root), so nothing in `~/.local`, `~/.npm`, or `~/.config` ends up root-owned.
- **Idempotent** — every install is gated on `command -v <bin>`; re-running just fills gaps. (Caveat: `agent` is ambiguous — Grok's CLI also uses that name, so the Cursor check may false-positive on this machine.)
- **Fail-soft** — one tool failing (e.g. network drop) logs `[fail]` and moves on instead of aborting the run. A PATH summary prints at the end.
- **No unattended login** — the script only places binaries. Each agent still needs its own interactive OAuth or a pasted API key, done by you when you're back.

## Current status on this machine (2026-07-22)

All installed and verified runnable: `claude`, `kimi`, `codex`, `gemini`, `opencode`,
`qwen`, `aider`, `agent` (Grok), and `q` (Amazon Q, v1.19.7 — installed during verification).
`cursor-agent` is intentionally **not** installed: Cursor's binary is also named `agent`
and would clobber the Grok CLI, so the script skips it by design.

### Notes from deep verification (things that would have broken an AFK run)
- **mise is interactive-only.** `~/.bashrc` bails on non-interactive shells, so a plain
  `sudo -u you bash -lc` finds *system* npm (root-owned global dir) instead of mise's.
  The script activates mise explicitly in every user-context command.
- **All guards run as you, not root.** Root's PATH can't see `~/.local`/mise, so guards
  running as root would falsely reinstall everything (and clobber Grok's `agent`).
- **Amazon Q installer is interactive by default.** It has no `--no-confirm` flag; it runs
  `q setup` (interactive) unless `Q_SKIP_SETUP=1` is set. The script sets it and installs
  to `~/.local/bin` (no sudo). Run `q login` yourself afterward.
- **stdin is `/dev/null` everywhere** so nothing can hang waiting for input while you're away.

## Post-install: logins (interactive, not scriptable)

| Agent      | Login |
|------------|-------|
| `codex`    | run `codex`, sign in with ChatGPT/OpenAI account or API key |
| `gemini`   | run `gemini`, sign in with Google account or API key |
| `opencode` | `opencode auth login` |
| `qwen`     | needs a DashScope / ModelStudio API key |
| `agent`    | (Cursor) `agent login` — note Grok also owns this name here |
| `aider`    | set `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` env var |
| `q`        | `q login` (AWS Builder ID or IAM Identity Center) |
