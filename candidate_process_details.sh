#!/usr/bin/env bash
set -u

# --- Config (uguale al report) ---
WATCH_PROCS_REGEX='(ss-server|shadowsocks|hbbs|hbbr|rustdesk|ngrok|frpc|frps|chisel|socat|nc|ncat|xmrig|cryptominer)'

# --- Helpers ---
join_by_comma() { local IFS=,; echo "$*"; }

has_flag() {
  local needle="$1"; shift
  local f
  for f in "$@"; do [[ "$f" == "$needle" ]] && return 0; done
  return 1
}

# --- 1) Estrazione PID (ss + ps watchlist), deduplica ---
extract_candidate_pids() {
  local p1 p2

  # PID da ss (connessioni + processi associati)
  p1="$(
    ss -H -tunap 2>/dev/null \
    | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' \
    | sort -u \
    || true
  )"

  # PID da ps match watch regex (cmdline)
  p2="$(
    ps auxww 2>/dev/null \
    | grep -Ei "$WATCH_PROCS_REGEX" \
    | grep -Ev 'egrep|grep' \
    | awk '{print $2}' \
    | sort -u \
    || true
  )"

  # Unione + rimozione vuoti + deduplica
  printf "%s\n%s\n" "$p1" "$p2" | awk 'NF' | sort -u
}

# --- 2) Candidate Process Details per PID ---
print_candidate_process_details() {
  local pid="$1"

  [[ -d "/proc/$pid" ]] || return 0

  local exe user cmd cwd
  exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)"
  user="$(stat -c '%U' "/proc/$pid" 2>/dev/null || true)"
  cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
  cwd="$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)"

  local flags=()

  # watched-process: match su exe o cmdline
  if printf '%s %s' "$exe" "$cmd" | grep -Eqi "$WATCH_PROCS_REGEX"; then
    flags+=("watched-process")
  fi

  # exec-from-temp: exe in temp dirs
  if [[ -n "${exe:-}" ]] && [[ "$exe" =~ ^(/tmp/|/var/tmp/|/dev/shm/) ]]; then
    flags+=("exec-from-temp")
  fi

  # running-as-root
  if [[ "${user:-}" == "root" ]]; then
    flags+=("running-as-root")
  fi

  # Classificazione INFO/WARN/BAD
  local status="INFO"
  if has_flag "watched-process" "${flags[@]}" || has_flag "exec-from-temp" "${flags[@]}"; then
    status="BAD"
  elif ((${#flags[@]} > 0)); then
    status="WARN"
  fi

  # Flags string
  local flags_str="—"
  if ((${#flags[@]} > 0)); then
    flags_str="$(join_by_comma "${flags[@]}")"
  fi

  # Output “compatto” come nel report testuale
  echo "PID $pid"
  echo "$status"
  echo "User: ${user:-N/A}"
  echo "Exe: ${exe:-N/A}"
  echo "Flags: $flags_str"
  # Se vuoi anche i dettagli grezzi (ps/cmd/cwd), scommenta:
  # echo "ps: $(ps -fp "$pid" 2>/dev/null | tail -n +2 || true)"
  # echo "Cmd: ${cmd:-N/A}"
  # echo "Cwd: ${cwd:-N/A}"
}

main() {
  local pids
  mapfile -t pids < <(extract_candidate_pids)

  # Stampa in ordine numerico (già sort -u), uno dopo l’altro
  local pid
  for pid in "${pids[@]}"; do
    print_candidate_process_details "$pid"
  done
}

main "$@"

