bash -lc "ps auxww | egrep -i '(ss-server|shadowsocks|hbbs|hbbr|rustdesk|ngrok|frpc|frps|chisel|socat|nc|ncat|xmrig|cryptominer)' | egrep -v 'egrep|grep' || true"
