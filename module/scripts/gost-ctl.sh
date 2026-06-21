#!/system/bin/sh
# gost 代理守护进程
MODDIR=${0%/*}/..
GOST_BIN=$MODDIR/bin/gost
GOST_CONFIG=/data/adb/feilian-proxy/gost.yml
LOG=/data/local/tmp/feilian-proxy.log
GOST_LOG=/data/local/tmp/gost.log

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')][gost-ctl] $1" >> "$LOG"
}

# 杀掉已有的 gost 进程
pkill -f "$GOST_BIN" 2>/dev/null
sleep 1

log "守护进程启动"

# 守护循环：gost 退出后自动重启
while true; do
    $GOST_BIN -C "$GOST_CONFIG" > "$GOST_LOG" 2>&1
    EXIT_CODE=$?
    log "gost 退出 (code=$EXIT_CODE)，3秒后重启"
    sleep 3
done
