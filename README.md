# Feilian VPN Proxy

飞连 VPN 保活 + gost HTTP 代理的 Magisk 模块。

在 Android 手机上运行飞连 VPN 并通过 gost 对外提供 HTTP 代理，使开发机通过手机代理访问内网资源。

## 功能

- **gost HTTP 代理**：开机自动启动，监听 `:8888`，流量通过飞连 VPN 隧道转发
- **gost 守护**：gost 异常退出后自动重启
- **VPN 守护进程**：每 2 分钟检测飞连 VPN 连接状态，断开时通过 Quick Settings Tile 自动重连（最多重试 3 次）
- **gost 管理 API**：`:18080` 端口提供 REST API，可动态增删代理/转发规则

## 安装

### 方式 1：Magisk 模块（推荐）

1. 从 [Releases](../../releases) 下载 `feilian-proxy-vX.X.X.zip`
2. 打开 Magisk Manager → 模块 → 从本地安装 → 选择 zip
3. 重启手机
4. gost 代理和 VPN 守护将自动启动

### 方式 2：手动部署

```bash
# 推送文件
adb push module/bin/gost /data/local/tmp/feilian-server/gost
adb push module/scripts/* /data/local/tmp/feilian-server/
adb shell "chmod +x /data/local/tmp/feilian-server/*"

# 创建配置
adb shell "mkdir -p /data/adb/feilian-proxy"
adb push module/config/gost.yaml /data/adb/feilian-proxy/gost.yml

# 启动 gost
adb shell "su -c '/data/local/tmp/feilian-server/gost-ctl.sh &'"

# 启动 VPN 守护
adb shell "su -c '/data/local/tmp/feilian-server/vpn-monitor.sh &'"
```

## 使用

### 代理配置

在开发机上设置 HTTP 代理：

```bash
export http_proxy=http://<手机IP>:8888
export https_proxy=http://<手机IP>:8888

# 测试
curl -x http://<手机IP>:8888 https://code.byted.org
```

### gost 配置

配置文件位于 `/data/adb/feilian-proxy/gost.yml`（首次启动时从模块内置配置复制）。

默认提供 HTTP 代理（:8888）+ 管理 API（:18080），DNS 解析通过 VPN 隧道内的 DNS 服务器。

可自行编辑添加端口转发等规则，修改后重启 gost 生效：

```yaml
services:
- name: http-proxy
  addr: :8888
  handler:
    type: http
  listener:
    type: tcp
  resolver: vpn-dns
# 添加端口转发示例
- name: forward-example
  addr: :2345
  handler:
    type: tcp
  listener:
    type: tcp
  forwarder:
    nodes:
    - name: target
      addr: remote-host:2345

resolvers:
- name: vpn-dns
  nameservers:
  - addr: 10.8.8.18:53
  - addr: 10.0.0.1:53

api:
  addr: :18080
```

### gost 动态 API

gost 管理 API（:18080）可动态增删服务，无需重启：

```bash
# 查看所有服务
curl http://<手机IP>:18080/api/services

# 添加端口转发
curl -X POST http://<手机IP>:18080/api/services -d '{
  "name": "fwd-2345",
  "addr": ":2345",
  "handler": {"type": "tcp"},
  "listener": {"type": "tcp"},
  "forwarder": {"nodes": [{"name": "t", "addr": "target:2345"}]}
}'

# 删除服务
curl -X DELETE http://<手机IP>:18080/api/services/fwd-2345
```

## 文件说明

| 路径 | 说明 |
|------|------|
| `/data/adb/modules/feilian-proxy/bin/gost` | gost 二进制 |
| `/data/adb/modules/feilian-proxy/scripts/gost-ctl.sh` | gost 守护脚本 |
| `/data/adb/modules/feilian-proxy/scripts/vpn-monitor.sh` | VPN 守护脚本 |
| `/data/adb/feilian-proxy/gost.yml` | gost 配置文件（用户可编辑）|
| `/data/local/tmp/feilian-proxy.log` | 服务日志 |
| `/data/local/tmp/gost.log` | gost 日志 |

## 要求

- Magisk v20+
- 需要 root 权限
- 飞连 app 已登录且 Quick Settings Tile 已添加到下拉面板
