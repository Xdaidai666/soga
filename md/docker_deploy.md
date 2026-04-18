# Soga Docker 镜像部署说明

## 适用环境
- 仅支持 `Linux amd64`
- 固定版本 `soga 2.13.7`
- 需要已安装 `Docker Engine` 和 `docker compose`
- 当前 `docker-compose.yml` 使用 `host` 网络模式，因此仅适合 Linux 服务器

## 文件位置
- [docker-compose.yml](C:/Users/16570/Desktop/soga/docker/docker-compose.yml)
- [docker-install.sh](C:/Users/16570/Desktop/soga/docker-install.sh)

## 一键拉取 Docker 镜像部署目录
服务器可直接执行：

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

## 自定义镜像地址
默认镜像名是：

```text
ghcr.io/xdaidai666/soga:2.13.7
```

如果你换了镜像地址，可以这样指定：

```bash
SOGA_DOCKER_IMAGE=你的镜像地址 bash <(curl -Ls https://raw.githubusercontent.com/Xdaidai666/soga/main/docker-install.sh)
```

## 部署方式
编辑配置文件：

```bash
nano /opt/soga-docker/data/soga.conf
```

进入部署目录后执行：

```bash
cd /opt/soga-docker/docker
docker compose pull
docker compose up -d
```

## 配置文件
容器内配置目录固定映射为：

```text
/etc/soga
```

宿主机对应目录：

```text
/opt/soga-docker/data
```

会自动准备这些文件：
- `soga.conf`
- `blockList`
- `whiteList`
- `dns.yml`
- `routes.toml`

## 常用命令
查看日志：

```bash
cd /opt/soga-docker/docker
docker compose logs -f soga
```

停止：

```bash
cd /opt/soga-docker/docker
docker compose down
```

重启：

```bash
cd /opt/soga-docker/docker
docker compose restart
```

## 说明
- 这套 Docker 方案不会自动下发证书
- 如果你的 `soga.conf` 需要证书，请自行把证书文件放到 `/opt/soga-docker/data` 中，并在配置里填写对应路径
- 这套方案是“拉镜像运行”，不再需要用户本地 `docker build`
