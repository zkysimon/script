#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
XRAY_INSTALL_URL="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"
CONFIG_FILE="/usr/local/etc/xray/config.json"
RESULT_FILE="/root/xray-xhttp-reality.txt"
CLIENT_FILE="/root/xray-xhttp-reality-client.json"

PORT=""
SERVER_ADDRESS=""
REALITY_TARGET="www.microsoft.com:443"
REALITY_SNI=""
XHTTP_PATH=""
UUID=""
SHORT_ID=""
SPIDER_X=""
NO_FIREWALL=0

usage() {
  cat <<EOF
Xray VLESS + XHTTP + REALITY one-key installer for Debian 13.

Usage:
  sudo bash ${SCRIPT_NAME} [options]

Options:
  --host <ip-or-domain>       Server address written to the VLESS link.
  --port <port>               Listen port. Default: random free high port.
  --dest <domain:port>        REALITY target. Default: ${REALITY_TARGET}
  --sni <domain>              REALITY serverName. Default: domain part of --dest.
  --path </path>              XHTTP path. Default: random path.
  --uuid <uuid>               VLESS UUID. Default: random UUID.
  --short-id <hex>            REALITY shortId. Default: random 16-char hex.
  --spider-x </path>          REALITY spiderX for client config/link. Default: random path.
  --no-firewall               Do not touch ufw/firewalld even if active.
  -h, --help                  Show this help.

Examples:
  sudo bash ${SCRIPT_NAME}
  sudo bash ${SCRIPT_NAME} --host vpn.example.com --dest www.apple.com:443 --sni www.apple.com
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

log() {
  echo "==> $*"
}

require_value() {
  local option="$1"
  local value="${2:-}"
  if [[ -z "${value}" || "${value}" == --* ]]; then
    die "${option} requires a value."
  fi
}

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Please run as root: sudo bash ${SCRIPT_NAME}"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host)
        require_value "$1" "${2:-}"
        SERVER_ADDRESS="${2:-}"
        shift 2
        ;;
      --port)
        require_value "$1" "${2:-}"
        PORT="${2:-}"
        shift 2
        ;;
      --dest)
        require_value "$1" "${2:-}"
        REALITY_TARGET="${2:-}"
        shift 2
        ;;
      --sni)
        require_value "$1" "${2:-}"
        REALITY_SNI="${2:-}"
        shift 2
        ;;
      --path)
        require_value "$1" "${2:-}"
        XHTTP_PATH="${2:-}"
        shift 2
        ;;
      --uuid)
        require_value "$1" "${2:-}"
        UUID="${2:-}"
        shift 2
        ;;
      --short-id)
        require_value "$1" "${2:-}"
        SHORT_ID="${2:-}"
        shift 2
        ;;
      --spider-x)
        require_value "$1" "${2:-}"
        SPIDER_X="${2:-}"
        shift 2
        ;;
      --no-firewall)
        NO_FIREWALL=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

detect_os() {
  if [[ ! -r /etc/os-release ]]; then
    die "Cannot read /etc/os-release"
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  if [[ "${ID:-}" != "debian" ]]; then
    log "Warning: this script is tuned for Debian 13, current ID=${ID:-unknown}."
  elif [[ "${VERSION_ID:-}" != "13" ]]; then
    log "Warning: this script is tuned for Debian 13, current VERSION_ID=${VERSION_ID:-unknown}."
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    die "systemd is required."
  fi
}

install_dependencies() {
  log "Installing base dependencies"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl openssl iproute2 coreutils
}

install_xray() {
  log "Installing or upgrading Xray-core"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  if ! curl -fsSL "${XRAY_INSTALL_URL}" -o "${tmp_dir}/install-release.sh"; then
    rm -rf "${tmp_dir}"
    die "Failed to download Xray installer."
  fi
  if ! bash "${tmp_dir}/install-release.sh" install; then
    rm -rf "${tmp_dir}"
    die "Xray installer failed."
  fi
  rm -rf "${tmp_dir}"

  if ! command -v xray >/dev/null 2>&1; then
    die "xray command was not found after installation."
  fi
}

random_hex() {
  local bytes="$1"
  openssl rand -hex "${bytes}"
}

port_in_use() {
  local port="$1"
  ss -H -tuln 2>/dev/null | awk '{print $5}' | grep -Eq "[:.]${port}$"
}

random_port() {
  local candidate
  for _ in $(seq 1 100); do
    candidate="$(shuf -i 20000-65000 -n 1)"
    if ! port_in_use "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

detect_public_address() {
  local ip=""
  local urls=(
    "https://api.ipify.org"
    "https://ifconfig.me/ip"
    "https://icanhazip.com"
  )

  for url in "${urls[@]}"; do
    ip="$(curl -fsS4 --max-time 8 "${url}" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      printf '%s\n' "${ip}"
      return 0
    fi
  done

  for url in "${urls[@]}"; do
    ip="$(curl -fsS6 --max-time 8 "${url}" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "${ip}" == *:* ]]; then
      printf '%s\n' "${ip}"
      return 0
    fi
  done

  printf '%s\n' "YOUR_SERVER_IP"
}

domain_from_target() {
  local target="$1"
  printf '%s\n' "${target%%:*}"
}

normalize_path() {
  local value="$1"
  if [[ -z "${value}" ]]; then
    die "Path cannot be empty."
  fi
  if [[ "${value}" != /* ]]; then
    value="/${value}"
  fi
  printf '%s\n' "${value}"
}

validate_inputs() {
  if [[ -n "${PORT}" && ! "${PORT}" =~ ^[0-9]+$ ]]; then
    die "--port must be a number."
  fi

  if [[ -n "${PORT}" && ( "${PORT}" -lt 1024 || "${PORT}" -gt 65535 ) ]]; then
    die "--port must be between 1024 and 65535."
  fi

  if [[ -n "${PORT}" ]] && port_in_use "${PORT}"; then
    die "Port ${PORT} is already in use."
  fi

  if [[ "${REALITY_TARGET}" != *:* ]]; then
    die "--dest must look like domain:port, for example www.microsoft.com:443."
  fi

  if [[ -n "${SHORT_ID}" && ! "${SHORT_ID}" =~ ^[0-9a-fA-F]{2,16}$ ]]; then
    die "--short-id must be even-length hex, 2 to 16 chars."
  fi

  if [[ -n "${SHORT_ID}" && $(( ${#SHORT_ID} % 2 )) -ne 0 ]]; then
    die "--short-id length must be even."
  fi
}

generate_values() {
  log "Generating config values"

  if [[ -z "${PORT}" ]]; then
    PORT="$(random_port)" || die "Failed to find a free high port."
  fi

  if [[ -z "${SERVER_ADDRESS}" ]]; then
    SERVER_ADDRESS="$(detect_public_address)"
  fi

  if [[ -z "${REALITY_SNI}" ]]; then
    REALITY_SNI="$(domain_from_target "${REALITY_TARGET}")"
  fi

  if [[ -z "${XHTTP_PATH}" ]]; then
    XHTTP_PATH="/$(random_hex 8)"
  fi
  XHTTP_PATH="$(normalize_path "${XHTTP_PATH}")"

  if [[ -z "${UUID}" ]]; then
    UUID="$(xray uuid)"
  fi

  if [[ -z "${SHORT_ID}" ]]; then
    SHORT_ID="$(random_hex 8)"
  fi

  if [[ -z "${SPIDER_X}" ]]; then
    SPIDER_X="/$(random_hex 4)"
  fi
  SPIDER_X="$(normalize_path "${SPIDER_X}")"
}

generate_x25519() {
  local output
  output="$(xray x25519)"
  PRIVATE_KEY="$(awk -F':[[:space:]]*' '/^(Private key|PrivateKey):/ {print $2; exit}' <<<"${output}")"
  PUBLIC_KEY="$(awk -F':[[:space:]]*' '/^(Public key|PublicKey|Password \(PublicKey\)):/ {print $2; exit}' <<<"${output}")"

  if [[ -z "${PRIVATE_KEY}" || -z "${PUBLIC_KEY}" ]]; then
    echo "${output}" >&2
    die "Failed to parse xray x25519 output."
  fi
}

backup_existing_config() {
  if [[ -f "${CONFIG_FILE}" ]]; then
    local backup_file
    backup_file="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "${CONFIG_FILE}" "${backup_file}"
    log "Existing config backed up to ${backup_file}"
  fi
}

write_server_config() {
  log "Writing server config to ${CONFIG_FILE}"
  install -d -m 755 "$(dirname "${CONFIG_FILE}")"
  backup_existing_config

  cat > "${CONFIG_FILE}" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-xhttp-reality",
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "path": "${XHTTP_PATH}"
        },
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "${REALITY_TARGET}",
          "serverNames": [
            "${REALITY_SNI}"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      }
    ]
  }
}
EOF

  local nobody_group
  nobody_group="$(id -gn nobody 2>/dev/null || printf '%s\n' nogroup)"
  chown "root:${nobody_group}" "${CONFIG_FILE}" 2>/dev/null || chown root:root "${CONFIG_FILE}"
  chmod 640 "${CONFIG_FILE}" 2>/dev/null || chmod 644 "${CONFIG_FILE}"
}

urlencode() {
  local string="$1"
  local encoded=""
  local pos char
  for ((pos = 0; pos < ${#string}; pos++)); do
    char="${string:${pos}:1}"
    case "${char}" in
      [-_.~a-zA-Z0-9])
        encoded+="${char}"
        ;;
      *)
        printf -v encoded '%s%%%02X' "${encoded}" "'${char}"
        ;;
    esac
  done
  printf '%s\n' "${encoded}"
}

host_for_uri() {
  local host="$1"
  if [[ "${host}" == *:* && "${host}" != \[*\] ]]; then
    printf '[%s]\n' "${host}"
  else
    printf '%s\n' "${host}"
  fi
}

build_vless_uri() {
  local uri_host query name
  uri_host="$(host_for_uri "${SERVER_ADDRESS}")"
  query="encryption=none"
  query+="&security=reality"
  query+="&sni=$(urlencode "${REALITY_SNI}")"
  query+="&fp=chrome"
  query+="&pbk=$(urlencode "${PUBLIC_KEY}")"
  query+="&sid=$(urlencode "${SHORT_ID}")"
  query+="&spx=$(urlencode "${SPIDER_X}")"
  query+="&type=xhttp"
  query+="&path=$(urlencode "${XHTTP_PATH}")"
  name="$(urlencode "xhttp-reality-${SERVER_ADDRESS}")"
  printf 'vless://%s@%s:%s?%s#%s\n' "${UUID}" "${uri_host}" "${PORT}" "${query}" "${name}"
}

write_client_outputs() {
  local vless_uri
  vless_uri="$(build_vless_uri)"

  log "Writing client outputs"
  cat > "${CLIENT_FILE}" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "socks-in",
      "listen": "127.0.0.1",
      "port": 10808,
      "protocol": "socks",
      "settings": {
        "udp": true
      }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "${SERVER_ADDRESS}",
            "port": ${PORT},
            "users": [
              {
                "id": "${UUID}",
                "encryption": "none",
                "flow": ""
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "path": "${XHTTP_PATH}"
        },
        "security": "reality",
        "realitySettings": {
          "serverName": "${REALITY_SNI}",
          "password": "${PUBLIC_KEY}",
          "shortId": "${SHORT_ID}",
          "spiderX": "${SPIDER_X}",
          "fingerprint": "chrome"
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ]
}
EOF

  cat > "${RESULT_FILE}" <<EOF
Xray VLESS + XHTTP + REALITY

Server address: ${SERVER_ADDRESS}
Port: ${PORT}
UUID: ${UUID}
Transport: xhttp
XHTTP path: ${XHTTP_PATH}
REALITY target: ${REALITY_TARGET}
REALITY serverName/SNI: ${REALITY_SNI}
REALITY publicKey: ${PUBLIC_KEY}
REALITY shortId: ${SHORT_ID}
REALITY spiderX: ${SPIDER_X}

VLESS URI:
${vless_uri}

Server config:
${CONFIG_FILE}

Client JSON:
${CLIENT_FILE}
EOF

  chmod 600 "${RESULT_FILE}" "${CLIENT_FILE}"

  echo
  echo "==================== XHTTP + REALITY ===================="
  cat "${RESULT_FILE}"
  echo "=========================================================="
  echo
}

configure_firewall() {
  if [[ "${NO_FIREWALL}" -eq 1 ]]; then
    return 0
  fi

  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    log "Opening TCP ${PORT} in ufw"
    ufw allow "${PORT}/tcp"
  fi

  if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    log "Opening TCP ${PORT} in firewalld"
    firewall-cmd --permanent --add-port="${PORT}/tcp"
    firewall-cmd --reload
  fi
}

validate_and_start() {
  log "Validating Xray config"
  xray run -test -config "${CONFIG_FILE}"

  log "Starting Xray service"
  systemctl daemon-reload
  systemctl enable xray >/dev/null
  systemctl restart xray

  if ! systemctl is-active --quiet xray; then
    journalctl -u xray -n 80 --no-pager >&2 || true
    die "Xray service failed to start."
  fi
}

main() {
  need_root
  parse_args "$@"
  detect_os
  install_dependencies
  install_xray
  validate_inputs
  generate_values
  generate_x25519
  write_server_config
  configure_firewall
  validate_and_start
  write_client_outputs

  log "Done. If the VPS provider has a security group, also open TCP ${PORT} there."
}

main "$@"
