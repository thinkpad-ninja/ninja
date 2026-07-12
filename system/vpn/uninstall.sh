#!/bin/sh
# Removes the AmneziaVPN watchdog. Needs root (see install.sh header for the
# docker/nsenter form used on this laptop).
set -e
systemctl disable --now amnezia-vpn-watchdog.service 2>/dev/null || true
rm -f /etc/systemd/system/amnezia-vpn-watchdog.service
rm -rf /usr/local/lib/amnezia-watchdog
systemctl daemon-reload
echo "removed."
