#!/bin/bash

function docker_install()
{
	echo "检查Docker......"
	docker -v
    if [ $? -eq  0 ]; then
        echo "检查到Docker已安装!"
    else
    	echo "安装docker环境..."
        curl -fsSL https://get.docker.com | sh && systemctl enable docker
        echo "安装docker环境...安装完成!"
    fi
}

function check_mtp_install()
{
    echo "检测docker mtg 安装情况..."
    systemctl start docker
    docker ps -a | grep mtg
    if [ $? -eq 0 ]; then
        echo "检测到docker mtg已安装!"
        docker rm -f mtg
        docker ps -a | grep mtg
        echo "旧版docker mtg已经删除!"
    else
        echo "检测到docker mtg未安装!"
    fi
}

function get_config()
{
    echo "生成随机配置文件..."
    docker pull nineseconds/mtg:2
    secret=`docker run --rm nineseconds/mtg:2 generate-secret --hex bing.com`
    port=$((RANDOM + 10000))
    echo "选取的端口为:$port"
cat > /etc/mtg.toml << EOF
secret = "$secret"
bind-to = "0.0.0.0:443"
EOF

}
function install_mtp()
{
    echo "开始安装docker mtg..."
    docker run -d -v /etc/mtg.toml:/config.toml  --name=mtg --restart=always -p $port:443 nineseconds/mtg:2
    if [ $? -eq 0 ] ; then
        echo "docker mtg 安装完成!"
	  ip=`curl ip.sb`
    echo "-----------------------------------------------------"
	  echo "TG一键链接: https://t.me/proxy?server=$ip&port=$port&secret=$secret"
	  echo "TG一键链接: tg://proxy?server=$ip&port=$port&secret=$secret"
    echo "-----------------------------------------------------"
    else
        echo "docker mtg 安装失败!"
    fi
    
}



function main()
{
    
    echo "欢迎来到automtg--------by:zimk"
    echo "-----------------------------------------------------"
    echo "本脚本会为您自动重新安装mtg并随机更改端口"

    docker_install
    check_mtp_install
    get_config
    install_mtp

    echo "安装结束！"

}

main
