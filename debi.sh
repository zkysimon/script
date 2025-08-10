#!/bin/bash
#
# ==============================================================================
#  带条件化参数的智能 DD 安装 Debian 脚本
#
#  将此脚本保存为文件 (如 my_debi.sh), 授予执行权限 (chmod +x),
#  然后通过命令行参数进行自定义安装。
#  - 参数 --key 和 --install 是可选的，如果未提供，则不会传递给底层脚本。
# ==============================================================================

# --- 帮助信息函数 ---
usage() {
  echo "使用方法: $0 [选项]"
  echo "一个智能的 Debian DD 安装脚本，支持自动网络检测和内核选择。"
  echo
  echo "选项:"
  echo "  --user <用户名>       设置登录用户名 (默认: 'root')"
  echo "  --password <密码>     设置用户密码 (默认: '123456')"
  echo "  --key <URL>           (可选) 指定您的 authorized_keys 公钥链接。如果未提供，则不设置。"
  echo "  --install \"包列表\"    (可选) 用引号括起来的、空格分隔的预装软件包列表。"
  echo "  -h, --help            显示此帮助信息"
  echo
  echo "示例: ./my_debi.sh --user admin --password \"MyPass\" --key \"https://github.com/user.keys\""
}

# ==============================================================================
#  1. 定义默认值 (可选参数的变量留空)
# ==============================================================================
CUSTOM_USER='root'
CUSTOM_PASSWORD='123456'
CUSTOM_KEYS_URL=''      # 留空，等待参数提供
INSTALL_PACKAGES=''     # 留空，等待参数提供

# ==============================================================================
#  2. 解析命令行参数
# ==============================================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      CUSTOM_USER="$2"
      shift; shift
      ;;
    --password)
      CUSTOM_PASSWORD="$2"
      shift; shift
      ;;
    --key)
      CUSTOM_KEYS_URL="$2"
      shift; shift
      ;;
    --install)
      INSTALL_PACKAGES="$2"
      shift; shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "错误: 未知参数: $1"
      usage
      exit 1
      ;;
  esac
done

# ==============================================================================
#  核心逻辑区 (自动检测)
# ==============================================================================

# --- 3. 自动检测网络配置 ---
echo "INFO: 正在自动检测网络配置..."
DEFAULT_ROUTE_LINE=$(ip r | grep default)
if [ -z "$DEFAULT_ROUTE_LINE" ]; then
    echo "ERROR: 无法找到默认路由。无法确定主网卡和网关。"
    exit 1
fi
IFACE=$(echo "$DEFAULT_ROUTE_LINE" | awk '{print $5}')
GATEWAY=$(echo "$DEFAULT_ROUTE_LINE" | awk '{print $3}')
IP_CIDR=$(ip -4 a s "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
if [ -z "$IP_CIDR" ] || [ -z "$IFACE" ] || [ -z "$GATEWAY" ]; then
    echo "ERROR: 无法完整获取 IP 地址、网卡或网关信息。"
    exit 1
fi

# --- 4. 智能选择内核 ---
echo "INFO: 正在检测网卡驱动以决定内核类型..."
KERNEL_PARAM="--cloud-kernel"
DRIVER_NAME=$(basename $(readlink -f /sys/class/net/$IFACE/device/driver) 2>/dev/null || echo "unknown")
if [[ "$DRIVER_NAME" == *"81"* || "$DRIVER_NAME" == *"rtl"* ]]; then
    echo "WARN: 检测到 Realtek 网卡驱动 ($DRIVER_NAME)。为确保兼容性，将使用通用内核。"
    KERNEL_PARAM=""
else
    echo "INFO: 检测到驱动 ($DRIVER_NAME)。将使用优化的 Cloud Kernel。"
fi

# ==============================================================================
#  动态构建命令
# ==============================================================================

# --- 5. 使用数组动态构建 debi.sh 的参数 ---
DEBI_ARGS=(
  --cdn
  --ip "$IP_CIDR"
  --gateway "$GATEWAY"
  --dns '8.8.8.8 8.8.4.4'
  --timezone 'Asia/Shanghai'
  --bbr
  --user "$CUSTOM_USER"
  --password "$CUSTOM_PASSWORD"
)

# 如果 KERNEL_PARAM 非空, 则添加内核参数
if [ -n "$KERNEL_PARAM" ]; then
  DEBI_ARGS+=("$KERNEL_PARAM")
fi

# 如果用户通过 --key 提供了 URL, 则添加密钥参数
if [ -n "$CUSTOM_KEYS_URL" ]; then
  DEBI_ARGS+=(--authorized-keys-url "$CUSTOM_KEYS_URL")
fi

# 如果用户通过 --install 提供了软件包列表, 则添加安装参数
if [ -n "$INSTALL_PACKAGES" ]; then
  DEBI_ARGS+=(--install "$INSTALL_PACKAGES")
fi

# --- 6. 打印最终配置并确认 ---
echo "--------------------------------------------------"
echo "最终配置确认:"
echo "  - 用户名: $CUSTOM_USER"
echo "  - 密码: [已隐藏]"
echo "  - 主网卡: $IFACE"
echo "  - IP 地址: $IP_CIDR"
echo "  - 网关: $GATEWAY"
echo "  - 最终传递给 debi.sh 的命令: ./debi.sh ${DEBI_ARGS[*]}"
echo "--------------------------------------------------"
echo "将在 5 秒后开始执行 DD 安装，按 Ctrl+C 取消..."
sleep 5

# --- 7. 执行 DD 安装脚本 ---
curl -fLO https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh && \
chmod a+rx debi.sh && \
./debi.sh "${DEBI_ARGS[@]}" && \
shutdown -r now
