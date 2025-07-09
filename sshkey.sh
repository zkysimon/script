#!/bin/bash

# 脚本名称：generate_fancy_sshkey_ed25519.sh
# 功能：使用多线程无限生成满足靓号要求的 ED25519 SSH 密钥，并发送到 Telegram
# 要求：
# - 公钥 Base64 编码开头 12 个字符相同
# - 最后一个 / 后面为 ZIMK（全大写）或 zimk（全小写）
# - 支持通过 -p 参数设置密钥密码
# - 通过 -t 参数设置 Telegram Bot Token
# - 通过 -u 参数设置 Telegram 用户 ID
# - 使用所有 CPU 核心运行多线程
# - 无限运行
# - 密钥直接发送到 Telegram，不保存本地
# - 启动时发送测试消息

# 解析命令行参数
PASSWORD=""
BOT_TOKEN=""
CHAT_ID=""
while getopts "p:t:u:" opt; do
    case $opt in
        p)
            PASSWORD="$OPTARG"
            ;;
        t)
            BOT_TOKEN="$OPTARG"
            ;;
        u)
            CHAT_ID="$OPTARG"
            ;;
        \?)
            echo "用法：$0 [-p 密码] -t BotToken -u 用户ID"
            exit 1
            ;;
    esac
done

# 确保 Bot Token 和 用户 ID 已提供
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "错误：必须提供 Telegram Bot Token (-t) 和 用户 ID (-u)"
    exit 1
fi

# 确保 ssh-keygen 和 curl 存在
if ! command -v ssh-keygen &> /dev/null || ! command -v curl &> /dev/null; then
    echo "错误：需要安装 ssh-keygen 和 curl"
    exit 1
fi

# 检查 OpenSSH 版本是否支持 ED25519
SSH_VERSION=$(ssh -V 2>&1 | grep -o 'OpenSSH_[0-9.]*' | cut -d'_' -f2)
if [[ $(echo "$SSH_VERSION" | cut -d'.' -f1) -lt 6 || ( $(echo "$SSH_VERSION" | cut -d'.' -f1) -eq 6 && $(echo "$SSH_VERSION" | cut -d'.' -f2) -lt 5 ) ]]; then
    echo "错误：OpenSSH 版本过低，需要 6.5 或以上"
    exit 1
fi

# 获取 CPU 核心数
THREADS=$(nproc)

# 函数：发送消息到 Telegram
send_to_telegram() {
    local MESSAGE="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$MESSAGE" > /dev/null
    if [ $? -ne 0 ]; then
        echo "警告：发送 Telegram 消息失败"
    fi
}

# 发送测试消息
TEST_MESSAGE="脚本启动：$(date '+%Y-%m-%d %H:%M:%S')，开始生成 ED25519 靓号密钥"
send_to_telegram "$TEST_MESSAGE"
if [ $? -eq 0 ]; then
    echo "测试消息已发送到 Telegram"
else
    echo "错误：测试消息发送失败，请检查 Bot Token 和 用户 ID"
    exit 1
fi

# 函数：单个线程生成靓号密钥
generate_key() {
    local THREAD_ID=$1
    local TEMP_KEY="/tmp/temp_ed25519_$$_$THREAD_ID"
    local TEMP_PUB="/tmp/temp_ed25519_$$_$THREAD_ID.pub"

    while true; do
        # 生成 ED25519 密钥对，静默模式，使用指定密码（或无密码）
        ssh-keygen -t ed25519 -N "$PASSWORD" -f "$TEMP_KEY" -q

        # 读取公钥内容（仅 Base64 部分，忽略 ssh-ed25519 和注释）
        PUB_KEY=$(awk '{print $2}' "$TEMP_PUB")

        # 检查最后一个 / 后面的字符是否为 ZIMK 或 zimk
        LAST_PART=$(echo "$PUB_KEY" | grep -o '[^/]*$')
        if [ "$LAST_PART" != "ZIMK" ] && [ "$LAST_PART" != "zimk" ]; then
            rm -f "$TEMP_KEY" "$TEMP_PUB"
            continue
        fi

        # 检查开头 12 个字符是否相同
        FIRST_CHAR=${PUB_KEY:0:1}
        FIRST_12=${PUB_KEY:0:12}
        EXPECTED_12=$(printf "%${#FIRST_12}s" | tr " " "$FIRST_CHAR")
        if [ "$FIRST_12" != "$EXPECTED_12" ]; then
            rm -f "$TEMP_KEY" "$TEMP_PUB"
            continue
        fi

        # 获取前 16 位作为标识
        FILENAME=$(echo "$PUB_KEY" | head -c 16)

        # 检查文件名是否有效（仅包含 Base64 字符）
        if [[ ! "$FILENAME" =~ ^[A-Za-z0-9+/]+$ ]]; then
            rm -f "$TEMP_KEY" "$TEMP_PUB"
            continue
        fi

        # 准备发送到 Telegram 的内容
        KEY_CONTENT=$(cat <<EOF
New ED25519 Key Generated:
-----BEGIN PRIVATE KEY-----
$(cat "$TEMP_KEY")
-----END PRIVATE KEY-----
-----BEGIN PUBLIC KEY-----
$(cat "$TEMP_PUB")
-----END PUBLIC KEY-----
Identifier: $FILENAME
EOF
)

        # 发送到 Telegram
        send_to_telegram "$KEY_CONTENT"

        # 输出公钥到终端
        cat "$TEMP_PUB"

        # 清理临时文件
        rm -f "$TEMP_KEY" "$TEMP_PUB"
    done
}

# 导出函数以便并行执行
export -f generate_key
export -f send_to_telegram
export PASSWORD
export BOT_TOKEN
export CHAT_ID

# 启动并行线程
for ((i=1; i<=THREADS; i++)); do
    generate_key $i &
done

# 等待所有线程（无限运行，直到 Ctrl+C）
wait
