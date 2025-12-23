# Sentinel Report (sentinel_report)

A **root-only**, **read-only** Linux triage script that produces a single **HTML incident snapshot** (plus a raw log)
to help you quickly spot suspicious network activity, persistence, and access on an Ubuntu host.

> This repository contains the script: `sentinel_report`.

---

## What the script does

When executed, the script:

1. **Refuses to run unless you are root**
   - It checks `EUID` and exits with an error message if not run as root.

2. **Creates timestamped output files**
   - HTML report: `/tmp/sentinel_report_<host>_<YYYY-MM-DD_HHMMSS>.html`
   - Raw log:      `/tmp/sentinel_report_<host>_<YYYY-MM-DD_HHMMSS>.log`

3. **Collects baseline host + network context**
   - `uname -a` (kernel/arch)
   - `lsb_release -a` (distro metadata)
   - `uptime`
   - `ip -brief addr` (interfaces/IPs)
   - `ip route` (routing)

4. **Captures network activity via `ss` and highlights “interesting” entries**
   - **Established connections**: `ss -H -tunap state established`
   - **Listening sockets**:       `ss -H -tulnp`

   The HTML report turns these into tables and adds a *Flags* column to quickly indicate common “red flags”, e.g.:
   - Listener bound to all interfaces (`0.0.0.0:*` or `[::]:*`)
   - Matches on a watchlist of suspicious/commonly abused tools (see “Watched indicators”)

5. **Scans for watched/suspicious processes**
   - Runs: `ps auxww | egrep -i "$WATCH_PROCS_REGEX" | egrep -v 'egrep|grep'`
   - This is meant to quickly catch common remote-access / tunneling / proxy / crypto-mining
     process names (see below).

6. **Extracts “candidate PIDs” and expands details**
   - Candidate PIDs are assembled from:
     - PIDs found in `ss -H -tunap` output (`pid=...`)
     - PIDs found by the watched-process `ps` scan
   - For each candidate PID, the HTML report includes:
     - `ps -fp <pid>`
     - `/proc/<pid>/cmdline` (shown as a readable single-line string)
     - `/proc/<pid>/cwd`
     - `/proc/<pid>/exe`
     - Owner (via `stat -c '%U' /proc/<pid>`)
   - The report also applies **flags** such as:
     - “watched-process” (process name matches watch regex)
     - “exec-from-temp” (executable path in places like `/tmp`, `/var/tmp`, `/dev/shm`, etc.)

7. **Summarizes systemd services and “interesting unit files”**
   - Running services: `systemctl --type=service --state=running`
   - Unit-file search (keyword scan for commonly abused names):
     - `systemctl list-unit-files | egrep -i 'shadowsocks|rustdesk|hbbs|hbbr|ngrok|frp|chisel|socat'`

8. **Reports firewall and rulesets**
   - `ufw status verbose`
   - `iptables -S`
   - `nft list ruleset`

9. **Shows current and recent access**
   - Current sessions: `who`
   - Current activity: `w`
   - Recent logins: `last -i | head -n 50`
   - Failed logins: `lastb -i | head -n 50` (if available)

10. **Checks common persistence locations**
    - Root crontab: `crontab -l`
    - All user crontabs (iterating `/etc/passwd`)
    - Cron directories listing:
      - `/etc/cron.d`, `/etc/cron.daily`, `/etc/cron.hourly`, `/etc/cron.weekly`, `/etc/cron.monthly`
    - Recent files in temp-like locations:
      - `/tmp`, `/var/tmp`, `/dev/shm` (top 100, newest first)
    - SUID binaries (top 200 on the same filesystem)

11. **Collects logs and performs a quick keyword scan**
    - `journalctl -u ssh --since '7 days ago' | tail -n 500`
    - A “keyword scan” in the last 48h:
      - `journalctl --since '48 hours ago' | egrep -i 'ss-server|shadowsocks|rustdesk|ngrok|frp|chisel' | tail -n 500`

12. **Builds a navigable HTML dashboard**
    - Sidebar navigation with anchors
    - “Copy command” buttons that copy the underlying command to the clipboard
    - A small summary grid with counts (established connections, listening sockets, watched items)
    - A final “Notes” section suggesting what to investigate next

---

## Watched indicators

The script uses two configurable regular expressions near the top:

```bash
WATCH_PROCS_REGEX='(ss-server|shadowsocks|hbbs|hbbr|rustdesk|ngrok|frpc|frps|chisel|socat|nc|ncat|xmrig|cryptominer)'
WATCH_PORTS_REGEX='(:5588|:21118|:21119|:1080|:10808|:10809|:3333|:4444|:5555|:6666|:7777|:8888|:9999)'
```

- **`WATCH_PROCS_REGEX`** targets process names commonly associated with:
  - tunneling (ngrok, chisel, frp)
  - remote desktop / RAT-like tooling (rustdesk hbbs/hbbr)
  - proxies / SOCKS (socat, nc/ncat)
  - crypto-mining (xmrig, generic “cryptominer”)
- **`WATCH_PORTS_REGEX`** flags sockets that match a small set of ports often seen in
  ad‑hoc tunnels, proxies, or remote tooling defaults.

These are heuristics: **a match is a lead, not proof**. Update the regexes to fit your environment.

---

## Output files

After completion, you will see:

- `HTML report saved to: /tmp/sentinel_report_<host>_<timestamp>.html`
- `Raw log saved to:    /tmp/sentinel_report_<host>_<timestamp>.log`

The HTML is designed to be opened locally:

```bash
xdg-open /tmp/sentinel_report_<host>_<timestamp>.html
```

---

## Requirements

- Linux system with:
  - `bash`
  - `ss` (usually from `iproute2`)
  - `ip`
  - `ps`
  - `systemctl` (systemd)
  - `journalctl`
  - `ufw` (optional; command may fail gracefully if not installed)
  - `iptables` and/or `nft` (the script will attempt both)
  - `last`, `lastb` (the `lastb` database may not exist on every system)
- **Root privileges** (required).

The script is resilient: many commands are wrapped so failures won’t abort the report (even though it uses
`set -euo pipefail`).

---

## Usage

```bash
chmod +x sentinel_report
sudo ./sentinel_report
```

If you want to keep outputs somewhere else, copy them after generation:

```bash
sudo cp /tmp/sentinel_report_*.{html,log} /path/to/case-folder/
```

---

## Security & privacy notes

- The script is **read-only**: it does not edit configuration, kill processes, or change firewall rules.
- The HTML may contain **sensitive information** (usernames, command lines, IPs, routes, firewall rules).
  Treat it as incident evidence and store it securely.
- If you plan to share the report externally, redact:
  - hostnames / internal IPs
  - usernames
  - command lines containing secrets/tokens
  - any identified customer or internal infrastructure identifiers

---

## Customization

Common changes you might want:

- Extend the watchlists:
  - Edit `WATCH_PROCS_REGEX` and `WATCH_PORTS_REGEX`
- Add more checks:
  - Follow the existing `card_pre` pattern for commands that should be embedded as `<pre>`
  - Or use `card_html` if you are generating custom HTML fragments

---

## Troubleshooting

- **“ERROR: run as root”**
  - Run with `sudo` (the script needs access to `/proc/<pid>` details and `lastb`, plus firewall reads).
- **`ufw: command not found` / `nft: command not found`**
  - Safe to ignore; the script will still complete.
- **Large HTML file**
  - Log sections use `tail` to reduce size, but some hosts can still produce large outputs.

---
