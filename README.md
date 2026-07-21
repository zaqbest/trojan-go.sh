# Trojan-Go 一键安装脚本

一个用于快速部署 [Trojan-Go](https://github.com/p4gefau1t/trojan-go) 服务端的自动化脚本。

所有文件（程序、配置、证书、日志）统一放在 `/opt/trojan-go` 目录下，便于管理。

## ✨ 功能特性

- ✅ **多系统兼容**：Debian / Ubuntu / CentOS / RHEL / Rocky / AlmaLinux / Fedora
- ✅ **多架构支持**：amd64 / arm64
- ✅ **开机自启**：自动配置 systemd
- ✅ **自动生成自签证书**：10 年有效期，支持 SAN
- ✅ **参数可配置**：端口、密码、SNI 均可通过环境变量自定义
- ✅ **一键安装**：支持 `bash -c "$(curl ...)"` 远程执行
- ✅ **单目录部署**：所有文件集中在 `/opt/trojan-go`，方便备份 / 卸载

## 📦 默认配置

| 项目 | 值 |
|------|-----|
| 默认端口 | `54389` |
| 默认密码 | `Ijk2e20p7gEVTjXS` |
| 默认 SNI | `trojan-go.zaqbest.com` |
| 安装目录 | `/opt/trojan-go/` |
| 可执行文件 | `/opt/trojan-go/trojan-go` |
| 配置文件 | `/opt/trojan-go/config.json` |
| 证书目录 | `/opt/trojan-go/certs/` |
| 日志目录 | `/opt/trojan-go/logs/` |

## 🚀 快速开始

### 方式一：一键远程安装（推荐）

```bash
# 使用默认端口、密码、SNI
bash -c "$(curl -fsSL https://install-trojan-go.zaqbest.com)"

# 自定义端口、密码、SNI（通过环境变量，写在 bash 前面）
PORT=443 PASSWORD="mypassword" SNI="your.domain.com" \
  bash -c "$(curl -fsSL https://install-trojan-go.zaqbest.com)"
```

> 💡 通过 `curl | bash` 远程执行时，环境变量要写在 `bash` 前面（作为 `bash` 进程的环境变量），不要写在 `curl` 前面。

### 方式二：本地下载执行

```bash
# 下载脚本
curl -fsSL -o install.sh https://install-trojan-go.zaqbest.com
chmod +x install.sh

# 默认安装
sudo bash install.sh

# 自定义参数
sudo PORT=443 PASSWORD="mypassword" SNI="your.domain.com" bash install.sh
```

### 可用环境变量

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `PORT` | `54389` | Trojan-Go 监听端口 |
| `PASSWORD` | `Ijk2e20p7gEVTjXS` | 连接密码 |
| `SNI` | `trojan-go.zaqbest.com` | TLS SNI（证书 CN） |

## 📁 目录结构

安装完成后：

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

## 🔧 服务管理

```bash
systemctl start   trojan-go     # 启动
systemctl stop    trojan-go     # 停止
systemctl restart trojan-go     # 重启
systemctl status  trojan-go     # 查看状态
systemctl enable  trojan-go     # 开机自启
systemctl disable trojan-go     # 禁用自启
journalctl -u trojan-go -f      # 实时日志
```

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

## 🔧 使用正式证书（推荐）

将 Let's Encrypt / Cloudflare / 商业证书替换到：

```bash
sudo cp your_cert.crt /opt/trojan-go/certs/server.crt
sudo cp your_key.key  /opt/trojan-go/certs/server.key
sudo chmod 644 /opt/trojan-go/certs/server.crt
sudo chmod 600 /opt/trojan-go/certs/server.key
sudo systemctl restart trojan-go
```

## 🗑️ 卸载

```bash
sudo systemctl stop trojan-go
sudo systemctl disable trojan-go
sudo rm -f /etc/systemd/system/trojan-go.service
sudo systemctl daemon-reload
sudo rm -rf /opt/trojan-go
```

## ❓ 常见问题

### 1. 一键安装如何传参？

远程一键安装时，环境变量要写在 `bash` 前面：

```bash
PORT=443 PASSWORD="pass" SNI="your.domain.com" \
  bash -c "$(curl -fsSL https://install-trojan-go.zaqbest.com)"
```

**错误写法**（`curl` 不识别这些变量）：
```bash
# ❌ 不要这样写
curl -fsSL https://xxx/install.sh | PORT=443 bash
```

### 2. GitHub API 限流怎么办？

脚本通过 GitHub API 获取最新 Release 版本，未登录用户每小时 60 次。如遇限流：
- 稍后重试
- 或修改脚本中 `download_trojan_go` 手动指定 `latest_tag` 版本号

### 3. 客户端连接失败？

- 确认服务器防火墙 / 云安全组已放行对应端口（TCP）
- 客户端 `sni` 必须与服务端一致
- 使用自签证书时客户端需关闭证书校验（`"verify": false`）

### 4. 如何查看运行日志？

```bash
# systemd 日志（推荐）
journalctl -u trojan-go -f

# 查看最近 100 行
journalctl -u trojan-go -n 100 --no-pager
```

### 5. 端口被占用 / 无法启动？

```bash
sudo ss -tlnp | grep :54389
sudo journalctl -u trojan-go -n 100 --no-pager
```

### 6. 想升级到最新版本？

```bash
sudo bash install.sh
```

重新运行脚本即可，会覆盖二进制并重启服务（已有证书会保留，配置会被重写）。

## 📄 License

MIT

## 🔗 相关链接

- Trojan-Go 项目：<https://github.com/p4gefau1t/trojan-go>
- Trojan-Go 配置文档：<https://p4gefau1t.github.io/trojan-go/>