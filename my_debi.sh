#!/bin/bash
#
# ==============================================================================
#  “集大成”终极版 DD 安装包装脚本 (v10)
#
#  - 智能检测 IP、网关、内核，但允许用户通过提供同名参数来覆盖任何检测。
#  - 提供可被覆盖的默认 user 和 password。
#  - 其他所有未被脚本处理的参数都将原封不动地传递给底层的 debi.sh 脚本。
# ==============================================================================

# --- 可在此处修改默认值 ---
DEFAULT_USER="root"
DEFAULT_PASSWORD="123456"

# --- 1. 预先检查用户提供了哪些参数，以决定是否启用自动检测 ---
user_provided_ip=false
user_provided_gateway=false
user_provided_kernel=false
user_provided_user=false
user_provided_pass=false

for arg in "$@"; do
  case "$arg" in
    --ip) user_provided_ip=true ;;
    --gateway) user_provided_gateway=true ;;
    --cloud-kernel|--no-cloud-kernel) user_provided_kernel=true ;;
    --user) user_provided_user=true ;;
    --password) user_provided_pass=true ;;
  esac
done

# --- 2. 初始化最终参数列表，首先包含用户提供的所有参数 ---
FINAL_ARGS=("$@")

# --- 3. 根据用户是否提供参数，来决定是否执行相应的智能检测和添加默认值 ---

# --- 智能检测网络 ---
if [ "$user_provided_ip" = false ] && [ "$user_provided_gateway" = false ]; then
  echo "INFO: 未提供网络参数，开始自动检测 IP 和网关..."
  DEFAULT_ROUTE_LINE=$(ip r | grep default)
  if [ -z "$DEFAULT_ROUTE_LINE" ]; then
      echo "ERROR: 自动检测失败：无法找到默认路由。"
  else
      IFACE=$(echo "$DEFAULT_ROUTE_LINE" | awk '{print $5}')
      GATEWAY=$(echo "$DEFAULT_ROUTE_LINE" | awk '{print $3}')
      IP_CIDR=$(ip -4 a s "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
      if [ -n "$IP_CIDR" ] && [ -n "$GATEWAY" ]; then
          echo "INFO: 自动检测成功: IP=$IP_CIDR, Gateway=$GATEWAY"
          FINAL_ARGS+=(--ip "$IP_CIDR" --gateway "$GATEWAY")
      else
          echo "ERROR: 自动检测失败：无法从主网卡 '$IFACE' 获取完整网络信息。"
      fi
  fi
else
  echo "INFO: 检测到用户已手动提供网络参数，跳过自动检测。"
fi

# --- 智能选择内核 ---
if [ "$user_provided_kernel" = false ]; then
  echo "INFO: 未提供内核参数，开始根据网卡驱动自动选择内核..."
  KERNEL_PARAM="--cloud-kernel"
  if ! command -v lspci &> /dev/null; then
      echo "WARN: 未找到 lspci 命令。为确保兼容性，将强制使用通用内核。"
      KERNEL_PARAM=""
  else
      # 需要先确定网卡接口，即使网络参数是手动指定的
      IFACE_FOR_KERNEL_DETECTION=$(ip r | grep default | awk '{print $5}')
      if [ -n "$IFACE_FOR_KERNEL_DETECTION" ]; then
        PCI_ADDR=$(basename $(readlink -f /sys/class/net/$IFACE_FOR_KERNEL_DETECTION/device))
        DEVICE_INFO=$(lspci -s "$PCI_ADDR")
        if echo "$DEVICE_INFO" | grep -iq "Realtek" || echo "$DEVICE_INFO" | grep -iq "Virtual Function"; then
            echo "WARN: 检测到主网卡为 Realtek 或 VF 设备。将使用通用内核。"
            KERNEL_PARAM=""
        else
            echo "INFO: 主网卡设备类型兼容，将使用优化的 Cloud Kernel。"
        fi
      else
        echo "WARN: 无法确定主网卡以进行内核检测，将使用通用内核。"
        KERNEL_PARAM=""
      fi
  fi

  if [ -n "$KERNEL_PARAM" ]; then
    FINAL_ARGS+=("$KERNEL_PARAM")
  fi
else
  echo "INFO: 检测到用户已手动提供内核参数，跳过自动检测。"
fi

# --- 添加默认用户和密码 ---
if [ "$user_provided_user" = false ]; then
  echo "INFO: 未提供 --user 参数，将使用默认值: $DEFAULT_USER"
  FINAL_ARGS+=(--user "$DEFAULT_USER")
fi
if [ "$user_provided_pass" = false ]; then
  echo "INFO: 未提供 --password 参数，将使用默认密码。"
  FINAL_ARGS+=(--password "$DEFAULT_PASSWORD")
fi

# ==============================================================================
#  执行区
# ==============================================================================
echo "--------------------------------------------------"
echo "最终将执行: bash ./debi.sh ${FINAL_ARGS[*]}"
echo "--------------------------------------------------"
echo "将在 5 秒后开始执行 DD 安装，按 Ctrl+C 取消..."
sleep 5

# 下载底层脚本
echo "INFO: 正在下载底层安装脚本 (debi.sh)..."
curl -fLO https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh
if [ ! -f "debi.sh" ]; then
    echo "ERROR: 下载 debootstrap 脚本 (debi.sh) 失败。"
    exit 1
fi

# 强制使用 bash 执行
echo "INFO: 下载完成，强制使用 bash 解释器执行安装..."
bash ./debi.sh "${FINAL_ARGS[@]}" && \
shutdown -r now
