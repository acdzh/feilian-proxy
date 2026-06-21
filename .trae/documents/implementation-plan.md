# 飞连代理 Magisk 模块实现方案

## Context

将之前验证通过的 VPN 保活 + gost 代理方案封装为一个 Magisk 模块，通过 Magisk Manager 内置 WebUI 提供本地控制界面。

## 项目结构

```
feilian-android-server/
├── module/                         # Magisk 模块（打包为 zip）
│   ├── module.prop                 # 模块元数据
│   ├── customize.sh                # 安装时执行
│   ├── service.sh                  # 开机启动入口
│   ├── webroot/                    # Magisk WebUI
│   │   └── index.html              # 控制面板（单文件）
│   ├── bin/
│   │   └── gost                    # gost arm64 静态二进制
│   └── scripts/
│       ├── vpn-monitor.sh          # VPN 守护进程
│       └── gost-ctl.sh             # gost 启动/停止/状态
├── .github/
│   └── workflows/
│       └── release.yml             # CI: 打包模块 zip
└── README.md                       # 部署说明
```

## 开机行为

`service.sh` 开机后：
1. 启动 gost 代理（默认启用）
2. VPN 守护进程**默认关闭**，需通过 WebUI 手动开启

## 核心脚本

### scripts/vpn-monitor.sh

```
参数: start | stop | status
start: 后台启动守护循环，写 PID 文件
stop: 杀守护进程
status: 输出 enabled/disabled + VPN 连接状态

守护循环:
while true:
    if tun0 不存在:
        确保飞连进程存活 → click-tile → sleep 5 验证
    sleep 60
```

### scripts/gost-ctl.sh

```
参数: start | stop | status
start: 读取 /sdcard/gost.yaml，后台启动 gost，写 PID 文件
stop: 杀 gost 进程
status: 进程是否存活
```

## WebUI 功能

单文件 `index.html`，4 个按钮 + 日志查看：

1. **启动/停止 VPN 守护** — 调用 `vpn-monitor.sh start/stop`
2. **启动/停止 gost** — 调用 `gost-ctl.sh start/stop`
3. **查看日志** — 读取日志文件最后 N 行

页面顶部显示当前状态（VPN 是否连接、守护是否开启、gost 是否在跑）。

## gost 配置

安装时复制默认配置到 `/sdcard/gost.yaml`（如果不存在）：

```yaml
services:
- name: http-proxy
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

api:
  addr: :18080
```

用户可编辑 `/sdcard/gost.yaml` 自行添加端口转发等规则，重启 gost 生效。

## GitHub CI

`release.yml`:
1. 将 `module/` 打包为 `feilian-proxy-vX.X.X.zip`
2. Release 产物：模块 zip

gost 二进制直接放在仓库 `module/bin/gost` 中。

## 部署方式

### Magisk 模块安装（推荐）
1. 下载 zip → Magisk Manager 安装 → 重启
2. WebUI 控制启停

### 手动部署
1. adb push 二进制和脚本到手机
2. 手动创建 `/sdcard/gost.yaml`
3. 手动执行 `service.sh` 或各脚本

## 实现步骤

1. 创建项目结构（module.prop, customize.sh）
2. 实现 scripts/vpn-monitor.sh
3. 实现 scripts/gost-ctl.sh
4. 实现 service.sh（开机启动两个服务）
5. 放入 gost arm64 二进制
6. 实现 webroot/index.html
7. 编写 .github/workflows/release.yml
8. 编写 README.md

## 验证

1. push 到手机手动跑脚本验证
2. 打包安装到 Magisk，重启验证自动启动
3. WebUI 点击启停验证
4. `curl -x http://手机IP:8888 https://code.byted.org` 验证代理
