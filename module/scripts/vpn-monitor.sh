#!/system/bin/sh
# VPN 守护进程 - 检测飞连 VPN 断开时自动重连
MODDIR=${0%/*}/..
LOG=/data/local/tmp/feilian-proxy.log

FEILIAN_PACKAGE="com.volcengine.corplink"
FEILIAN_TILE="com.volcengine.corplink/com.bytedance.topgo.widget.QSTileService"
FEILIAN_ACTIVITY="com.volcengine.corplink/com.bytedance.topgo.activity.SplashActivity"
CHECK_INTERVAL=120
RETRY_INTERVAL=10

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')][vpn-monitor] $1" >> "$LOG"
}

check_vpn() {
    ls /sys/class/net/tun0 >/dev/null 2>&1
}

ensure_app_alive() {
    if ! pidof "$FEILIAN_PACKAGE" >/dev/null 2>&1; then
        log "飞连进程不存在，启动 app"
        am start -n "$FEILIAN_ACTIVITY" >/dev/null 2>&1
        sleep 3
    fi
}

reconnect_vpn() {
    ensure_app_alive
    # 拉到前台，确保 QS Tile 能正常响应
    am start -n "$FEILIAN_ACTIVITY" >/dev/null 2>&1
    sleep 2
    log "触发 QS Tile 连接 VPN"
    cmd statusbar click-tile "$FEILIAN_TILE"
    sleep 5
    if check_vpn; then
        log "VPN 重连成功"
        return 0
    else
        log "VPN 重连失败"
        return 1
    fi
}

log "守护进程启动"

while true; do
    if ! check_vpn; then
        log "检测到 VPN 断开"
        RETRIES=0
        while [ $RETRIES -lt 3 ] && ! check_vpn; do
            reconnect_vpn
            RETRIES=$((RETRIES + 1))
            [ $RETRIES -lt 3 ] && sleep $RETRY_INTERVAL
        done
    fi
    sleep $CHECK_INTERVAL
done
