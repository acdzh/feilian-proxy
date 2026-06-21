# 代理服务方案（已验证）

## 方案概述

在 Android 手机上运行 gost（HTTP 代理），监听 8888 端口，对外提供 HTTP/HTTPS 代理服务。流量通过 VPN 路由表自动走 tun0 出去。

```
开发机 --[HTTP Proxy]--> 手机 wlan0:8888 --[gost]--> tun0(VPN) ---> 内网资源
```

## 已验证结论

| 项目 | 结论 |
|------|------|
| root 流量是否走 VPN | ✅ 是，ip rule 包含 UID 0-99999 走 tun0 表 |
| gost 能否正常代理 | ✅ HTTP + HTTPS CONNECT 均可 |
| 外部设备能否连接 | ✅ Mac 通过 10.0.0.142:8888 访问内网成功 |
| DNS 解析 | ⚠️ 必须显式指定 VPN DNS (10.8.8.18)，否则内网域名无法解析 |

## 代理工具

- **gost v3.2.6**
- 静态链接 arm64 ELF，7.4MB，无依赖
- 下载地址: `https://github.com/go-gost/gost/releases/download/v3.2.6/gost_3.2.6_linux_arm64.tar.gz`
- 部署路径: `/data/local/tmp/gost`（最终应放到 Magisk 模块目录）

## 配置文件

路径: `/data/local/tmp/gost.yaml`

```yaml
services:
- name: proxy
  addr: :8888
  handler:
    type: http
  listener:
    type: tcp
  resolver: vpn-dns

resolvers:
- name: vpn-dns
  nameservers:
  - addr: 10.8.8.18:53
```

**关键点**: `resolver` 必须指向 VPN DNS，否则 gost 无法解析内网域名（如 `code.byted.org`）。

## 启动命令

### 在设备上执行（需 root shell）

```bash
# 前台启动（调试用）
/data/local/tmp/gost -C /data/local/tmp/gost.yaml

# 后台启动
nohup /data/local/tmp/gost -C /data/local/tmp/gost.yaml > /data/local/tmp/gost.log 2>&1 &
```

### 通过 adb 执行

```bash
# 启动
adb shell "su -c 'nohup /data/local/tmp/gost -C /data/local/tmp/gost.yaml > /data/local/tmp/gost.log 2>&1 &'"

# 停止
adb shell "su -c 'pkill gost'"

# 查看日志
adb shell "su -c 'tail -20 /data/local/tmp/gost.log'"

# 检查是否在运行
adb shell "su -c 'pidof gost && echo RUNNING || echo STOPPED'"
```

## 客户端使用

在开发机上配置 HTTP 代理:

```bash
# 临时使用
export http_proxy=http://10.0.0.142:8888
export https_proxy=http://10.0.0.142:8888

# curl 测试
curl -x http://10.0.0.142:8888 https://code.byted.org

# 或在系统网络设置中配置代理:
#   服务器: 10.0.0.142
#   端口: 8888
```

## 验证命令

```bash
# 从电脑验证代理可用（应返回 200 或 302）
curl -x http://10.0.0.142:8888 -s -o /dev/null -w "%{http_code}" https://code.byted.org

# 从手机本地验证
adb shell "su -c 'curl -x http://127.0.0.1:8888 -s -o /dev/null -w \"%{http_code}\" https://code.byted.org'"
```

## 路由原理

Android VPN 的路由策略（已验证）:

```
# ip rule (关键规则)
13000: from all fwmark 0x0/0x20000 iif lo uidrange 0-99999 lookup tun0

# tun0 路由表内容
0.0.0.0/1 dev tun0
128.0.0.0/1 dev tun0
10.8.8.18 dev tun0
10.254.224.0/19 dev tun0
30.100.0.0/14 dev tun0
```

含义: 所有本地进程（UID 0-99999，包含 root），只要 fwmark 没有设置 0x20000 位，出站流量都走 tun0 路由表。因此 gost 的出站连接自动通过 VPN 隧道。

## 注意事项

1. **DNS 是关键** — 不配置 resolver 时 gost 无法解析内网域名，会返回 503
2. **VPN 必须先连接** — gost 依赖 tun0 路由，VPN 断开时代理不可用
3. **端口无防火墙** — Android 默认不阻止入站连接，无需额外 iptables 规则
4. **gost 以 root 运行** — 确保走 VPN 路由规则
