#!/bin/bash

# --- 可在此处修改默认值 ---
DEFAULT_USER="root"
DEFAULT_PASSWORD="123456" # 建议修改为一个更复杂的默认密码

# --- 检查用户是否已提供 user/password ---
user_provided=false
pass_provided=false
for arg in "$@"; do
  if [[ "$arg" == "--user" ]]; then
    user_provided=true
  fi
  if [[ "$arg" == "--password" ]]; then
    pass_provided=true
  fi
done

# --- 构建最终参数列表 ---
FINAL_ARGS=("$@") # 首先包含用户提供的所有参数

# 如果用户未提供，则添加默认值
if [ "$user_provided" = false ]; then
  echo "INFO: 未提供 --user 参数，将使用默认值: $DEFAULT_USER"
  FINAL_ARGS+=(--user "$DEFAULT_USER")
fi
if [ "$pass_provided" = false ]; then
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
