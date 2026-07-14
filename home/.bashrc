# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# Omarchy defaults — override below, don't edit upstream
source ~/.local/share/omarchy/default/bash/rc

# ---------- Environment ----------
export PATH="$HOME/.local/bin:$PATH:/usr/local/go/bin"
export NNN_TMPFILE="$HOME/.config/nnn/.lastd"

# ---------- Core shell ----------
alias cl='clear'
alias df='df -h /'
l1() {
    local file="/home/x/v/mp4/study1.webm"
    if command -v mpv >/dev/null 2>&1; then
        mpv "$file"
    else
        xdg-open "$file"
    fi
}
alias la='ls -lah'
alias lr='ls -tra'
alias l="ls -l"
alias m='mv'
alias ca='cat'
alias th='touch'
alias mk='mkdir'
alias tar='tar -zxvf'
alias zip='zip -r'

mkd()    { mkdir -p "$1" && cd "$1"; }
duh()    { du -h --max-depth=1 .; }
alias du='du -h -d 1 . 2>/dev/null | sort -rh'
unpack() { mv "$1"/* . && rm -rf "$1"; }

# ---------- System ----------
alias hr='hyprctl reload'
alias nf='neofetch'
alias restart_network='sudo ip link set wlan0 down && sudo ip link set wlan0 up'
alias rnet="restart_network"
alias kill_code='killall code && pkill -9 -f vscode'
alias context_clear='omarchy-hyprland-window-close-all'

# ---------- Suspend ----------
alias sleep_history='journalctl -u systemd-suspend.service --since today'
# also toggled via SUPER+SHIFT+S
bag() {
  ~/.config/hypr/scripts/lid-suspend-timer.sh toggle-arm
  if [ -f ~/.config/hypr/.suspend-armed ]; then
    echo "on"
  else
    echo "off"
  fi
}
alias bags='~/.config/hypr/scripts/lid-suspend-timer.sh status'
_delayed_suspend() {
  systemctl --user stop delayed-suspend.timer 2>/dev/null
  systemd-run --user --on-active="${1}m" --unit=delayed-suspend systemctl suspend >/dev/null \
    && echo "Suspending in ${1}m (at $(date -d "+${1} minutes" +%H:%M))"
}
alias 30='_delayed_suspend 30'
alias 60='_delayed_suspend 60'
alias 90='_delayed_suspend 90'
alias 120='_delayed_suspend 120'
alias 180='_delayed_suspend 180'
alias 240='_delayed_suspend 240'
alias 360='_delayed_suspend 360'

alias slpc='systemctl --user stop delayed-suspend.timer 2>/dev/null && echo "Delayed suspend cancelled" || echo "No timer set"'
alias slps='systemctl --user list-timers delayed-suspend.timer --no-pager 2>/dev/null'

# ---------- Pacman ----------
alias p='sudo pacman -S'

# ---------- Editors ----------
alias vim='estop & nvim'
alias v='nvim'
alias b='nvim ~/.bashrc'
alias 1='code .'

# ---------- Git ----------
f() { git clone "$1" && cd "$(basename "${1%.git}")"; }
alias @="f"
alias 0="git add . && git commit -m 'update'"
alias 00="git push origin master"

# ---------- Cargo ----------
alias cr='cl && cargo run'

# ---------- project radar ----------
# build (if needed) and run the ~/try* obsession dashboard; args pass through
# e.g. `repos`, `repos --no-stars`, `repos --open`
repos() { ( cd ~/project-radar && cargo build --release -q && ./target/release/radar "$@" ); }

# ---------- VPN (AdGuard) ----------
alias a='adguardvpn-cli connect --fastest'
alias vpn='adguardvpn-cli connect --location=Oslo --verbose'
alias vpnd='adguardvpn-cli disconnect'
alias vpns='adguardvpn-cli status'
alias k="sudo pkill -9 -f '[a]dguard'"
alias t='k && sleep 2 && vpn'
alias vpnr='k && sleep 2 && vpn'

# ---------- Networking ----------
alias 9='ping google.com'

# ---------- Tailscale ----------
alias tsu='sudo tailscale up'
alias tsd='sudo tailscale down'
alias tss='tailscale status'
alias tsi='tailscale ip'

# ---------- IDEs (HiDPI fix) ----------
alias clion='GDK_SCALE=1 GDK_DPI_SCALE=1 clion'
alias webstorm='GDK_SCALE=1 GDK_DPI_SCALE=1 webstorm'

# ---------- Camera ----------
alias cam='guvcview'
camoff() { sudo modprobe -r uvcvideo; }
camon()  { sudo modprobe uvcvideo; }

self() {
    rm -f ~/selfie.jpg
    ffmpeg -f v4l2 -input_format mjpeg -video_size 1920x1080 -framerate 30 \
        -i /dev/video0 \
        -vf "select='gte(n,30)',tmix=frames=10,unsharp=5:5:0.8:5:5:0.0,eq=saturation=1.1" \
        -frames:v 1 -q:v 1 \
        ~/selfie.jpg
}

# ---------- Hyprland config shortcuts ----------
alias ch='c ~/.config/hypr && hr'
alias dh='c ~/.local/share/omarchy/default/hypr && hr'
alias nch='estop & nvim ~/.config/hypr && hr'
alias ndh='estop & nvim ~/.local/share/omarchy/default/hypr && hr'

# ---------- Espanso ----------
alias estop='espanso stop'
alias econf='code ~/.config/espanso'
alias estatus='pgrep -x espanso >/dev/null && echo "on" || echo "off"'
estart() {
  espanso start 2>/dev/null || { espanso service register >/dev/null 2>&1 && espanso start; }
}

# ---------- Trash ----------
alias trm='trash-put'
alias tl='trash-list'
alias trs='trash-restore'
alias tre='trash-empty'

# ---------- Snapshots ----------
alias o='omarchy-snapshot create'
alias ol='omarchy-snapshot restore'

# Delete all snapshots except the newest one in each config (home + root)
delete_snapshots() {
  for cfg in home root; do
    local ids newest todel
    ids=$(sudo snapper -c "$cfg" --csvout list --columns number | awk -F, 'NR>1 && $1!=0 {print $1}')
    newest=$(echo "$ids" | sort -n | tail -1)
    todel=$(echo "$ids" | grep -vx "$newest" | tr '\n' ' ')
    echo ">>> $cfg: keeping $newest | deleting: $todel"
    [ -n "$(echo $todel | tr -d ' ')" ] && sudo snapper -c "$cfg" delete $todel
  done
}

# ---------- BTRFS ----------
# Откат к снапшоту не освобождает место
# https://claude.ai/chat/00fcfc43-a897-4854-bda7-976bde19b544
alias filesystem_usage='sudo btrfs filesystem usage /'
alias filesystem_balance='sudo btrfs balance start -dusage=50 /'
alias diskcheck='sudo btrfs filesystem usage / | grep -E "unallocated|Metadata"'
# Прогресс/отмена balance (можно прерывать без вреда для ФС)
alias filesystem_balance_status='sudo btrfs balance status /'
alias filesystem_balance_cancel='sudo btrfs balance cancel /'

# Экстренное лечение ENOSPC на btrfs (unallocated = 1 MiB, метадате некуда
# писать, rm/balance висят): временно добавить 4G loop-устройство из RAM.
# https://claude.ai/chat/c787ae96-1871-4e98-b7f5-384abeef48b2
btrfs_rescue_add() {
    truncate -s 4G /dev/shm/r.img || return 1
    local l; l="$(sudo losetup --show -f /dev/shm/r.img)" || return 1
    sudo btrfs device add -f "$l" / && echo "added $l — now free space (rm), then run btrfs_rescue_remove $l"
}
# Ultimate balance: работает даже при unallocated = 1 MiB, когда обычный
# balance падает с ENOSPC. Полная последовательность из того же треда:
# 4G loop из RAM -> device add -> balance -> device remove -> losetup -d -> rm img.
# Каждый шаг проверяется; loop никогда не остаётся висеть в пуле.
# При Ctrl+C во время balance: filesystem_balance_cancel, потом btrfs_rescue_remove <loop>.
force_filesystem_balance() {
    local img=/dev/shm/r.img l rc=0
    if [ -e "$img" ]; then
        echo "force_filesystem_balance: $img уже существует — прошлый запуск не убрался?" >&2
        echo "Провери 'losetup -a' и 'sudo btrfs filesystem show /', потом btrfs_rescue_remove <loop>." >&2
        return 1
    fi
    truncate -s 4G "$img" || return 1
    if ! l="$(sudo losetup --show -f "$img")"; then rm -f "$img"; return 1; fi
    if ! sudo btrfs device add -f "$l" /; then
        sudo losetup -d "$l"; rm -f "$img"; return 1
    fi
    echo ">>> loop $l добавлен, запускаю balance (можно смотреть filesystem_balance_status в другом TTY)"
    sudo btrfs balance start -dusage=50 / || rc=$?
    echo ">>> убираю $l из пула"
    if ! sudo btrfs device remove "$l" /; then
        echo "device remove не прошёл — loop $l ещё в пуле! Добей вручную: btrfs_rescue_remove $l" >&2
        return 1
    fi
    sudo losetup -d "$l"
    rm -f "$img"
    sudo btrfs filesystem usage / | grep -i unallocated
    return $rc
}

# Убрать loop обратно: balance -> device remove -> losetup -d -> rm img
btrfs_rescue_remove() {
    local l="${1:-/dev/loop0}"
    sudo btrfs balance start -dusage=50 /
    sudo btrfs device remove "$l" / || return 1
    sudo losetup -d "$l"
    rm -f /dev/shm/r.img
    sudo btrfs filesystem usage / | grep -i unallocated
}

# ---------- Ranger (cd-on-quit) ----------
n() {
    local tmp; tmp="$(mktemp)"
    ranger --cmd="set colorscheme snow" --choosedir="$tmp" "$@"
    if [ -f "$tmp" ]; then
        local dir; dir="$(cat "$tmp")"
        rm -f "$tmp"
        [ -d "$dir" ] && [ "$dir" != "$PWD" ] && cd "$dir"
    fi
}

# ---------- ThinkPad LEDs ----------
_tp_leds() {
    local kbd="$1"
    local led
    for led in kbd_backlight lid_logo_dot power standby thinklight thinkvantage; do
        echo 0 | sudo tee /sys/class/leds/tpacpi::$led/brightness > /dev/null
    done
    echo 0 | sudo tee /sys/class/leds/platform::micmute/brightness > /dev/null
    echo 0 | sudo tee /sys/class/leds/platform::mute/brightness > /dev/null
    echo "$kbd" | sudo tee /sys/class/leds/tpacpi::kbd_backlight/brightness > /dev/null
}
k1() { _tp_leds 0; }
k2() { _tp_leds 1; }

# ---------- Claude ----------
# omarchy's default bash aliases set `c=opencode`; drop it so our function wins.
unalias c 2>/dev/null
c() {
  # Pre-accept the workspace trust dialog for the current directory so it
  # never prompts. (--dangerously-skip-permissions does NOT skip trust.)
  python3 - "$PWD" <<'PYEOF' 2>/dev/null
import json, os, sys
p = os.path.expanduser('~/.claude.json')
try:
    d = json.load(open(p))
except Exception:
    d = {}
proj = d.setdefault('projects', {}).setdefault(sys.argv[1], {})
proj['hasTrustDialogAccepted'] = True
json.dump(d, open(p, 'w'), indent=2)
PYEOF
  claude --dangerously-skip-permissions --permission-mode bypassPermissions "$@"
}

_claude_account() {
    CLAUDE_CONFIG_DIR=~/.claude-account-"$1" claude --dangerously-skip-permissions --permission-mode bypassPermissions "${@:2}"
}
claude1() { CLAUDE_CONFIG_DIR=~/.claude-account-a claude "$@"; }
claude2() { CLAUDE_CONFIG_DIR=~/.claude-account-b claude "$@"; }
claude3() { CLAUDE_CONFIG_DIR=~/.claude-account-c claude "$@"; }
claude4() { CLAUDE_CONFIG_DIR=~/.claude-account-d claude "$@"; }
claude5() { CLAUDE_CONFIG_DIR=~/.claude-account-f claude "$@"; }
claude6() { CLAUDE_CONFIG_DIR=~/.claude-account-e claude "$@"; }
claude7() { CLAUDE_CONFIG_DIR=~/.claude-account-g claude "$@"; }

c1() { _claude_account a "$@"; }
c2() { _claude_account b "$@"; }
c3() { _claude_account c "$@"; }
c4() { _claude_account d "$@"; }
c5() { _claude_account f "$@"; }
c6() { _claude_account e "$@"; }
c7() { _claude_account g "$@"; }



s() {
    nnn "$@"
    if [ -f "$NNN_TMPFILE" ]; then
        . "$NNN_TMPFILE"
        rm -f "$NNN_TMPFILE"
    fi
}
# ---------- YTsaurus ----------
alias y='cd /home/x/try3/ytsaurus'
alias http_proxy="cd /home/x/try3/ytsaurus/yt/yt/server/http_proxy"
alias yl="cd /tmp/yt_local"


hardware() {
    echo "CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
    echo "GPU: $(lspci | grep -E 'VGA|3D' | cut -d: -f3 | xargs)"
    echo "RAM: $(free -h | awk '/Mem:/ {print $3" / "$2}')"
}


alias h=hardware

ram() {
    echo "RAM: $(free -h | awk '/Mem:/ {print $3" / "$2}')"
}

alias r=ram

dx() { docker exec -it "$1" bash; }
alias dl="docker ps"
d1() { docker exec -it "$(docker ps -q | head -n1)" bash; }

alias clear_sublime_tabs="bash ~/s/clear-sublime-tabs"
alias cl="clear"
. "$HOME/.cargo/env"

# ---------- ninja ----------
alias n='ninja -j"$(nproc)"'
alias n16='ninja -j16'
alias n8='ninja -j8'
alias n6='ninja -j6'
alias n4='ninja -j4'
alias n3='ninja -j3'
alias n2='ninja -j2'
alias n1='ninja -j1'

alias commit="cd ~/conf && ./commit"

# open Zed in current directory
alias ,='zed -n .'

# search shell history
hx() { history | grep "$@" | tail -n 15; }

# alias x -> cd
alias x='cd'

# --- OpenClaw "Claude Code" Telegram bot (@clawbot_grnxx_bot) ---
# Start the bot (OpenClaw gateway service)
claude-bot-start()  { openclaw gateway start  && echo "Claude Code bot started"; }
# Stop the bot
claude-bot-stop()   { openclaw gateway stop   && echo "Claude Code bot stopped"; }
# Restart the bot (apply config changes)
claude-bot-restart(){ openclaw gateway restart && echo "Claude Code bot restarted"; }
# Show bot/channel status
claude-bot-status() { openclaw gateway status; openclaw channels status; }
# Tail bot logs
claude-bot-logs()   { openclaw logs; }


alias 2="cd ~/try2 && s"
alias 3="cd ~/try3 && s"
alias 4="cd ~/try4 && s"
alias 5="cd ~/try5 && s"
alias 6="cd ~/try6 && s"
# --- snapper snapshots ---
# List snapshots
alias snaps='sudo snapper list'
# Delete one or more snapshots by number, e.g. snapdel 45 46
snapdel() { sudo snapper delete "$@"; }

alias ?="pwd"
alias .="ls -la"


alias pram="sudo swapoff -a && sudo swapon -a"

. "$HOME/.local/share/../bin/env"

# Private env vars (API keys etc.) live in ~/.secrets — not tracked in git
[ -f "$HOME/.secrets" ] && . "$HOME/.secrets"

# Ultra-low-resource tdesktop Debug build ("low ninja"): 0.5 CPU pinned to
# core 0, 9G RAM cap, single job, lowest CPU/IO priority — won't freeze the PC.
lown() {
  local repo="${1:-/home/x/c/tdesktop_2}"
  docker rm -f tdesktop-rebuild 2>/dev/null
  docker run --rm --name tdesktop-rebuild \
    --cpus=0.5 --cpuset-cpus=0 --memory=9g --memory-swap=11g \
    -u "$(id -u)" -e HOME=/tmp \
    -v "$repo:/usr/src/tdesktop" \
    tdesktop-build:mz-patched \
    bash -lc 'cd /usr/src/tdesktop && nice -n 19 ionice -c3 cmake --build out --config Debug -j1'
}

# --- battery (upower) ---
# Full battery report: charge, state, health, time to empty/full, voltage, cycles
alias battery='upower -i $(upower -e | grep BAT)'
# Quick summary: just the lines that matter
batt() { upower -i "$(upower -e | grep BAT)" | grep -E 'state|percentage|capacity:|time to|energy-rate|charge-cycles'; }

# --- github: create a private repo (usage: g@ <name>) ---
alias 'g@'='gh repo create --private'

# --- github: create a public repo (usage: @+ <name>) ---
alias '@+'='gh repo create --public'
