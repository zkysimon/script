#!/bin/bash

# 脚本名称：generate_fancy_sshkey_ed25519.sh
# 功能：在 Debian 上使用多线程无限生成满足靓号要求的 ED25519 SSH 密钥
# 要求：
# - 公钥 Base64 编码开头 12 个字符相同
# - 最后一个 / 后面为 ZIMK（全大写）或 zimk（全小写）
# - 密钥文件名：公钥 Base64 编码前 16 位
# - 公钥和私钥保存到同一文件，位于当前目录
# - 仅输出满足条件的公钥
# - 支持通过 -p 参数设置密钥密码
# - 使用所有 CPU 核心运行多线程
# - 无限运行

# 解析命令行参数
PASSWORD=""
while getopts "p:" opt; do
    case $opt in
        p)
            PASSWORD="$OPTARG"
            ;;
        \?)
            exit 1
            ;;
    esac
done

# 确保 ssh-keygen 存在
if ! command -v ssh-keygen &> /dev/null; then
    exit 1
fi

# 检查 OpenSSH 版本是否支持 ED25519
SSH_VERSION=$(ssh -V 2>&1 | grep -o 'OpenSSH_[0-9.]*' | cut -d'_' -f2)
if [[ $(echo "$SSH_VERSION" | cut -d'.' -f1) -lt 6 || ( $(echo "$SSH_VERSION" | cut -d'.' -f1) -eq 6 && $(echo "$SSH_VERSION" | cut -d'.' -f2) -lt 5 ) ]]; then
    exit 1
fi

# 获取 CPU 核心数
THREADS=$(nproc)

# 确保当前目录可写
if ! touch .test_write 2>/dev/null; then
    exit 1
fi
rm -f .test_write

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

        # 获取前 16 位作为文件名
        FILENAME=$(echo "$PUB_KEY" | head -c 16)

        # 检查文件名是否有效（仅包含 Base64 字符）
        if [[ ! "$FILENAME" =~ ^[A-Za-z0-9+/]+$ ]]; then
            rm -f "$TEMP_KEY" "$TEMP_PUB"
            continue
        fi

        # 检查文件名是否已存在，添加时间戳后缀
        if [ -f "./${FILENAME}" ]; then
            FILENAME="${FILENAME}_$(date +%s)"
        fi

        # 保存公钥和私钥到同一文件
        {
            echo "-----BEGIN PRIVATE KEY-----"
            cat "$TEMP_KEY"
            echo "-----END PRIVATE KEY-----"
            echo "-----BEGIN PUBLIC KEY-----"
            cat "$TEMP_PUB"
            echo "-----END PUBLIC KEY-----"
        } > "./${FILENAME}"

        # 设置文件权限
        chmod 600 "./${FILENAME}"

        # 输出公钥内容
        cat "./${FILENAME}.pub"

        # 清理临时文件
        rm -f "$TEMP_KEY" "$TEMP_PUB"
    done
}

# 导出函数以便并行执行
export -f generate_key
export PASSWORD

# 启动并行线程
for ((i=1; i<=THREADS; i++)); do
    generate_key $i &
done

# 等待所有线程（无限运行，直到 Ctrl+C）
wait
