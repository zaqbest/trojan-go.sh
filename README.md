# Trojan-Go 一键安装脚本

一键在 Linux 服务器上部署 [Trojan-Go](https://github.com/p4gefau1t/trojan-go) 服务端，自动完成依赖安装、二进制下载、自签证书生成、配置文件写入、systemd 服务注册与启动。

所有文件（程序、配置、证书、日志）统一放在 `/opt/trojan-go` 目录下，便于管理。

---

## ✨ 特性

- 🚀 一键部署，全流程自动化
- 📦 自动从 GitHub Releases 拉取最新版本
- 🏗️ 支持 `x86_64 (amd64)` 与 `aarch64 (arm64)` 架构
- 🔐 自动生成 10 年有效期的自签 TLS 证书
- 🛠️ 集成 systemd，开机自启 + 崩溃重启
- 🎨 支持环境变量自定义端口、密码、SNI
- 📂 单目录部署（`/opt/trojan-go`），方便备份与卸载

---

## 📋 系统要求

- **操作系统**：基于 systemd 的 Linux 发行版
  - Debian / Ubuntu（apt）
  - CentOS / RHEL / Rocky / AlmaLinux（yum / dnf）
  - Fedora（dnf）
- **架构**：`x86_64` 或 `aarch64`
- **权限**：root（或 sudo）

---

## 🚀 快速开始

### 使用默认参数安装

```bash
sudo bash install.sh
```

### 自定义参数安装

通过环境变量覆盖默认值：

```bash
sudo PORT=443 \
     PASSWORD="your_strong_password" \
     SNI="your.domain.com" \
     bash install.sh
```

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `PORT` | `54389` | Trojan-Go 监听端口 |
| `PASSWORD` | `Ijk2e20p7gEVTjXS` | 连接密码 |
| `SNI` | `trojan-go.zaqbest.com` | TLS SNI（证书 CN） |

---

## 📁 目录结构

安装完成后，所有文件集中在 `/opt/trojan-go`：

```
/opt/trojan-go/
├── trojan-go              # 主程序二进制
├── config.json            # 主配置文件
├── certs/
│   ├── server.crt         # 自签证书
│   └── server.key         # 证书私钥
└── logs/                  # 日志目录
```

其他系统级文件：

| 路径 | 说明 |
|------|------|
| `/etc/systemd/system/trojan-go.service` | systemd 服务文件 |

---

## 🛠️ 服务管理

```bash
# 查看状态
systemctl status trojan-go

# 启动 / 停止 / 重启
systemctl start   trojan-go
systemctl stop    trojan-go
systemctl restart trojan-go

# 开机自启 / 禁用
systemctl enable  trojan-go
systemctl disable trojan-go

# 实时日志
journalctl -u trojan-go -f
```

---

## 📲 客户端配置示例

```json
{
  "run_type": "client",
  "local_addr": "127.0.0.1",
  "local_port": 1080,
  "remote_addr": "你的服务器IP",
  "remote_port": 54389,
  "password": ["Ijk2e20p7gEVTjXS"],
  "ssl": {
    "sni": "trojan-go.zaqbest.com",
    "verify": false
  }
}
```

> ⚠️ 由于使用的是**自签证书**，客户端需设置 `"verify": false`，或将服务端证书（`/opt/trojan-go/certs/server.crt`）加入客户端信任链。

---

## 🔧 常用配置调整

编辑配置文件后重启服务生效：

```bash
sudo vim /opt/trojan-go/config.json
sudo systemctl restart trojan-go
```

### 使用正式证书（推荐）

将 Let's Encrypt / Cloudflare / 商业证书替换到：
- `/opt/trojan-go/certs/server.crt`
- `/opt/trojan-go/certs/server.key`

注意权限：
```bash
sudo chmod 644 /opt/trojan-go/certs/server.crt
sudo chmod 600 /opt/trojan-go/certs/server.key
sudo systemctl restart trojan-go
```

---

## 🗑️ 卸载

```bash
sudo systemctl stop trojan-go
sudo systemctl disable trojan-go
sudo rm -f /etc/systemd/system/trojan-go.service
sudo systemctl daemon-reload

sudo rm -rf /opt/trojan-go
```

---

## ❓ 常见问题

### 1. 端口被占用 / 无法启动？
```bash
sudo ss -tlnp | grep :54389
sudo journalctl -u trojan-go -n 100 --no-pager
```

### 2. 客户端连接失败？
- 确认服务器防火墙 / 云安全组已放行对应端口（TCP）
- 客户端 `sni` 必须与服务端一致
- 使用自签证书时客户端需关闭证书校验

### 3. 想升级到最新版本？
```bash
sudo bash install.sh
```
重新运行脚本即可，会覆盖二进制并重启服务（已有证书会保留，配置会被重写）。

---

## 📄 License

MIT

---

## 🔗 相关链接

- Trojan-Go 项目：<https://github.com/p4gefau1t/trojan-go>
- Trojan-Go 配置文档：<https://p4gefau1t.github.io/trojan-go/>