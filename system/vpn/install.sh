#!/bin/sh
# Installs the AmneziaVPN suspend/resume watchdog from this folder.
# Needs root (run via sudo, or on this laptop:
#   docker run --rm --privileged --pid=host alpine nsenter -t 1 -m -u -i -n -p -- \
#     sh -c 'cd /home/x/conf/system/vpn && ./install.sh'
# )
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST=/usr/local/lib/amnezia-watchdog

install -d -m 755 "$DEST"
install -m 755 -o root -g root "$HERE/amnezia_watchdog.py"       "$DEST/"
install -m 644 -o root -g root "$HERE/README.md"                 "$DEST/"
install -m 644 -o root -g root "$HERE/amnezia-vpn-watchdog.service" /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now amnezia-vpn-watchdog.service
systemctl is-active amnezia-vpn-watchdog.service
echo "installed. logs: journalctl -u amnezia-vpn-watchdog -e"
