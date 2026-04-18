#!/bin/sh
set -eu

CONFIG_DIR="/etc/soga"
APP_DIR="/usr/local/soga"

mkdir -p "${CONFIG_DIR}"

copy_if_missing() {
    src="$1"
    dst="$2"
    if [ ! -f "${dst}" ] && [ -f "${src}" ]; then
        cp -f "${src}" "${dst}"
    fi
}

copy_if_missing "${APP_DIR}/blockList" "${CONFIG_DIR}/blockList"
copy_if_missing "${APP_DIR}/whiteList" "${CONFIG_DIR}/whiteList"
copy_if_missing "${APP_DIR}/dns.yml" "${CONFIG_DIR}/dns.yml"
copy_if_missing "${APP_DIR}/routes.toml" "${CONFIG_DIR}/routes.toml"

if [ ! -f "${CONFIG_DIR}/soga.conf" ]; then
    cp -f "${APP_DIR}/soga.conf" "${CONFIG_DIR}/soga.conf"
    echo "已生成默认配置文件: ${CONFIG_DIR}/soga.conf"
    echo "请先编辑配置文件，再重新启动容器。"
    exit 1
fi

exec "${APP_DIR}/soga" \
    -c "${CONFIG_DIR}/soga.conf" \
    -b "${CONFIG_DIR}/blockList" \
    -d "${CONFIG_DIR}/dns.yml" \
    -r "${CONFIG_DIR}/routes.toml" \
    -w "${CONFIG_DIR}/whiteList"
