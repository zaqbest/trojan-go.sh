#!/usr/bin/env bash
set -euo pipefail

DEFAULT_PORT=54389
DEFAULT_PASSWORD="Ijk2e20p7gEVTjXS"
DEFAULT_SNI="bing.com"

PORT="${PORT:-$DEFAULT_PORT}"
PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
SNI="${SNI:-$DEFAULT_SNI}"

BASE_DIR="/opt/trojan-go"
INSTALL_DIR="${BASE_DIR}"
CONFIG_DIR="${BASE_DIR}"
CERT_DIR="${BASE_DIR}/certs"
LOG_DIR="${BASE_DIR}/logs"
SERVICE_FILE="/etc/systemd/system/trojan-go.service"

log()  { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERR ]\033[0m $*" >&2; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "请使用 root 运行：sudo bash install.sh"
    exit 1
  fi
}

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      err "不支持的架构: $arch"
      exit 1
      ;;
  esac
}

install_deps() {
  if command -v apt >/dev/null 2>&1; then
    apt update
    apt install -y curl tar ca-certificates unzip openssl
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl tar ca-certificates unzip openssl
  elif command -v yum >/dev/null 2>&1; then
    yum install -y curl tar ca-certificates unzip openssl
  else
    warn "未识别包管理器，请手动安装：curl tar ca-certificates unzip openssl"
  fi
}

download_trojan_go() {
  local arch="$1"
  local tmp_dir latest_tag pkg url

  tmp_dir="$(mktemp -d)"

  log "获取 Trojan-Go 最新版本..."
  latest_tag="$(curl -fsSL https://api.github.com/repos/p4gefau1t/trojan-go/releases/latest | grep -oE '"tag_name":\s*"[^"]+"' | head -n1 | cut -d'"' -f4)"
  if [[ -z "$latest_tag" ]]; then
    err "无法获取 Trojan-Go 最新版本号"
    rm -rf "$tmp_dir"
    exit 1
  fi

  pkg="trojan-go-linux-${arch}.zip"
  url="https://github.com/p4gefau1t/trojan-go/releases/download/${latest_tag}/${pkg}"

  log "下载: ${url}"
  if ! curl -fL "$url" -o "${tmp_dir}/${pkg}"; then
    err "下载失败: ${url}"
    rm -rf "$tmp_dir"
    exit 1
  fi

  mkdir -p "$INSTALL_DIR"
  unzip -o "${tmp_dir}/${pkg}" -d "$INSTALL_DIR" >/dev/null

  if [[ ! -f "${INSTALL_DIR}/trojan-go" ]]; then
    err "解压后未找到 trojan-go 二进制文件"
    rm -rf "$tmp_dir"
    exit 1
  fi
  chmod +x "${INSTALL_DIR}/trojan-go"

  rm -rf "$tmp_dir"
}

create_dirs() {
  mkdir -p "$CONFIG_DIR" "$CERT_DIR" "$LOG_DIR"
}

generate_self_signed_cert() {
  local cert_file="${CERT_DIR}/server.crt"
  local key_file="${CERT_DIR}/server.key"

  if [[ -f "$cert_file" && -f "$key_file" ]]; then
    log "证书已存在，跳过生成: $cert_file"
    return
  fi

  log "生成自签证书: CN/SNI=${SNI}"
  if ! openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$cert_file" \
        -days 3650 \
        -subj "/CN=${SNI}" \
        -addext "subjectAltName=DNS:${SNI}" >/dev/null 2>&1; then
    warn "openssl 不支持 -addext，退回到不带 SAN 的模式"
    if ! openssl req -x509 -nodes -newkey rsa:2048 \
          -keyout "$key_file" \
          -out "$cert_file" \
          -days 3650 \
          -subj "/CN=${SNI}" >/dev/null 2>&1; then
      err "生成自签证书失败"
      exit 1
    fi
  fi

  chmod 600 "$key_file"
  chmod 644 "$cert_file"
}

write_config() {
  local cert_file="${CERT_DIR}/server.crt"
  local key_file="${CERT_DIR}/server.key"

  cat > "${CONFIG_DIR}/config.json" <<EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": ${PORT},
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": [
    "${PASSWORD}"
  ],
  "ssl": {
    "cert": "${cert_file}",
    "key": "${key_file}",
    "sni": "${SNI}",
    "fallback_port": 80
  },
  "websocket": {
    "enabled": false
  },
  "mux": {
    "enabled": true
  },
  "log_level": 1
}
EOF

  chmod 640 "${CONFIG_DIR}/config.json"
}

write_service() {
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Trojan-Go Service
After=network.target nss-lookup.target

[Service]
Type=simple
ExecStart="${INSTALL_DIR}/trojan-go" -config "${CONFIG_DIR}/config.json"
Restart=on-failure
RestartSec=3
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable trojan-go
  systemctl restart trojan-go
}

get_public_ip() {
  local ip
  ip="$(curl -fsSL -4 --max-time 5 https://api.ipify.org 2>/dev/null \
        || curl -fsSL -4 --max-time 5 https://ifconfig.me 2>/dev/null \
        || curl -fsSL -4 --max-time 5 https://ipinfo.io/ip 2>/dev/null)"
  [[ -z "$ip" ]] && ip="<your-server-ip>"
  echo "$ip"
}

# 基于 IP 后 2 段生成 Surge 节点名前缀
node_prefix() {
  local ip="$1"
  local last2
  last2="$(echo "${ip}" | awk -F. '{print $3"-"$4}' 2>/dev/null || true)"
  if [[ -z "${last2}" || "${last2}" = "-" ]]; then
    echo "trojan"
  else
    echo "tj-${last2}"
  fi
}

show_result() {
  local public_ip prefix trojan_url
  public_ip="$(get_public_ip)"
  prefix="$(node_prefix "${public_ip}")"
  trojan_url="trojan://${PASSWORD}@${public_ip}:${PORT}?security=tls&sni=${SNI}&alpn=h2%2Chttp%2F1.1&allowInsecure=1#${prefix}"

  log "安装完成"
  echo
  echo -e "\033[1;32m============================================================\033[0m"
  echo -e "\033[1;32m     Trojan-Go 安装成功！\033[0m"
  echo -e "\033[1;32m============================================================\033[0m"
  echo -e " \033[1;34m服务器地址\033[0m : ${public_ip}"
  echo -e " \033[1;34m端口\033[0m       : ${PORT}"
  echo -e " \033[1;34m密码\033[0m       : ${PASSWORD}"
  echo -e " \033[1;34mSNI\033[0m        : ${SNI}"
  echo -e " \033[1;34m证书类型\033[0m   : 自签 (客户端必须开 skip-cert-verify)"
  echo -e " \033[1;34m配置文件\033[0m   : ${CONFIG_DIR}/config.json"
  echo -e " \033[1;34m证书文件\033[0m   : ${CERT_DIR}/server.crt"
  echo -e "\033[1;32m------------------------------------------------------------\033[0m"
  echo -e "\033[1;33m# Surge / Stash / Loon [Proxy] 直接复制:\033[0m"
  echo "${prefix} = trojan, ${public_ip}, ${PORT}, password=${PASSWORD}, sni=${SNI}, skip-cert-verify=true, udp-relay=true"
  echo
  echo -e "\033[1;33m# 通用 URL:\033[0m"
  echo "${trojan_url}"
  echo -e "\033[1;32m------------------------------------------------------------\033[0m"
  echo -e " 服务管理:"
  echo -e "   状态 : \033[1;33msystemctl status trojan-go --no-pager\033[0m"
  echo -e "   重启 : \033[1;33msystemctl restart trojan-go\033[0m"
  echo -e "   日志 : \033[1;33mjournalctl -u trojan-go -f\033[0m"
  echo -e "\033[1;32m============================================================\033[0m"
  echo

  # 同时写入客户端信息文件
  cat > "${BASE_DIR}/client_info.txt" <<CIEOF
  Trojan-Go server info (client reference)
Server IP : ${public_ip}
Port      : ${PORT}
Password  : ${PASSWORD}
SNI       : ${SNI}
Cert type : self-signed (client MUST enable skip-cert-verify / allow_insecure)

# Surge / Stash / Loon [Proxy] 直接复制:
${prefix} = trojan, ${public_ip}, ${PORT}, password=${PASSWORD}, sni=${SNI}, skip-cert-verify=true, udp-relay=true

# 通用 URL:
${trojan_url}
CIEOF
  chmod 600 "${BASE_DIR}/client_info.txt"
}

main() {
  require_root
  install_deps
  local arch
  arch="$(detect_arch)"
  download_trojan_go "$arch"
  create_dirs
  generate_self_signed_cert
  write_config
  write_service
  show_result
}

main "$@"