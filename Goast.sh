#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

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

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "是否重启Goast" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontents.com/EUForest/Goast-script/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "输入指定版本(默认最新版): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontents.com/EUForest/Goast-script/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}更新完成，已自动重启 Goast，请使用 Goast log 查看运行日志${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "Goast在修改配置后会自动尝试重启"
    vi /etc/Goast/config.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "Goast状态: ${green}已运行${plain}"
            ;;
        1)
            echo -e "检测到您未启动Goast或Goast自动重启失败，是否查看日志？[Y/n]" && echo
            read -e -rp "(默认: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "Goast状态: ${red}未安装${plain}"
    esac
}

uninstall() {
    confirm "确定要卸载 Goast 吗?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop Goast
    systemctl disable Goast
    rm /etc/systemd/system/Goast.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/Goast/ -rf
    rm /usr/local/Goast/ -rf

    echo ""
    echo -e "卸载成功，如果你想删除此脚本，则退出脚本后运行 ${green}rm /usr/bin/Goast -f${plain} 进行删除"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Goast已运行，无需再次启动，如需重启请选择重启${plain}"
    else
        systemctl start Goast
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}Goast 启动成功，请使用 Goast log 查看运行日志${plain}"
        else
            echo -e "${red}Goast可能启动失败，请稍后使用 Goast log 查看日志信息${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop Goast
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}Goast 停止成功${plain}"
    else
        echo -e "${red}Goast停止失败，可能是因为停止时间超过了两秒，请稍后查看日志信息${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart Goast
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Goast 重启成功，请使用 Goast log 查看运行日志${plain}"
    else
        echo -e "${red}Goast可能启动失败，请稍后使用 Goast log 查看日志信息${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status Goast --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable Goast
    if [[ $? == 0 ]]; then
        echo -e "${green}Goast 设置开机自启成功${plain}"
    else
        echo -e "${red}Goast 设置开机自启失败${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable Goast
    if [[ $? == 0 ]]; then
        echo -e "${green}Goast 取消开机自启成功${plain}"
    else
        echo -e "${red}Goast 取消开机自启失败${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u Goast.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh)
}

update_shell() {
    wget -O /usr/bin/Goast -N --no-check-certificate https://github.com/EUForest/Goast-script/master/Goast.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}下载脚本失败，请检查本机能否连接 Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/Goast
        echo -e "${green}升级脚本成功，请重新运行脚本${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/Goast.service ]]; then
        return 2
    fi
    temp=$(systemctl status Goast | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled Goast)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Goast已安装，请不要重复安装${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}请先安装Goast${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Goast状态: ${green}已运行${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Goast状态: ${yellow}未运行${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Goast状态: ${red}未安装${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自启: ${green}是${plain}"
    else
        echo -e "是否开机自启: ${red}否${plain}"
    fi
}

generate_x25519_key() {
    echo -n "正在生成 x25519 密钥："
    /usr/local/Goast/Goast x25519
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_Goast_version() {
    echo -n "Goast 版本："
    /usr/local/Goast/Goast version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

add_node_config() {
    echo -e "${green}请选择节点核心类型：${plain}"
    echo -e "${green}1. xray${plain}"
    echo -e "${green}2. singbox${plain}"
    read -rp "请输入：" core_type
    if [ "$core_type" == "1" ]; then
        core="xray"
        core_xray=true
    elif [ "$core_type" == "2" ]; then
        core="sing"
        core_sing=true
    else
        echo "无效的选择。请选择 1 或 2。"
        continue
    fi
    while true; do
        read -rp "请输入节点Node ID：" NodeID
        # 判断NodeID是否为正整数
        if [[ "$NodeID" =~ ^[0-9]+$ ]]; then
            break  # 输入正确，退出循环
        else
            echo "错误：请输入正确的数字作为Node ID。"
        fi
    done
    
    echo -e "${yellow}请选择节点传输协议：${plain}"
    echo -e "${green}1. Shadowsocks${plain}"
    echo -e "${green}2. Vless${plain}"
    echo -e "${green}3. Vmess${plain}"
    echo -e "${green}4. Hysteria${plain}"
    echo -e "${green}5. Hysteria2${plain}"
    echo -e "${green}6. Tuic${plain}"
    echo -e "${green}7. Trojan${plain}"
    read -rp "请输入：" NodeType
    case "$NodeType" in
        1 ) NodeType="shadowsocks" ;;
        2 ) NodeType="vless" ;;
        3 ) NodeType="vmess" ;;
        4 ) NodeType="hysteria" ;;
        5 ) NodeType="hysteria2" ;;
        6 ) NodeType="tuic" ;;
        7 ) NodeType="trojan" ;;
        * ) NodeType="shadowsocks" ;;
    esac

    nodes_config+=(
        {
            \"Core\": \"$core\",
            \"ApiHost\": \"$ApiHost\",
            \"ApiKey\": \"$ApiKey\",
            \"NodeID\": $NodeID,
            \"NodeType\": \"$NodeType\",
            \"Timeout\": 4,
            \"ListenIP\": \"0.0.0.0\",
            \"SendIP\": \"0.0.0.0\",
            \"EnableProxyProtocol\": false,
            \"EnableUot\": true,
            \"EnableTFO\": true,
            \"DNSType\": \"UseIPv4\"
        }
    )
    nodes_config+=(",")
}
    

generate_config_file() {
    echo -e "${yellow}Goast 配置文件生成向导${plain}"
    echo -e "${red}请阅读以下注意事项：${plain}"
    echo -e "${red}1. 目前该功能正处测试阶段${plain}"
    echo -e "${red}2. 生成的配置文件会保存到 /etc/Goast/config.json${plain}"
    echo -e "${red}3. 原来的配置文件会保存到 /etc/Goast/config.json.bak${plain}"
    echo -e "${red}4. 目前不支持TLS${plain}"
    echo -e "${red}5. 使用此功能生成的配置文件会自带审计，确定继续？(y/n)${plain}"
    read -rp "请输入：" continue_prompt
    if [[ "$continue_prompt" =~ ^[Nn][Oo]? ]]; then
        exit 0
    fi
    
    nodes_config=()
    first_node=true
    core_xray=false
    core_sing=false
    fixed_api_info=false
    check_api=false
    
    while true; do
        if [ "$first_node" = true ]; then
            read -rp "请输入机场网址：" ApiHost
            read -rp "请输入面板对接API Key：" ApiKey
            read -rp "是否设置固定的机场网址和API Key？(y/n)" fixed_api
            if [ "$fixed_api" = "y" ] || [ "$fixed_api" = "Y" ]; then
                fixed_api_info=true
                echo -e "${red}成功固定地址${plain}"
            fi
            first_node=false
            add_node_config
        else
            read -rp "是否继续添加节点配置？(回车继续，输入n或no退出)" continue_adding_node
            if [[ "$continue_adding_node" =~ ^[Nn][Oo]? ]]; then
                break
            elif [ "$fixed_api_info" = false ]; then
                read -rp "请输入机场网址：" ApiHost
                read -rp "请输入面板对接API Key：" ApiKey
            fi
            add_node_config
        fi
    done

    # 根据核心类型生成 Cores
    if [ "$core_xray" = true ] && [ "$core_sing" = true ]; then
        cores_config="[
        {
            \"Type\": \"xray\",
            \"Log\": {
                \"Level\": \"error\",
                \"ErrorPath\": \"/etc/Goast/error.log\"
            },
            \"OutboundConfigPath\": \"/etc/Goast/custom_outbound.json\",
            \"RouteConfigPath\": \"/etc/Goast/route.json\"
        },
        {
            \"Type\": \"sing\",
            \"Log\": {
                \"Level\": \"error\",
                \"Timestamp\": true
            },
            \"NTP\": {
                \"Enable\": true,
                \"Server\": \"time.apple.com\",
                \"ServerPort\": 0
            }
        }
        ]"
    elif [ "$core_xray" = true ]; then
        cores_config="[
        {
            \"Type\": \"xray\",
            \"Log\": {
                \"Level\": \"error\",
                \"ErrorPath\": \"/etc/Goast/error.log\"
            },
            \"OutboundConfigPath\": \"/etc/Goast/custom_outbound.json\",
            \"RouteConfigPath\": \"/etc/Goast/route.json\"
        }
        ]"
    elif [ "$core_sing" = true ]; then
        cores_config="[
        {
            \"Type\": \"sing\",
            \"Log\": {
                \"Level\": \"error\",
                \"Timestamp\": true
            },
            \"NTP\": {
                \"Enable\": true,
                \"Server\": \"time.apple.com\",
                \"ServerPort\": 0
            }
        }
        ]"
    fi

    # 切换到配置文件目录
    cd /etc/Goast
    
    # 备份旧的配置文件
    mv config.json config.json.bak
    formatted_nodes_config=$(echo "${nodes_config[*]}" | sed 's/,\s*$//')
    
    # 创建 config.json 文件
    cat <<EOF > /etc/Goast/config.json
    {
        "Log": {
            "Level": "error",
            "Output": ""
        },
        "Cores": $cores_config,
        "Nodes": [$formatted_nodes_config]
    }
EOF
    
    # 创建 custom_outbound.json 文件
    cat <<EOF > /etc/Goast/custom_outbound.json
    [
        {
            "tag": "IPv4_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv4"
            }
        },
        {
            "tag": "IPv6_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv6"
            }
        },
        {
            "tag": "direct",
            "protocol": "freedom"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
EOF
    
    # 创建 route.json 文件
    cat <<EOF > /etc/Goast/route.json
    {
        "domainStrategy": "AsIs",
        "rules": [
            {
                "type": "field",
                "outboundTag": "block",
                "ip": [
                    "geoip:private",
                    "58.87.70.69"
                ]
            },
            {
                "type": "field",
                "outboundTag": "direct",
                "domain": [
                    "domain:zgovps.com"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "domain": [
                    "regexp:(api|ps|sv|offnavi|newvector|ulog.imap|newloc)(.map|).(baidu|n.shifen).com",
                    "regexp:(.+.|^)(360|so).(cn|com)",
                    "regexp:(Subject|HELO|SMTP)",
                    "regexp:(torrent|.torrent|peer_id=|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=)",
                    "regexp:(^.@)(guerrillamail|guerrillamailblock|sharklasers|grr|pokemail|spam4|bccto|chacuo|027168).(info|biz|com|de|net|org|me|la)",
                    "regexp:(.?)(xunlei|sandai|Thunder|XLLiveUD)(.)",
                    "regexp:(..||)(dafahao|mingjinglive|botanwang|minghui|dongtaiwang|falunaz|epochtimes|ntdtv|falundafa|falungong|wujieliulan|zhengjian).(org|com|net)",
                    "regexp:(ed2k|.torrent|peer_id=|announce|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=|magnet:|xunlei|sandai|Thunder|XLLiveUD|bt_key)",
                    "regexp:(.+.|^)(360|speedtest|fast).(cn|com|net)",
                    "regexp:(.*.||)(guanjia.qq.com|qqpcmgr|QQPCMGR)",
                    "regexp:(.*.||)(rising|kingsoft|duba|xindubawukong|jinshanduba).(com|net|org)",
                    "regexp:(.*.||)(netvigator|torproject).(com|cn|net|org)",
                    "regexp:(..||)(visa|mycard|gov|gash|beanfun|bank).",
                    "regexp:(.*.||)(gov|12377|12315|talk.news.pts.org|creaders|zhuichaguoji|efcc.org|cyberpolice|aboluowang|tuidang|epochtimes|nytimes|zhengjian|110.qq|mingjingnews|inmediahk|xinsheng|breakgfw|chengmingmag|jinpianwang|qi-gong|mhradio|edoors|renminbao|soundofhope|xizang-zhiye|bannedbook|ntdtv|12321|secretchina|dajiyuan|boxun|chinadigitaltimes|dwnews|huaglad|oneplusnews|epochweekly|cn.rfi).(cn|com|org|net|club|net|fr|tw|hk|eu|info|me)",
                    "regexp:(.*.||)(miaozhen|cnzz|talkingdata|umeng).(cn|com)",
                    "regexp:(.*.||)(mycard).(com|tw)",
                    "regexp:(.*.||)(gash).(com|tw)",
                    "regexp:(.bank.)",
                    "regexp:(.*.||)(pincong).(rocks)",
                    "regexp:(.*.||)(taobao).(com)",
                    "regexp:(.*.||)(laomoe|jiyou|ssss|lolicp|vv1234|0z|4321q|868123|ksweb|mm126).(com|cloud|fun|cn|gs|xyz|cc)",
                    "regexp:(flows|miaoko).(pages).(dev)"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "ip": [
                    "127.0.0.1/32",
                    "10.0.0.0/8",
                    "fc00::/7",
                    "fe80::/10",
                    "172.16.0.0/12"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "protocol": [
                    "bittorrent"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "port": "23,24,25,107,194,445,465,587,992,3389,6665-6669,6679,6697,6881-6999,7000"
            }
        ]
    }
EOF
                

    echo -e "${green}Goast 配置文件生成完成，正在重新启动 Goast 服务${plain}"
    restart 0
    before_show_menu
}

# 放开防火墙端口
open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}放开防火墙端口成功！${plain}"
}

show_usage() {
    echo "Goast 管理脚本使用方法: "
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
    echo "Goast update x.x.x - 安装 Goast 指定版本"
    echo "Goast install      - 安装 Goast"
    echo "Goast uninstall    - 卸载 Goast"
    echo "Goast version      - 查看 Goast 版本"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Goast 后端管理脚本，${plain}${red}不适用于docker${plain}
--- https://github.com/EUForest/Goast ---
  ${green}0.${plain} 修改配置
————————————————
  ${green}1.${plain} 安装 Goast
  ${green}2.${plain} 更新 Goast
  ${green}3.${plain} 卸载 Goast
————————————————
  ${green}4.${plain} 启动 Goast
  ${green}5.${plain} 停止 Goast
  ${green}6.${plain} 重启 Goast
  ${green}7.${plain} 查看 Goast 状态
  ${green}8.${plain} 查看 Goast 日志
————————————————
  ${green}9.${plain} 设置 Goast 开机自启
  ${green}10.${plain} 取消 Goast 开机自启
————————————————
  ${green}11.${plain} 一键安装 bbr (最新内核)
  ${green}12.${plain} 查看 Goast 版本
  ${green}13.${plain} 生成 X25519 密钥
  ${green}14.${plain} 升级 Goast 维护脚本
  ${green}15.${plain} 生成 Goast 配置文件
  ${green}16.${plain} 放行 VPS 的所有网络端口
 "
 #后续更新可加入上方字符串中
    show_status
    echo && read -rp "请输入选择 [0-16]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_Goast_version ;;
        13) check_install && generate_x25519_key ;;
        14) update_shell ;;
        15) generate_config_file ;;
        16) open_ports ;;
        *) echo -e "${red}请输入正确的数字 [0-16]${plain}" ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "x25519") check_install 0 && generate_x25519_key 0 ;;
        "version") check_install 0 && show_Goast_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi
