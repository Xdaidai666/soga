#!/bin/bash

set -e

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

install_dir="${SOGA_DOCKER_INSTALL_DIR:-/opt/soga-docker}"
compose_dir="${install_dir}/docker"
config_file="${install_dir}/data/soga.conf"
image_name="${SOGA_DOCKER_IMAGE:-ghcr.io/xdaidai666/soga:2.13.7}"

declare -a config_overrides=()
command_name=""
log_lines="100"

show_help() {
    cat <<EOF
soga-docker manager

usage:
  soga-docker start
  soga-docker stop
  soga-docker restart
  soga-docker status
  soga-docker log [lines]
  soga-docker config
  soga-docker --set key=value [--set key=value ...]

examples:
  soga-docker --set type=v2board --set server_type=v2ray --set node_id=1
  soga-docker --set soga_key=your_key --set api=webapi --set webapi_url=https://www.example.com/
  soga-docker start
  soga-docker log 200
EOF
}

require_installation() {
    if [[ ! -f "${compose_dir}/docker-compose.yml" || ! -f "${config_file}" ]]; then
        echo -e "${red}未检测到 Docker 部署目录，请先运行安装脚本${plain}"
        exit 1
    fi
}

require_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${red}未检测到 docker，请先安装 Docker Engine${plain}"
        exit 1
    fi

    if ! docker compose version >/dev/null 2>&1; then
        echo -e "${red}未检测到 docker compose，请先安装 Docker Compose 插件${plain}"
        exit 1
    fi
}

run_compose() {
    (
        cd "${compose_dir}"
        SOGA_DOCKER_IMAGE="${image_name}" docker compose "$@"
    )
}

escape_sed_replacement() {
    printf '%s' "$1" | sed -e 's/[&~]/\\&/g'
}

set_config_value() {
    local key="$1"
    local value="$2"
    local escaped_value

    escaped_value="$(escape_sed_replacement "${value}")"

    if [[ ! -w "${config_file}" ]]; then
        echo -e "${red}配置文件不可写，请使用 root 或 sudo 运行${plain}"
        exit 1
    fi

    if grep -q "^${key}=" "${config_file}"; then
        sed -i "s~^${key}=.*~${key}=${escaped_value}~" "${config_file}"
    else
        printf '\n%s=%s\n' "${key}" "${value}" >> "${config_file}"
    fi
}

read_config_value() {
    local key="$1"
    local value
    value="$(sed -n "s/^${key}=//p" "${config_file}" | head -n 1 | tr -d '\r')"
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

apply_overrides_and_start() {
    local pair key value

    for pair in "${config_overrides[@]}"; do
        [[ "${pair}" == *=* ]] || { echo -e "${red}非法配置参数 ${pair}，必须使用 key=value${plain}"; exit 1; }
        key="${pair%%=*}"
        value="${pair#*=}"
        [[ -n "${key}" ]] || { echo -e "${red}非法配置参数 ${pair}${plain}"; exit 1; }
        set_config_value "${key}" "${value}"
    done

    echo -e "${green}配置已写入：${config_file}${plain}"

    if config_is_ready; then
        echo -e "${yellow}配置完整，开始拉取镜像并启动容器...${plain}"
        run_compose pull
        run_compose up -d
        echo -e "${green}Docker 容器已启动${plain}"
    else
        echo -e "${yellow}配置尚未完整，当前不会自动启动。${plain}"
        echo "可继续执行更多 --set 参数，或手动编辑：${config_file}"
    fi
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
        start|stop|restart|status|config)
            [[ -z "${command_name}" ]] || { echo -e "${red}错误：${plain} 只能指定一个命令"; exit 1; }
            command_name="$1"
            shift
            ;;
        log)
            [[ -z "${command_name}" ]] || { echo -e "${red}错误：${plain} 只能指定一个命令"; exit 1; }
            command_name="log"
            shift
            if [[ $# -gt 0 && "$1" != --* ]]; then
                log_lines="$1"
                shift
            fi
            ;;
        *)
            echo -e "${red}错误：${plain} 不支持的参数 $1"
            echo
            show_help
            exit 1
            ;;
    esac
done

require_installation
require_docker

if [[ ${#config_overrides[@]} -gt 0 ]]; then
    apply_overrides_and_start
    exit 0
fi

case "${command_name}" in
    start)
        if ! config_is_ready; then
            echo -e "${red}配置尚未填写完整，请先使用 soga-docker --set ... 或编辑 ${config_file}${plain}"
            exit 1
        fi
        run_compose pull
        run_compose up -d
        ;;
    stop)
        run_compose down
        ;;
    restart)
        if ! config_is_ready; then
            echo -e "${red}配置尚未填写完整，请先使用 soga-docker --set ... 或编辑 ${config_file}${plain}"
            exit 1
        fi
        run_compose pull
        run_compose up -d
        ;;
    status)
        run_compose ps
        ;;
    config)
        cat "${config_file}"
        ;;
    log)
        run_compose logs -f --tail "${log_lines}" soga
        ;;
    "")
        show_help
        ;;
esac
