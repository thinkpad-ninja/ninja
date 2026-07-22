#!/usr/bin/env bash
# Installs terminal-based AI coding agent CLIs (Claude Code / Kimi Code alternatives).
# Hardened to run UNATTENDED (AFK) via:  sudo bash install-ai-agents.sh
#
# Design facts this script accounts for on THIS machine:
#   * node/npm are mise-managed (~/.local/share/mise/...), NOT system.
#   * mise only activates in *interactive* shells (~/.bashrc bails when non-interactive),
#     so every "as the user" command below explicitly activates mise first — otherwise
#     a fresh login shell would fall back to system npm and install to a root-owned dir.
#   * root's PATH sees none of the user's ~/.local or mise tools, so all "is it already
#     installed?" checks and the final summary run AS THE USER, with mise active.
#   * stdin is redirected from /dev/null everywhere so nothing can hang waiting for input.

set -euo pipefail

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m[ok]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[fail]\033[0m %s\n' "$1" >&2; }

REAL_USER="${SUDO_USER:-$USER}"

# Run a command AS ROOT (system package manager only).
as_root() {
  if [[ $EUID -ne 0 ]]; then sudo "$@"; else "$@"; fi
}

# Run a command AS THE REAL USER, in a login shell WITH mise activated, stdin=/dev/null.
# This reproduces the user's real interactive tool environment (mise node/npm + ~/.local/bin).
as_user() {
  local cmd="$1"
  local prelude='command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)" 2>/dev/null; '
  if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
    sudo -u "$SUDO_USER" -H bash -lc "$prelude$cmd" </dev/null
  else
    bash -lc "$prelude$cmd" </dev/null
  fi
}

# True if <bin> is on the user's real PATH (mise active). Used for all install guards.
have() { as_user "command -v '$1' >/dev/null 2>&1"; }

if [[ $EUID -ne 0 ]]; then
  warn "Not running as root — you'll be prompted once for your sudo password (system packages only)."
fi

# ---------------------------------------------------------------------------
# 1. System prerequisites — only touch pacman if something is genuinely missing,
#    so an unattended run can't trigger a risky partial upgrade on a healthy system.
# ---------------------------------------------------------------------------
log "Checking system prerequisites"
declare -A PREREQ=( [git]=git [curl]=curl [unzip]=unzip [node]=nodejs [npm]=npm [python]=python [pipx]=python-pipx )
missing_pkgs=()
for bin in "${!PREREQ[@]}"; do
  have "$bin" || missing_pkgs+=("${PREREQ[$bin]}")
done

if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
  ok "All prerequisites already present (git, curl, unzip, node, npm, python, pipx) — skipping package manager"
else
  log "Installing missing prerequisites: ${missing_pkgs[*]}"
  if command -v pacman &>/dev/null; then
    as_root pacman -Sy --needed --noconfirm "${missing_pkgs[@]}"
  elif command -v apt-get &>/dev/null; then
    as_root apt-get update -y
    # translate a couple of Arch names to Debian names
    deb=("${missing_pkgs[@]//python-pipx/pipx}"); deb=("${deb[@]//nodejs/nodejs}"); deb=("${deb[@]//python/python3}")
    as_root apt-get install -y "${deb[@]}" || warn "apt install reported an error"
  elif command -v dnf &>/dev/null; then
    as_root dnf install -y "${missing_pkgs[@]//python-pipx/pipx}" || warn "dnf install reported an error"
  else
    warn "No known package manager — install manually: ${missing_pkgs[*]}"
  fi
fi

as_user "command -v pipx >/dev/null && python -m pipx ensurepath >/dev/null 2>&1" || true

# ---------------------------------------------------------------------------
# 2. npm-based agent CLIs (installed as the user, via mise's npm)
# ---------------------------------------------------------------------------
install_npm_cli() {
  local bin="$1" pkg="$2" label="$3"
  if have "$bin"; then
    ok "$label already installed"
    return
  fi
  log "Installing $label ($pkg)"
  if as_user "npm install -g '$pkg'"; then
    ok "$label installed"
  else
    err "$label failed to install — skipping"
  fi
}

install_npm_cli codex    "@openai/codex"                "OpenAI Codex CLI"
install_npm_cli gemini   "@google/gemini-cli"           "Google Gemini CLI"
install_npm_cli opencode "opencode-ai"                  "OpenCode"
install_npm_cli qwen     "@qwen-code/qwen-code@latest"  "Qwen Code CLI"

# ---------------------------------------------------------------------------
# 3. Grok CLI (xAI "Grok Build") — installs to ~/.grok, command is `agent`
#    (also `grok`). Detect by the install dir, not the `grok` name: a different
#    bun-installed `grok` may exist and isn't the same tool.
# ---------------------------------------------------------------------------
if as_user '[ -x "$HOME/.grok/bin/agent" ]'; then
  ok "Grok CLI already installed"
else
  log "Installing Grok CLI (xAI)"
  if as_user "curl -fsSL https://x.ai/cli/install.sh | bash"; then
    ok "Grok CLI installed"
  else
    err "Grok CLI failed to install — skipping"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Cursor CLI — its binary is ALSO named `agent`, which would clobber the
#    Grok CLI (~/.local/bin/agent). Never auto-install over that name clash.
# ---------------------------------------------------------------------------
if have cursor-agent; then
  ok "Cursor CLI already installed"
elif as_user '[ -x "$HOME/.grok/bin/agent" ]' || have agent; then
  warn "Skipping Cursor CLI: command 'agent' is taken by the Grok CLI (name clash)."
  warn "  Install Cursor manually if you want it: curl https://cursor.com/install -fsS | bash"
else
  log "Installing Cursor CLI"
  if as_user "curl https://cursor.com/install -fsS | bash"; then
    ok "Cursor CLI installed"
  else
    err "Cursor CLI failed to install — skipping"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Aider (pipx, isolated venv)
# ---------------------------------------------------------------------------
if have aider; then
  ok "Aider already installed"
else
  log "Installing Aider"
  if as_user "pipx install aider-chat"; then
    ok "Aider installed"
  else
    err "Aider failed to install — skipping"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Amazon Q Developer CLI  (best-effort: big download + AWS installer)
#    glibc >= 2.34 required (this box: 2.43 OK). Runs fully non-interactive.
# ---------------------------------------------------------------------------
if have q; then
  ok "Amazon Q Developer CLI already installed"
else
  log "Installing Amazon Q Developer CLI"
  ARCH=$(uname -m)
  Q_URL="https://desktop-release.q.us-east-1.amazonaws.com/latest/q-${ARCH}-linux.zip"
  # install.sh has no --no-confirm flag and runs an INTERACTIVE `q setup` by default
  # (would hang AFK). Q_SKIP_SETUP=1 installs the binaries to ~/.local/bin only;
  # the user runs `q login` later to authenticate. No sudo needed (user-local install).
  Q_CMD="set -e; tmp=\$(mktemp -d); cd \"\$tmp\"; \
         curl --proto '=https' --tlsv1.2 -fsSL '$Q_URL' -o q.zip; \
         unzip -qo q.zip; \
         Q_SKIP_SETUP=1 ./q/install.sh; \
         rm -rf \"\$tmp\""
  if as_user "$Q_CMD"; then
    ok "Amazon Q Developer CLI installed"
  else
    err "Amazon Q Developer CLI failed — install manually if needed (optional, non-critical)"
  fi
fi

# ---------------------------------------------------------------------------
# Summary — checked in the user's real environment (mise active).
# ---------------------------------------------------------------------------
log "Final state (as $REAL_USER, mise active):"
# Broaden PATH with non-standard user bin dirs (kimi/grok/bun/cargo live outside the
# non-interactive login PATH) so the report doesn't falsely mark them missing.
SUMMARY_PATH='export PATH="$PATH:$HOME/.local/bin:$HOME/.kimi-code/bin:$HOME/.grok/bin:$HOME/.bun/bin:$HOME/.cargo/bin"; '
# label -> command to probe
for entry in "claude:claude" "kimi:kimi" "codex:codex" "gemini:gemini" \
             "opencode:opencode" "qwen:qwen" "grok (agent):agent" \
             "cursor:cursor-agent" "aider:aider" "amazon-q:q"; do
  label="${entry%%:*}"; bin="${entry##*:}"
  path=$(as_user "${SUMMARY_PATH}command -v '$bin' 2>/dev/null" || true)
  if [[ -n "$path" ]]; then
    printf '  \033[1;32m✓\033[0m %-14s %s\n' "$label" "$path"
  else
    printf '  \033[1;31m✗\033[0m %-14s (not installed)\n' "$label"
  fi
done

cat <<'EOF'

Each agent still needs its own login/API key (interactive — cannot be scripted AFK):
  codex     -> run `codex`  (ChatGPT/OpenAI account or API key)
  gemini    -> run `gemini` (Google account or API key)
  opencode  -> `opencode auth login`
  qwen      -> run `qwen`   (DashScope/ModelStudio API key)
  agent     -> grok CLI here; for Cursor see the note above
  aider     -> set OPENAI_API_KEY / ANTHROPIC_API_KEY
  q         -> `q login`    (AWS Builder ID or IAM Identity Center)
EOF
