#!/system/bin/sh
MODDIR=${0%/*}
LOG=/data/local/tmp/feilian-proxy.log

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

# 等待设备启动完成
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

log "设备启动完成，启动 gost 代理"

# 确保配置目录和文件存在
if [ ! -f /data/adb/feilian-proxy/gost.yml ]; then
    mkdir -p /data/adb/feilian-proxy
    cp $MODDIR/config/gost.yaml /data/adb/feilian-proxy/gost.yml
fi
chmod 0666 /data/adb/feilian-proxy/gost.yml
chcon u:object_r:adb_data_file:s0 /data/adb/feilian-proxy/gost.yml

# 启动 gost 代理（守护进程，后台运行）
$MODDIR/scripts/gost-ctl.sh &

# 启动 VPN 守护进程
$MODDIR/scripts/vpn-monitor.sh &
