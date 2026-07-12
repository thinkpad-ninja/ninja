#!/usr/bin/env python3
"""AmneziaVPN tunnel watchdog — auto-heals the VPN after suspend/resume.

Problem this fixes (diagnosed 2026-07-04 from the journal):
  On wake from sleep, wlan0 briefly loses carrier and the kernel drops the
  exclusion host-route that AmneziaVPN added for its server endpoint
  (e.g. "<server-ip> via <gateway-ip> dev wlan0"). After that, the
  encrypted WireGuard UDP packets match the VPN's own "0.0.0.0/1 dev amn0"
  route — a routing loop into the tunnel itself. wireguard-go then logs
  "sendmmsg: message too long" forever and the VPN is dead until the user
  manually disconnects/reconnects in the GUI.

What this daemon does, every few seconds, while the tunnel exists:
  1. Reads the live tunnel config (endpoint, fwmark) from the amneziawg
     UAPI socket, so it follows server changes automatically.
  2. Simulates the routing decision for an encrypted packet
     ("ip route get <endpoint> mark <fwmark>"). If it would be routed into
     amn0 — the loop — it restores the exclusion route via the current
     default gateway and re-sets the peer endpoint to force an immediate
     re-handshake.
  3. Independently probes the tunnel with a ping and runs the same repair
     if the tunnel stops passing traffic; if repair doesn't help
     (e.g. server down), it sends one desktop notification.

It never tears the tunnel down and never touches the daemon or GUI, so it
cannot fight AmneziaVPN's own reconnect logic; the worst it does is
re-add the same route AmneziaVPN itself would add.

Runs as root from amnezia-vpn-watchdog.service. See README.md next to
this file for uninstall instructions.
"""

import json
import os
import socket
import subprocess
import sys
import time

IFACE = "amn0"
UAPI_PATH = f"/var/run/amneziawg/{IFACE}.sock"
DEFAULT_FWMARK = 0x80000          # what amnezia uses; UAPI value overrides
PROBE_TARGETS = ("1.1.1.1", "1.0.0.1")   # the DNS servers amnezia routes via the tunnel
POLL_SECONDS = 5
PROBE_EVERY_N_CYCLES = 4          # ping probe cadence while everything looks healthy
FAILS_BEFORE_REPAIR = 2
FAILS_BEFORE_NOTIFY = 6
NOTIFY_USER = "x"
NOTIFY_UID = 1000


def log(msg):
    print(msg, flush=True)


def sh(*args):
    p = subprocess.run(args, capture_output=True, text=True)
    return p.returncode, p.stdout.strip()


def uapi(request: str) -> str:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(2)
    try:
        s.connect(UAPI_PATH)
        s.sendall(request.encode())
        buf = b""
        while b"\n\n" not in buf:
            chunk = s.recv(4096)
            if not chunk:
                break
            buf += chunk
        return buf.decode(errors="replace")
    finally:
        s.close()


def uapi_get():
    """Returns (interface_dict, [peer_dicts]) from the live wireguard-go config."""
    text = uapi("get=1\n\n")
    iface, peers, cur = {}, [], None
    for line in text.splitlines():
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        if k == "public_key":
            cur = {}
            peers.append(cur)
        if k == "errno" and v != "0":
            raise RuntimeError(f"UAPI errno={v}")
        (cur if cur is not None else iface)[k] = v
    return iface, peers


def first_endpoint(peers):
    """Returns (endpoint_ip, endpoint, peer_public_key) of the first peer."""
    for p in peers:
        ep = p.get("endpoint")
        if ep:
            ip = ep.rsplit(":", 1)[0].strip("[]")
            return ip, ep, p["public_key"]
    return None, None, None


def route_dev(ip, fwmark):
    """Which device would a packet to `ip` with `fwmark` leave through?"""
    cmd = ["ip", "-j", "route", "get", ip]
    if fwmark:
        cmd += ["mark", hex(fwmark)]
    rc, out = sh(*cmd)
    if rc != 0 or not out:
        return None
    try:
        routes = json.loads(out)
        return routes[0].get("dev") if routes else None
    except (json.JSONDecodeError, IndexError):
        return None


def default_route():
    rc, out = sh("ip", "-j", "route", "show", "default")
    if rc != 0:
        return None
    try:
        cands = [r for r in json.loads(out or "[]")
                 if r.get("gateway") and r.get("dev") not in (IFACE, "tailscale0")]
    except json.JSONDecodeError:
        return None
    return min(cands, key=lambda r: r.get("metric", 0)) if cands else None


def restore_exclusion_route(ep_ip):
    dr = default_route()
    if not dr:
        return False
    rc, _ = sh("ip", "route", "replace", f"{ep_ip}/32",
               "via", dr["gateway"], "dev", dr["dev"])
    if rc == 0:
        log(f"restored exclusion route: {ep_ip}/32 via {dr['gateway']} dev {dr['dev']}")
        return True
    return False


def renudge_endpoint(peer_pub, endpoint):
    """Re-set the peer endpoint (same value) to make wireguard-go re-handshake now."""
    try:
        resp = uapi(f"set=1\npublic_key={peer_pub}\nendpoint={endpoint}\n\n")
        ok = "errno=0" in resp
        log(f"re-set peer endpoint {endpoint}: {'ok' if ok else resp.strip()}")
    except OSError as e:
        log(f"endpoint re-set failed: {e}")


def tunnel_ping_ok():
    for target in PROBE_TARGETS:
        rc = subprocess.run(
            ["ping", "-n", "-c", "1", "-W", "2", "-I", IFACE, target],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
        if rc == 0:
            return True
    return False


def notify_user(message):
    try:
        subprocess.run(
            ["sudo", "-u", NOTIFY_USER, "env",
             f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{NOTIFY_UID}/bus",
             "notify-send", "-u", "critical", "-t", "15000",
             "Amnezia VPN watchdog", message],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    except Exception:
        pass


def diagnose_once():
    if not os.path.exists(f"/sys/class/net/{IFACE}"):
        print(f"{IFACE}: not present (VPN disconnected) — nothing to do")
        return 0
    iface, peers = uapi_get()
    ep_ip, ep, pub = first_endpoint(peers)
    fwmark = int(iface.get("fwmark", DEFAULT_FWMARK))
    dev = route_dev(ep_ip, fwmark) if ep_ip else None
    dr = default_route()
    hs = next((p.get("last_handshake_time_sec") for p in peers
               if p.get("last_handshake_time_sec")), None)
    hs_age = (int(time.time()) - int(hs)) if hs else None
    ping = tunnel_ping_ok()
    print(f"endpoint            : {ep}")
    print(f"fwmark              : {hex(fwmark)}")
    print(f"encrypted pkts exit : {dev} {'(ROUTING LOOP!)' if dev == IFACE else ''}")
    print(f"default route       : {dr}")
    print(f"last handshake age  : {hs_age}s")
    print(f"tunnel ping         : {'ok' if ping else 'FAIL'}")
    healthy = ping and dev != IFACE
    print(f"verdict             : {'healthy' if healthy else 'broken'}")
    return 0 if healthy else 1


def main_loop():
    log(f"amnezia watchdog started (iface={IFACE}, poll={POLL_SECONDS}s)")
    cycle = 0
    fails = 0
    notified = False
    while True:
        time.sleep(POLL_SECONDS)
        cycle += 1

        if not os.path.exists(f"/sys/class/net/{IFACE}"):
            fails, notified = 0, False   # VPN intentionally off / reconnecting
            continue

        try:
            iface, peers = uapi_get()
        except (OSError, RuntimeError):
            continue                     # daemon busy (re)configuring — retry next cycle

        ep_ip, ep, pub = first_endpoint(peers)
        if not ep_ip:
            continue

        if default_route() is None:
            fails, notified = 0, False   # no underlay network (wifi down) — just wait
            continue

        fwmark = int(iface.get("fwmark", DEFAULT_FWMARK))
        probe_now = fails > 0 or cycle % PROBE_EVERY_N_CYCLES == 0

        if route_dev(ep_ip, fwmark) == IFACE:
            log(f"routing loop detected: encrypted packets to {ep_ip} would exit via {IFACE}")
            if restore_exclusion_route(ep_ip):
                renudge_endpoint(pub, ep)
            probe_now = True
            fails = max(fails, 1)        # keep probing until recovery is confirmed

        if not probe_now:
            continue

        if tunnel_ping_ok():
            if fails >= FAILS_BEFORE_REPAIR or notified:
                log("tunnel healthy again")
            fails, notified = 0, False
            continue

        fails += 1
        if fails == FAILS_BEFORE_REPAIR:
            log("tunnel unresponsive — running repair (exclusion route + endpoint re-set)")
            restore_exclusion_route(ep_ip)
            renudge_endpoint(pub, ep)
        if fails == FAILS_BEFORE_NOTIFY and not notified:
            log("repair did not recover the tunnel — notifying user")
            notify_user("VPN tunnel is down and automatic repair failed. "
                        "Toggle the connection in the AmneziaVPN app.")
            notified = True


if __name__ == "__main__":
    if "--once" in sys.argv:
        sys.exit(diagnose_once())
    main_loop()
