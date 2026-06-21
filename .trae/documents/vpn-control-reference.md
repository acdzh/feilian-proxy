# 飞连 VPN 控制与状态检测

## 设备信息

- 包名: `com.volcengine.corplink`
- QS Tile: `com.volcengine.corplink/com.bytedance.topgo.widget.QSTileService`
- Main Activity: `com.volcengine.corplink/com.bytedance.topgo.activity.SplashActivity`
- VPN 接口: `tun0`
- VPN DNS: `10.8.8.18`

---

## 一、VPN 状态检测

### 在设备上执行（需 root shell）

```bash
# 方法 1: 接口是否存在（最快，< 1ms）
ls /sys/class/net/tun0 >/dev/null 2>&1 && echo "CONNECTED" || echo "DISCONNECTED"

# 方法 2: carrier 状态
cat /sys/class/net/tun0/carrier 2>/dev/null
# 输出 1 = 连接正常，文件不存在或输出 0 = 未连接

# 方法 3: ifconfig 状态
ifconfig tun0 2>/dev/null | grep -q "UP POINTOPOINT RUNNING" && echo "UP" || echo "DOWN"

# 方法 4: ping 连通性（最可靠，约 20-40ms）
ping -c 1 -W 3 -I tun0 10.8.8.18 >/dev/null 2>&1 && echo "REACHABLE" || echo "UNREACHABLE"

# 方法 5: 系统 connectivity 状态
dumpsys connectivity | grep -c "VPN CONNECTED"
# 输出 1 = VPN 连接中，0 = 未连接
```

### 通过 adb 执行

```bash
# 方法 1
adb shell "su -c 'ls /sys/class/net/tun0 >/dev/null 2>&1 && echo CONNECTED || echo DISCONNECTED'"

# 方法 2
adb shell "su -c 'cat /sys/class/net/tun0/carrier 2>/dev/null || echo 0'"

# 方法 3
adb shell "ifconfig tun0 2>/dev/null | grep -q 'UP POINTOPOINT RUNNING' && echo UP || echo DOWN"

# 方法 4
adb shell "su -c 'ping -c 1 -W 3 -I tun0 10.8.8.18 >/dev/null 2>&1 && echo REACHABLE || echo UNREACHABLE'"

# 方法 5
adb shell "su -c 'dumpsys connectivity | grep -c \"VPN CONNECTED\"'"
```

---

## 二、VPN 连接控制

### 连接 VPN

#### 在设备上执行（需 root shell）

```bash
# 前提：飞连 app 进程必须存活
# 检查进程是否存在，不存在则先启动 app
pidof com.volcengine.corplink >/dev/null 2>&1 || \
    am start -n com.volcengine.corplink/com.bytedance.topgo.activity.SplashActivity

# 等待 app 初始化
sleep 2

# 通过 QS Tile 连接（toggle，当前必须处于断开状态）
cmd statusbar click-tile com.volcengine.corplink/com.bytedance.topgo.widget.QSTileService

# 等待连接建立（通常 3-5 秒）
sleep 5

# 验证
ls /sys/class/net/tun0 >/dev/null 2>&1 && echo "OK" || echo "FAILED"
```

#### 通过 adb 执行

```bash
# 确保 app 存活
adb shell "pidof com.volcengine.corplink >/dev/null 2>&1 || am start -n com.volcengine.corplink/com.bytedance.topgo.activity.SplashActivity"

# 等待
sleep 2

# 触发连接
adb shell "su -c 'cmd statusbar click-tile com.volcengine.corplink/com.bytedance.topgo.widget.QSTileService'"

# 等待并验证
sleep 5
adb shell "su -c 'ls /sys/class/net/tun0 >/dev/null 2>&1 && echo CONNECTED || echo FAILED'"
```

### 断开 VPN

#### 在设备上执行（需 root shell）

```bash
# 通过 QS Tile 断开（toggle，当前必须处于连接状态）
cmd statusbar click-tile com.volcengine.corplink/com.bytedance.topgo.widget.QSTileService

# 等待断开（通常 1-3 秒）
sleep 3

# 验证
ls /sys/class/net/tun0 >/dev/null 2>&1 && echo "STILL CONNECTED" || echo "DISCONNECTED"
```

#### 通过 adb 执行

```bash
# 触发断开
adb shell "su -c 'cmd statusbar click-tile com.volcengine.corplink/com.bytedance.topgo.widget.QSTileService'"

# 等待并验证
sleep 3
adb shell "su -c 'ls /sys/class/net/tun0 >/dev/null 2>&1 && echo STILL_CONNECTED || echo DISCONNECTED'"
```

---

## 三、安全封装（避免 toggle 反向操作）

QS Tile 是 toggle 行为，直接调用可能反向操作。以下是带状态检查的安全版本。

### 在设备上执行（需 root shell）

```bash
# 安全连接（仅在断开时触发）
vpn_ensure_connected() {
    if ls /sys/class/net/tun0 >/dev/null 2>&1; then
        echo "already connected"
        return 0
    fi
    # 确保 app 进程存活
    pidof com.volcengine.corplink >/dev/null 2>&1 || {
        am start -n com.volcengine.corplink/com.bytedance.topgo.activity.SplashActivity
        sleep 3
    }
    cmd statusbar click-tile com.volcengine.corplink/com.bytedance.topgo.widget.QSTileService
    sleep 5
    ls /sys/class/net/tun0 >/dev/null 2>&1 && echo "connected" || echo "failed"
}

# 安全断开（仅在连接时触发）
vpn_ensure_disconnected() {
    if ! ls /sys/class/net/tun0 >/dev/null 2>&1; then
        echo "already disconnected"
        return 0
    fi
    cmd statusbar click-tile com.volcengine.corplink/com.bytedance.topgo.widget.QSTileService
    sleep 3
    ls /sys/class/net/tun0 >/dev/null 2>&1 && echo "failed" || echo "disconnected"
}
```

### 通过 adb 执行

```bash
# 安全连接
adb shell "su -c '
if ls /sys/class/net/tun0 >/dev/null 2>&1; then
    echo already_connected
else
    pidof com.volcengine.corplink >/dev/null 2>&1 || am start -n com.volcengine.corplink/com.bytedance.topgo.activity.SplashActivity
    sleep 3
    cmd statusbar click-tile com.volcengine.corplink/com.bytedance.topgo.widget.QSTileService
    sleep 5
    ls /sys/class/net/tun0 >/dev/null 2>&1 && echo connected || echo failed
fi'"

# 安全断开
adb shell "su -c '
if ls /sys/class/net/tun0 >/dev/null 2>&1; then
    cmd statusbar click-tile com.volcengine.corplink/com.bytedance.topgo.widget.QSTileService
    sleep 3
    ls /sys/class/net/tun0 >/dev/null 2>&1 && echo failed || echo disconnected
else
    echo already_disconnected
fi'"
```

---

## 四、防后台杀死（执行一次即可）

### 在设备上执行（需 root shell）

```bash
# 加入电池优化白名单（Doze 模式不影响）
dumpsys deviceidle whitelist +com.volcengine.corplink

# 允许后台运行
cmd appops set com.volcengine.corplink RUN_IN_BACKGROUND allow

# 验证
dumpsys deviceidle whitelist | grep corplink
```

### 通过 adb 执行

```bash
adb shell "su -c 'dumpsys deviceidle whitelist +com.volcengine.corplink'"
adb shell "su -c 'cmd appops set com.volcengine.corplink RUN_IN_BACKGROUND allow'"
adb shell "su -c 'dumpsys deviceidle whitelist | grep corplink'"
```

---

## 五、注意事项

1. **QS Tile 是 toggle** — 必须先检测当前状态再决定是否点击，否则可能断开正在运行的 VPN
2. **飞连进程必须存活** — 如果 app 被杀（如 `am force-stop`），click-tile 无效，需先 `am start` 拉起 app
3. **连接耗时** — 从 click-tile 到 tun0 出现通常需要 3-5 秒
4. **root 权限** — `cmd statusbar click-tile` 和 `ping -I tun0` 都需要 root
5. **VPN 模式** — 当前配置为 Full 模式（全局路由），所有流量走 VPN
