# Soga Docker 部署说明

## 适用环境
- 仅支持 `Linux amd64`
- 固定版本 `soga 2.13.7`
- 需要已安装 `Docker Engine` 和 `docker compose`
- 当前 `docker-compose.yml` 使用 `host` 网络模式，因此仅适合 Linux 服务器

## 文件位置
- [Dockerfile](C:/Users/16570/Desktop/soga/docker/Dockerfile)
- [entrypoint.sh](C:/Users/16570/Desktop/soga/docker/entrypoint.sh)
- [docker-compose.yml](C:/Users/16570/Desktop/soga/docker/docker-compose.yml)

## 一键拉取 Docker 部署目录
如果不想手动上传 `docker/` 目录，可以直接在服务器执行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Xdaidai666/soga/main/docker-install.sh)
```

默认会把 Docker 部署目录准备到：

```text
/opt/soga-docker
```

并自动生成：
- `/opt/soga-docker/docker`
- `/opt/soga-docker/data`

其中 `data/soga.conf` 会自动从安装包解出默认模板，等你自己填写。

## 部署方式
如果你是手动上传了 `docker/` 目录，进入 `docker` 目录后执行：

```bash
docker compose up -d --build
```

首次启动时，如果 `./data/soga.conf` 不存在，容器会自动复制默认模板到：

```text
./data/soga.conf
```

然后容器会退出，并提示你先填写配置。

## 配置文件
容器内配置目录固定映射为：

```text
/etc/soga
```

宿主机对应目录：

```text
./data
```

会自动准备这些文件：
- `soga.conf`
- `blockList`
- `whiteList`
- `dns.yml`
- `routes.toml`

## 启动命令
配置完成后重新启动：

```bash
docker compose up -d
```

查看日志：

```bash
docker compose logs -f soga
```

停止：

```bash
docker compose down
```

## 说明
- 这套 Docker 方案不会自动下发证书
- 如果你的 `soga.conf` 需要证书，请自行把证书文件放到 `./data` 中，并在配置里填写对应路径
- 当前镜像会从 GitHub Raw 下载固定安装包：
  - `https://raw.githubusercontent.com/Xdaidai666/soga/main/soga-2.13.7-linux-amd64.tar.gz`
