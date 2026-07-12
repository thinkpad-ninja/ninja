# amnezia-watchdog

Auto-heals the AmneziaVPN tunnel after laptop suspend/resume.
Installed 2026-07-04 by Claude Code at the user's request.

## The bug it works around

On wake from sleep, `wlan0` loses carrier for ~1s and the kernel drops the
exclusion host-route AmneziaVPN added for its server
(`<server-ip> via <gateway> dev wlan0`). Encrypted WireGuard packets then
match the VPN's own `0.0.0.0/1 dev amn0` route — a routing loop into the
tunnel itself (`wireguard-go` logs `sendmmsg: message too long`). The VPN
stays dead until you disconnect/reconnect in the app. The AmneziaVPN GUI
has its own wake-reconnect attempt but it does not always fire
(e.g. 2026-07-04 10:52 in the journal: 5 minutes of dead VPN).

## What it does

`amnezia_watchdog.py` runs as root (service `amnezia-vpn-watchdog`) and
every 5s, while `amn0` exists:

- reads endpoint + fwmark live from `/var/run/amneziawg/amn0.sock` (UAPI),
- checks `ip route get <endpoint> mark <fwmark>` — if the answer is `amn0`
  (the loop), restores the exclusion route via the current default gateway
  and re-sets the peer endpoint to force an immediate re-handshake,
- pings 1.1.1.1 through the tunnel as an independent health check and runs
  the same repair on failure; if repair doesn't help, sends one desktop
  notification.

It never disconnects the tunnel and never talks to the GUI/daemon control
sockets, so it can't fight the app's own logic.

## Ops

```
systemctl status amnezia-vpn-watchdog
journalctl -u amnezia-vpn-watchdog -e            # activity log (repairs)
python3 /usr/local/lib/amnezia-watchdog/amnezia_watchdog.py --once   # one-shot diagnosis (as root)
```

## Uninstall

```
sudo systemctl disable --now amnezia-vpn-watchdog
sudo rm -rf /usr/local/lib/amnezia-watchdog /etc/systemd/system/amnezia-vpn-watchdog.service
sudo systemctl daemon-reload
```
