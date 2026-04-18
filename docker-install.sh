#!/bin/bash

set -e

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

fixed_version="2.13.7"
base_url="${SOGA_DOCKER_BASE_URL:-https://raw.githubusercontent.com/Xdaidai666/soga/main}"
docker_base_url="${base_url}/docker"
package_url="${base_url}/soga-2.13.7-linux-amd64.tar.gz"
package_sha256="d8466d6cf8c075857d2ff7480e4a9092bedd1b7d7ba3d77886fdc375bbc6e4a0"
install_dir="${SOGA_DOCKER_INSTALL_DIR:-/opt/soga-docker}"
image_name="${SOGA_DOCKER_IMAGE:-ghcr.io/xdaidai666/soga:2.13.7}"

[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用 root 用户运行此脚本！\n" && exit 1

arch="$(uname -m)"
if [[ "${arch}" != "x86_64" && "${arch}" != "amd64" ]]; then
    echo -e "${red}仅支持 Linux amd64，当前架构：${arch}${plain}"
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo -e "${red}未检测到 docker，请先安装 Docker Engine${plain}"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo -e "${red}未检测到 docker compose，请先安装 Docker Compose 插件${plain}"
    exit 1
fi

mkdir -p "${install_dir}/docker" "${install_dir}/data"

download_file() {
    local url="$1"
    local output="$2"
    echo -e "下载: ${yellow}${url}${plain}"
    curl -LfsS "${url}" -o "${output}"
}

download_file "${docker_base_url}/docker-compose.yml" "${install_dir}/docker/docker-compose.yml"

tmp_tar="$(mktemp)"
download_file "${package_url}" "${tmp_tar}"

if command -v sha256sum >/dev/null 2>&1; then
    actual_sha256="$(sha256sum "${tmp_tar}" | awk '{print $1}')"
    if [[ "${actual_sha256}" != "${package_sha256}" ]]; then
        echo -e "${red}安装包校验失败${plain}"
        echo "期望: ${package_sha256}"
        echo "实际: ${actual_sha256}"
        rm -f "${tmp_tar}"
        exit 1
    fi
fi

extract_if_missing() {
    local src="$1"
    local dst="$2"
    if [[ ! -f "${dst}" ]]; then
        tar -xOzf "${tmp_tar}" "${src}" > "${dst}"
    fi
}

extract_if_missing "soga/soga.conf" "${install_dir}/data/soga.conf"
extract_if_missing "soga/blockList" "${install_dir}/data/blockList"
extract_if_missing "soga/whiteList" "${install_dir}/data/whiteList"
extract_if_missing "soga/dns.yml" "${install_dir}/data/dns.yml"
extract_if_missing "soga/routes.toml" "${install_dir}/data/routes.toml"

rm -f "${tmp_tar}"

echo
echo -e "${green}Docker 镜像部署目录已准备完成${plain}"
echo "目录: ${install_dir}"
echo "镜像: ${image_name}"
echo
echo "请先编辑配置文件："
echo "  ${install_dir}/data/soga.conf"
echo
echo "拉取镜像并启动："
echo "  cd ${install_dir}/docker && SOGA_DOCKER_IMAGE=${image_name} docker compose pull && SOGA_DOCKER_IMAGE=${image_name} docker compose up -d"
echo
echo "查看日志："
echo "  cd ${install_dir}/docker && docker compose logs -f soga"
