FROM debian:12-slim

ARG SOGA_VERSION=2.13.7
ARG SOGA_PACKAGE_URL=https://raw.githubusercontent.com/Xdaidai666/soga/main/soga-2.13.7-linux-amd64.tar.gz
ARG SOGA_PACKAGE_SHA256=d8466d6cf8c075857d2ff7480e4a9092bedd1b7d7ba3d77886fdc375bbc6e4a0

ENV TZ=Asia/Shanghai

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tar tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN curl -L "${SOGA_PACKAGE_URL}" -o soga.tar.gz \
    && echo "${SOGA_PACKAGE_SHA256}  soga.tar.gz" | sha256sum -c - \
    && tar -xzf soga.tar.gz -C /usr/local/ \
    && rm -f soga.tar.gz \
    && chmod +x /usr/local/soga/soga

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

VOLUME ["/etc/soga"]

EXPOSE 443/tcp

ENTRYPOINT ["/entrypoint.sh"]
