# Sentinel Report (sentinel_report)

A **root-only**, **read-only** Linux triage script that produces a single **HTML incident snapshot** (plus a raw log)
to help you quickly spot suspicious network activity, persistence, and access on a Linux host.

> This repository contains the script: `sentinel_report.sh`.

---

## What the script does

When executed, the script:

1. **Refuses to run unless you are root**
   - It checks `EUID` and exits with an error message if not run as root.

2. **Creates timestamped output files**
   - HTML report: `/tmp/sentinel_report_<host>_<YYYY-MM-DD_HHMMSS>.html`
   - Raw log:      `/tmp/sentinel_report_<host>_<YYYY-MM-DD_HHMMSS>.log`

3. **Collects baseline host and network context**
   - `uname -a`
   - `lsb_release -a`
   - `uptime`
   - `ip -brief addr`
   - `ip route`

4. **Captures network activity**
   - Established connections: `ss -H -tunap state established`
   - Listening sockets: `ss -H -tulnp`

   Results are rendered as HTML tables with automatic **flags** for:
   - Listeners bound to all interfaces (`0.0.0.0:*`, `[::]:*`)
   - Matches against watched ports or processes

5. **Scans for watched or suspicious processes**
   - `ps auxww | egrep -i "$WATCH_PROCS_REGEX"`

6. **Expands details for candidate PIDs**
   - `ps -fp <pid>`
   - `/proc/<pid>/cmdline`
   - `/proc/<pid>/cwd`
   - `/proc/<pid>/exe`
   - Process owner

7. **Summarizes systemd services**
   - Running services
   - Unit files matching common abuse keywords

8. **Firewall and rulesets**
   - `ufw status verbose`
   - `iptables -S`
   - `nft list ruleset`

9. **User access and login activity**
   - `who`, `w`
   - `last`, `lastb`

10. **Persistence checks**
    - Root and user crontabs
    - Cron directories
    - Recently modified files in `/tmp`, `/var/tmp`, `/dev/shm`
    - SUID binaries

11. **Log inspection**
    - SSH logs (last 7 days)
    - Keyword scan (last 48 hours)

12. **HTML dashboard**
    - Sidebar navigation
    - Summary counters
    - Copy-to-clipboard commands

---

## Watched indicators

```bash
WATCH_PROCS_REGEX='(ss-server|shadowsocks|hbbs|hbbr|rustdesk|ngrok|frpc|frps|chisel|socat|nc|ncat|xmrig|cryptominer)'
WATCH_PORTS_REGEX='(:5588|:21118|:21119|:1080|:10808|:10809|:3333|:4444|:5555|:6666|:7777|:8888|:9999)'
```

These indicators are **heuristics** and should be customized for your environment.

---

## Download & Integrity Verification

The recommended distribution format is the **XZ-compressed script**.

### 📦 Download

- **Compressed script (XZ):**  
  https://github.com/michele-tn/Sentinel-Report/blob/main/sentinel_report.sh.xz

- **SHA-256 checksum:**  
  https://github.com/michele-tn/Sentinel-Report/blob/main/sentinel_report.sh.xz.sha256

---

### 🔐 Verify integrity

```bash
sha256sum -c sentinel_report.sh.xz.sha256
```

Expected result:

```
sentinel_report.sh.xz: OK
```

---

### 📂 Extract

```bash
unxz sentinel_report.sh.xz
chmod +x sentinel_report.sh
```

---

## Usage

```bash
sudo ./sentinel_report.sh
```

---

## Requirements

- Linux system with `bash`
- `iproute2`, `ps`, `systemctl`, `journalctl`
- Optional: `ufw`, `iptables`, `nft`
- Root privileges

---

## Security & privacy notes

- The script is **read-only**
- The HTML report may contain sensitive data
- Always ensure proper authorization before execution

---

## License

This project is released under the **MIT License**.

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
