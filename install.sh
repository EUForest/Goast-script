#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
        yum install ca-certificates wget -y
        update-ca-trust force-enable
    else
        apt-get update -y
        apt install wget curl unzip tar cron socat -y
        apt-get install ca-certificates wget -y
        update-ca-certificates
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_Goast() {
    if [[ -e /usr/local/Goast/ ]]; then
        rm -rf /usr/local/Goast/
    fi

    mkdir /usr/local/Goast/ -p
    cd /usr/local/Goast/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/EUForest/Goast/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 Goast 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 Goast 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 Goast 最新版本：${last_version}，开始安装"
        wget -q -N --no-check-certificate -O /usr/local/Goast/Goast-linux.zip https://github.com/EUForest/Goast-script/releases/download/${last_version}/Goast.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 Goast 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/EUForest/Goast-script/releases/download/${last_version}/Goast-linux-${arch}.zip"
        echo -e "开始安装 Goast $1"
        wget -q -N --no-check-certificate -O /usr/local/Goast/Goast.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 Goast $1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    unzip Goast.zip
    rm Goast.zip -f
    chmod +x Goast
    mkdir /etc/Goast/ -p
    rm /etc/systemd/system/Goast.service -f
    file="https://github.com/EUForest/Goast-script/raw/master/Goast.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/Goast.service ${file}
    #cp -f Goast.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop Goast
    systemctl enable Goast
    echo -e "${green}Goast ${last_version}${plain} 安装完成，已设置开机自启"
    cp geoip.dat /etc/Goast/
    cp geosite.dat /etc/Goast/

    if [[ ! -f /etc/Goast/config.json ]]; then
        cp config.json /etc/Goast/
        echo -e ""
        echo -e "全新安装，请先参看教程：https://github.com/EUForest/Goast/tree/master/example，配置必要的内容"
        first_install=true
    else
        systemctl start Goast
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}Goast 重启成功${plain}"
        else
            echo -e "${red}Goast 可能启动失败，请稍后使用 Goast log 查看日志信息，若无法启动，则可能更改了配置格式，请前往 wiki 查看：https://github.com/Goast-project/Goast/wiki${plain}"
        fi
        first_install=false
    fi

    if [[ ! -f /etc/Goast/dns.json ]]; then
        cp dns.json /etc/Goast/
    fi
    if [[ ! -f /etc/Goast/route.json ]]; then
        cp route.json /etc/Goast/
    fi
    if [[ ! -f /etc/Goast/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/Goast/
    fi
    if [[ ! -f /etc/Goast/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/Goast/
    fi
    curl -o /usr/bin/Goast -Ls https://github.com/EUForest/Goast-script/master/Goast.sh
    chmod +x /usr/bin/Goast
    if [ ! -L /usr/bin/v2bx ]; then
        ln -s /usr/bin/Goast /usr/bin/v2bx
        chmod +x /usr/bin/v2bx
    fi
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Goast 管理脚本使用方法 (兼容使用Goast执行，大小写不敏感): "
    echo "------------------------------------------"
    echo "Goast              - 显示管理菜单 (功能更多)"
    echo "Goast start        - 启动 Goast"
    echo "Goast stop         - 停止 Goast"
    echo "Goast restart      - 重启 Goast"
    echo "Goast status       - 查看 Goast 状态"
    echo "Goast enable       - 设置 Goast 开机自启"
    echo "Goast disable      - 取消 Goast 开机自启"
    echo "Goast log          - 查看 Goast 日志"
    echo "Goast x25519       - 生成 x25519 密钥"
    echo "Goast generate     - 生成 Goast 配置文件"
    echo "Goast update       - 更新 Goast"
    echo "Goast update x.x.x - 更新 Goast 指定版本"
    echo "Goast install      - 安装 Goast"
    echo "Goast uninstall    - 卸载 Goast"
    echo "Goast version      - 查看 Goast 版本"
    echo "------------------------------------------"
    # 首次安装询问是否生成配置文件
    if [[ $first_install == true ]]; then
        read -rp "检测到你为第一次安装Goast,是否自动直接生成配置文件？(y/n): " if_generate
        if [[ $if_generate == [Yy] ]]; then
            curl -o ./initconfig.sh -Ls https://github.com/EUForest/Goast-script/master/initconfig.sh
            source initconfig.sh
            rm initconfig.sh -f
            generate_config_file
            read -rp "是否安装bbr内核 ?(y/n): " if_install_bbr
            if [[ $if_install_bbr == [Yy] ]]; then
                install_bbr
            fi
        fi
    fi
}

echo -e "${green}开始安装${plain}"
install_base
install_Goast $1
