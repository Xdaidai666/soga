#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)
fixed_version="2.13.7"
download_base_url="${SOGA_INSTALL_BASE_URL:-https://raw.githubusercontent.com/xdaidai666/soga/main}"
package_name="soga-2.13.7-linux-amd64.tar.gz"
package_sha256="d8466d6cf8c075857d2ff7480e4a9092bedd1b7d7ba3d77886fdc375bbc6e4a0"
package_url="${download_base_url}/${package_name}"
manager_url="${download_base_url}/soga.sh"

[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用 root 用户运行此脚本！\n" && exit 1

if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif grep -Eqi "debian" /etc/issue 2>/dev/null; then
    release="debian"
elif grep -Eqi "ubuntu" /etc/issue 2>/dev/null; then
    release="ubuntu"
elif grep -Eqi "centos|red hat|redhat" /etc/issue 2>/dev/null; then
    release="centos"
elif grep -Eqi "debian" /proc/version 2>/dev/null; then
    release="debian"
elif grep -Eqi "ubuntu" /proc/version 2>/dev/null; then
    release="ubuntu"
elif grep -Eqi "centos|red hat|redhat" /proc/version 2>/dev/null; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)
if [[ "${arch}" == "x86_64" || "${arch}" == "x64" || "${arch}" == "amd64" ]]; then
    arch="amd64"
else
    echo -e "${red}仅支持 amd64 架构，当前架构：${arch}${plain}"
    exit 1
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ]; then
    echo "本软件不支持 32 位系统 (x86)，请使用 64 位系统 (x86_64)"
    exit 2
fi

is_cmd_exist() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        return 1
    fi
    which "$cmd" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        return 0
    fi
    return 2
}

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar crontabs socat tzdata -y
    else
        apt update -y
        apt install wget curl tar cron socat tzdata -y
    fi
}

check_status() {
    if [[ ! -f /etc/systemd/system/soga.service ]]; then
        return 2
    fi
    temp=$(systemctl status soga 2>/dev/null | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

install_soga() {
    cd /usr/local/
    if [[ -e /usr/local/soga/ ]]; then
        rm /usr/local/soga/ -rf
    fi

    if [ $# -gt 0 ] && [[ -n "${1}" ]]; then
        echo -e "${yellow}提示：${plain} 当前安装脚本已固定版本 ${fixed_version}，忽略自定义版本参数 ${1}"
    fi

    echo -e "开始安装 soga v${fixed_version}"
    wget -N --no-check-certificate -O /usr/local/soga.tar.gz "${package_url}"
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 soga 失败，请确认你的服务器可以访问 ${package_url}${plain}"
        exit 1
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        actual_sha256="$(sha256sum /usr/local/soga.tar.gz | awk '{print $1}')"
        if [[ "${actual_sha256}" != "${package_sha256}" ]]; then
            echo -e "${red}安装包校验失败${plain}"
            echo "期望: ${package_sha256}"
            echo "实际: ${actual_sha256}"
            exit 1
        fi
    fi

    tar zxvf soga.tar.gz
    rm soga.tar.gz -f
    cd soga
    chmod +x soga
    last_version="$(./soga -v)"
    mkdir /etc/soga/ -p
    rm /etc/systemd/system/soga.service -f
    rm /etc/systemd/system/soga@.service -f
    cp -f soga.service /etc/systemd/system/
    cp -f soga@.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop soga >/dev/null 2>&1 || true
    systemctl enable soga
    echo -e "${green}soga v${last_version}${plain} 安装完成，已设置开机自启"
    if [[ ! -f /etc/soga/soga.conf ]]; then
        cp soga.conf /etc/soga/
        echo
        echo -e "全新安装，请先配置必要内容后再运行 ${green}soga start${plain}"
    else
        systemctl start soga
        sleep 2
        check_status
        echo
        if [[ $? == 0 ]]; then
            echo -e "${green}soga 重启成功${plain}"
        else
            echo -e "${red}soga 可能启动失败，请稍后使用 soga log 查看日志信息${plain}"
        fi
    fi

    if [[ ! -f /etc/soga/blockList ]]; then
        cp blockList /etc/soga/
    fi
    if [[ ! -f /etc/soga/whiteList ]]; then
        cp whiteList /etc/soga/
    fi
    if [[ ! -f /etc/soga/dns.yml ]]; then
        cp dns.yml /etc/soga/
    fi
    if [[ ! -f /etc/soga/routes.toml ]]; then
        cp routes.toml /etc/soga/
    fi

    curl -o /usr/bin/soga -Ls "${manager_url}"
    chmod +x /usr/bin/soga

    echo
    echo "soga 管理脚本使用方法:"
    echo "------------------------------------------"
    echo "soga                    - 显示管理菜单 (功能更多)"
    echo "soga start              - 启动 soga"
    echo "soga stop               - 停止 soga"
    echo "soga restart            - 重启 soga"
    echo "soga status             - 查看 soga 状态"
    echo "soga enable             - 设置 soga 开机自启"
    echo "soga disable            - 取消 soga 开机自启"
    echo "soga log                - 查看 soga 日志"
    echo "soga log n              - 查看 soga 最后 n 行日志"
    echo "soga update             - 重新安装固定版本 ${fixed_version}"
    echo "soga config             - 显示配置文件内容"
    echo "soga config xx=xx yy=yy - 自动设置配置文件"
    echo "soga install            - 安装 soga"
    echo "soga uninstall          - 卸载 soga"
    echo "soga version            - 查看 soga 版本"
    echo "------------------------------------------"
}

is_cmd_exist "systemctl"
if [[ $? != 0 ]]; then
    echo "systemctl 命令不存在，请使用较新版本的系统，例如 Ubuntu 18+、Debian 9+"
    exit 1
fi

echo -e "${green}开始安装${plain}"
install_base
install_acme
install_soga "${1:-}"
