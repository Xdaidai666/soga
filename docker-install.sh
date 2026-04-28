#!/bin/bash

set -e

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

fixed_version="2.13.7"
base_url="${SOGA_DOCKER_BASE_URL:-https://raw.githubusercontent.com/Xdaidai666/soga/main}"
docker_base_url="${base_url}/docker"
install_dir="${SOGA_DOCKER_INSTALL_DIR:-/opt/soga-docker}"
image_name="${SOGA_DOCKER_IMAGE:-ghcr.io/xdaidai666/soga:2.13.7}"
config_file_rel="data/soga.conf"
docker_manager_url="${base_url}/soga-docker.sh"
docker_manager_path="/usr/bin/soga-docker"

declare -a config_overrides=()

show_help() {
    cat <<EOF
soga docker installer
supported environment: Linux amd64 only
fixed version: ${fixed_version}

usage:
  bash docker-install.sh
  bash docker-install.sh --set key=value [--set key=value ...]

examples:
  bash docker-install.sh \\
    --set type=v2board \\
    --set server_type=v2ray \\
    --set node_id=1 \\
    --set soga_key=your_soga_key \\
    --set api=webapi \\
    --set webapi_url=https://www.example.com/ \\
    --set webapi_key=your_webapi_key \\
    --set cert_file=/etc/soga/fullchain.pem \\
    --set key_file=/etc/soga/privkey.pem

optional env overrides:
  SOGA_DOCKER_IMAGE
  SOGA_DOCKER_INSTALL_DIR
  SOGA_DOCKER_BASE_URL

config override env format:
  SOGA_CFG_TYPE=v2board
  SOGA_CFG_SERVER_TYPE=v2ray
  SOGA_CFG_NODE_ID=1
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --set)
            [[ $# -ge 2 ]] || { echo -e "${red}错误：${plain} --set 需要 key=value 参数"; exit 1; }
            config_overrides+=("$2")
            shift 2
            ;;
        --set=*)
            config_overrides+=("${1#--set=}")
            shift
            ;;
        *)
            echo -e "${red}错误：${plain} 不支持的参数 $1"
            echo
            show_help
            exit 1
            ;;
    esac
done

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

    curl \
        --fail \
        --location \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        --silent \
        --show-error \
        "${url}" \
        -o "${output}"
}

download_file "${docker_base_url}/docker-compose.yml" "${install_dir}/docker/docker-compose.yml"
download_file "${docker_manager_url}" "${docker_manager_path}"
chmod +x "${docker_manager_path}"

write_if_missing() {
    local dst="$2"
    if [[ ! -f "${dst}" ]]; then
        cat > "${dst}"
    fi
}

write_if_missing ignored "${install_dir}/data/soga.conf" <<'EOF'
# 基础配置
type=
server_type=
node_id=
soga_key=

# webapi 或 db 对接任选一个
api=

# webapi 对接信息
webapi_url=
webapi_key=

# db 对接信息
db_host=
db_port=
db_name=
db_user=
db_password=

# 手动证书配置
cert_file=
key_file=

# 自动证书配置
cert_mode=
cert_domain=
cert_key_length=ec-256
dns_provider=

# proxy protocol 中转配置
proxy_protocol=false
udp_proxy_protocol=false

# 全局限制用户 IP 数配置
redis_enable=
redis_addr=
redis_password=
redis_db=
conn_limit_expiry=

# 动态限速配置
dy_limit_enable=
dy_limit_duration=
dy_limit_trigger_time=
dy_limit_trigger_speed=
dy_limit_speed=
dy_limit_time=
dy_limit_white_user_id=

# 其它杂项
user_conn_limit=
user_speed_limit=
user_tcp_limit=
node_speed_limit=

check_interval=
submit_interval=
forbidden_bit_torrent=
log_level=

# 更多配置项请看文档根据需求自行添加
EOF

write_if_missing ignored "${install_dir}/data/blockList" <<'EOF'
# 每行一个审计规则
EOF

write_if_missing ignored "${install_dir}/data/whiteList" <<'EOF'
# 每行一个规则
EOF

write_if_missing ignored "${install_dir}/data/dns.yml" <<'EOF'
# dns配置
EOF

write_if_missing ignored "${install_dir}/data/routes.toml" <<'EOF'
# 出站路由配置，默认本机出站，无需配置
EOF

collect_env_config_overrides() {
    local var_name key value
    while IFS= read -r var_name; do
        key="$(printf '%s' "${var_name#SOGA_CFG_}" | tr 'A-Z' 'a-z')"
        value="${!var_name}"
        config_overrides+=("${key}=${value}")
    done < <(compgen -A variable SOGA_CFG_ | sort)
}

escape_sed_replacement() {
    printf '%s' "$1" | sed -e 's/[&~]/\\&/g'
}

set_config_value() {
    local key="$1"
    local value="$2"
    local escaped_value
    escaped_value="$(escape_sed_replacement "${value}")"

    if grep -q "^${key}=" "${install_dir}/${config_file_rel}"; then
        sed -i "s~^${key}=.*~${key}=${escaped_value}~" "${install_dir}/${config_file_rel}"
    else
        printf '\n%s=%s\n' "${key}" "${value}" >> "${install_dir}/${config_file_rel}"
    fi
}

apply_config_overrides() {
    local pair key value
    collect_env_config_overrides

    for pair in "${config_overrides[@]}"; do
        [[ "${pair}" == *=* ]] || { echo -e "${red}错误：${plain} 非法配置参数 ${pair}，必须使用 key=value"; exit 1; }
        key="${pair%%=*}"
        value="${pair#*=}"
        [[ -n "${key}" ]] || { echo -e "${red}错误：${plain} 非法配置参数 ${pair}"; exit 1; }
        set_config_value "${key}" "${value}"
    done
}

apply_config_overrides

read_config_value() {
    local key="$1"
    local value
    value="$(sed -n "s/^${key}=//p" "${install_dir}/${config_file_rel}" | head -n 1 | tr -d '\r')"
    printf '%s' "${value}"
}

config_is_ready() {
    local type_value server_type_value node_id_value soga_key_value api_value

    type_value="$(read_config_value "type")"
    server_type_value="$(read_config_value "server_type")"
    node_id_value="$(read_config_value "node_id")"
    soga_key_value="$(read_config_value "soga_key")"
    api_value="$(read_config_value "api")"

    [[ -n "${type_value}" ]] || return 1
    [[ -n "${server_type_value}" ]] || return 1
    [[ -n "${node_id_value}" ]] || return 1
    [[ -n "${soga_key_value}" ]] || return 1
    [[ -n "${api_value}" ]] || return 1

    if [[ "${api_value}" == "webapi" ]]; then
        [[ -n "$(read_config_value "webapi_url")" ]] || return 1
        [[ -n "$(read_config_value "webapi_key")" ]] || return 1
    elif [[ "${api_value}" == "db" ]]; then
        [[ -n "$(read_config_value "db_host")" ]] || return 1
        [[ -n "$(read_config_value "db_port")" ]] || return 1
        [[ -n "$(read_config_value "db_name")" ]] || return 1
        [[ -n "$(read_config_value "db_user")" ]] || return 1
        [[ -n "$(read_config_value "db_password")" ]] || return 1
    else
        return 1
    fi

    return 0
}

start_container_stack() {
    echo
    echo -e "${yellow}检测到配置已填写，开始自动拉取并启动 Docker 容器...${plain}"
    (
        cd "${install_dir}/docker"
        SOGA_DOCKER_IMAGE="${image_name}" docker compose pull
        SOGA_DOCKER_IMAGE="${image_name}" docker compose up -d
    )
}

echo
echo -e "${green}Docker 镜像部署目录已准备完成${plain}"
echo "目录: ${install_dir}"
echo "镜像: ${image_name}"
echo "管理命令: soga-docker"
echo
if config_is_ready; then
    start_container_stack
    echo
    echo -e "${green}Docker 容器已启动${plain}"
    echo
    echo "查看日志："
    echo "  soga-docker log"
else
    echo "请先编辑配置文件："
    echo "  ${install_dir}/${config_file_rel}"
    echo
    echo "或者重新运行并带上命令行参数，例如："
    echo "  bash docker-install.sh --set type=v2board --set server_type=v2ray --set node_id=1 --set soga_key=your_key ..."
    echo
    echo "安装完成后，也可以直接用命令管理："
    echo "  soga-docker --set type=v2board --set server_type=v2ray --set node_id=1 --set soga_key=your_key ..."
    echo
    echo "配置填好后执行："
    echo "  soga-docker start"
    echo
    echo "查看日志："
    echo "  soga-docker log"
fi
