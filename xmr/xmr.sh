#!/bin/sh

# variables
BASE_URL="https://cdn.jsdelivr.net/gh/zkysimon/script@latest/xmr/xmrig"
POOL="pool.minexmr.com:3333"
WALLET=""
UUID=$(cut -d '-' -f 1 /proc/sys/kernel/random/uuid)
BACKGROUND=true
DONATE=0
USEAGE=100

# get options
while [[ $# -ge 1 ]]; do
    case $1 in
    -b | --background)
        shift
        BACKGROUND="$1"
        shift
        ;;
    -d | --donate)
        shift
        DONATE="$1"
        shift
        ;;
    -p | --pool)
        shift
        POOL="$1"
        shift
        ;;
    -u | --useage)
        shift
        USEAGE="$1"
        shift
        ;;
    -w | --wallet)
        shift
        WALLET="$1"
        shift
        ;;
    *)
        if [[ "$1" != 'error' ]]; then
            echo -ne "\nInvaild option: '$1'\n\n"
        fi
        exit 1
        ;;
    esac
done

rm -rf xmrig
wget --no-check-certificate ${BASE_URL}
chmod +x xmrig

# prepare config
rm -f config.json
cat > config.json << EOF
{
    "autosave": true,
    "background": ${BACKGROUND},
    "randomx": {
        "1gb-pages": true
    },
    "donate-level": ${DONATE},
    "cpu": {
        "enabled": true,
        "max-threads-hint": ${USEAGE}
    },
    "opencl": false,
    "cuda": false,
    "pools": [
        {
            "coin": null,
            "algo": null,
            "url": "${POOL}",
            "user": "${WALLET}+100000.${UUID}",
            "rig-id": "${UUID}",
            "pass": "x",
            "tls": false,
            "keepalive": true,
            "nicehash": true
        }
    ]
}
EOF

# load service
./xmrig
echo "xmrig已经启动,若使用默认的矿池，请前往 https://minexmr.com/dashboard?address=$WALLET 查看."
