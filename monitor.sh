#!/usr/bin/env bash

# ==========================================================
# Remote monitoring script - required output style
# ==========================================================

SESSION_NAME="[A**IONOS!!]"

# Get the first non-loopback IP address (you can replace it with a fixed IP if you prefer)
IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$IP_ADDR" ] && IP_ADDR="0.0.0.0"

echo
echo "Remote-monitoring information for session ${SESSION_NAME} - ${IP_ADDR}"
echo
echo

# ----------------------------------------------------------
# Host
# ----------------------------------------------------------
echo "- Host:"
echo "    Hostname: $(hostname)"
echo "    Version:  $(cat /proc/version)"
echo

# ----------------------------------------------------------
# CPU
# ----------------------------------------------------------
CPU_LOAD=$(LC_ALL=C top -bn1 2>/dev/null | awk '/Cpu\(s\)/{printf "%d%%", 100-$8+0.5}')
if [ -z "$CPU_LOAD" ]; then
    # Fallback to mpstat if top does not work
    CPU_LOAD=$(LC_ALL=C mpstat 1 1 2>/dev/null | awk '/Average:/ && $3 ~ /all/ {printf "%d%%", 100-$13+0.5}')
fi
[ -z "$CPU_LOAD" ] && CPU_LOAD="N/A"

echo "- CPU:"
echo "    Current CPU load:  $CPU_LOAD"
echo

# ----------------------------------------------------------
# RAM
# ----------------------------------------------------------
# free -m for total/used/available
read _ total used free _ buff_cache available < <(free -m | awk 'NR==2{print $1,$2,$3,$4,$5,$6,$7}')

# /proc/meminfo for Cache and Buffers in MB
buffers=$(awk '/^Buffers:/{printf "%d", $2/1024}' /proc/meminfo)
cached=$(awk '/^Cached:/{printf "%d", $2/1024}' /proc/meminfo)

echo "- RAM:"
printf "    Total RAM:     %s MB\n" "$total"
printf "    Used RAM:      %s MB\n" "$used"
printf "    Available RAM: %s MB\n" "$available"
printf "    Cached RAM:    %s MB\n" "$cached"
printf "    Buffers:       %s MB\n" "$buffers"
echo

# ----------------------------------------------------------
# NET (upload/download)
# ----------------------------------------------------------
# Print upload/download totals for each interface (excluding loopback)
print_net_stats() {
    local dir_label="$1"  # upload / download

    echo "- Net (${dir_label}):"

    for iface in /sys/class/net/*; do
        iface=$(basename "$iface")
        # Skip loopback and common virtual interfaces
        [[ "$iface" == "lo" ]] && continue

        rx_bytes_file="/sys/class/net/$iface/statistics/rx_bytes"
        tx_bytes_file="/sys/class/net/$iface/statistics/tx_bytes"
        rx_err_file="/sys/class/net/$iface/statistics/rx_errors"
        tx_err_file="/sys/class/net/$iface/statistics/tx_errors"
        rx_drop_file="/sys/class/net/$iface/statistics/rx_dropped"
        tx_drop_file="/sys/class/net/$iface/statistics/tx_dropped"

        [ ! -r "$rx_bytes_file" ] && continue

        rx_bytes=$(cat "$rx_bytes_file")
        tx_bytes=$(cat "$tx_bytes_file")
        rx_err=$(cat "$rx_err_file")
        tx_err=$(cat "$tx_err_file")
        rx_drop=$(cat "$rx_drop_file")
        tx_drop=$(cat "$tx_drop_file")

        # Convert to kB
        rx_kb=$((rx_bytes / 1024))
        tx_kb=$((tx_bytes / 1024))

        if [ "$dir_label" = "upload" ]; then
            printf "    %s total out:      %s kB\n" "$iface" "$tx_kb"
            printf "    %s errors:         %s\n" "$iface" "$tx_err"
            printf "    %s dropped:        %s\n" "$iface" "$tx_drop"
            echo "    "
        else
            printf "    %s total in:       %s kB\n" "$iface" "$rx_kb"
            printf "    %s errors:         %s\n" "$iface" "$rx_err"
            printf "    %s dropped:        %s\n" "$iface" "$rx_drop"
            echo "    "
        fi
    done
}

print_net_stats "upload"
echo
print_net_stats "download"
echo

# ----------------------------------------------------------
# Netstat
# ----------------------------------------------------------
echo "- Netstat:"
echo "    Output of the \"netstat\" command:"

if command -v netstat >/dev/null 2>&1; then
    netstat -plant 2>/dev/null | sed 's/^/    /'
else
    # Fallback to ss if netstat is not available
    ss -plant 2>/dev/null | sed '1s/^/Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID\/Program name\n/; s/^/    /'
fi
echo

# ----------------------------------------------------------
# Uptime
# ----------------------------------------------------------
uptime_seconds=$(awk '{print $1}' /proc/uptime)
uptime_days=$(awk '{printf "%d", $1/86400}' /proc/uptime)

echo "- UpTime:"
printf "    Uptime:  %s days\n" "$uptime_days"
printf "    (%s seconds)\n" "$uptime_seconds"
echo

# ----------------------------------------------------------
# Processes
# ----------------------------------------------------------
# Total processes (excluding header)
total_proc=$(ps ax | awk 'END{print NR-1}')
# Processes in "R" (running) state
active_proc=$(ps -eo stat | awk 'NR>1 && $1 ~ /^R/ {c++} END{print c+0}')

echo "- Processes:"
printf "    Number of processes (active/total):  %s/%s\n" "$active_proc" "$total_proc"
echo

# ----------------------------------------------------------
# File descriptors
# ----------------------------------------------------------
# /proc/sys/fs/file-nr -> allocated unused max
read allocated unused max_fd < /proc/sys/fs/file-nr
opened_fd=$((allocated - unused))

echo "- File descriptors:"
printf "    Number of opened file descriptors:  %s\n" "$opened_fd"
printf "    Maximum number of file descriptors:  %s\n" "$max_fd"
echo

# ----------------------------------------------------------
# Users (who)
# ----------------------------------------------------------
echo "- Users:"
echo "    Output of the \"who\" command:"
who | sed 's/^/    /'
echo

# ----------------------------------------------------------
# Partitions (df)
# ----------------------------------------------------------
echo "- Partitions:"
echo "    Output of the \"df\" command:"
df -h | sed 's/^/    /'
echo
