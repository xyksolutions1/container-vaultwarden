# SPDX-FileCopyrightText: © 2026 Nfrastack <code@nfrastack.com>
#
# SPDX-License-Identifier: MIT

ARG \
    BASE_IMAGE

FROM docker.io/xyksolutions1/container-base:latest

LABEL \
        org.opencontainers.image.title="Vaultwarden" \
        org.opencontainers.image.description="Containerized password manager" \
        org.opencontainers.image.url="https://hub.docker.com/r/xyksolutions1/vaultwarden" \
        org.opencontainers.image.documentation="https://github.com/xyksolutions1/container-vaultwarden/blob/main/README.md" \
        org.opencontainers.image.source="https://github.com/xyksolutions1/container-vaultwarden.git" \
        org.opencontainers.image.authors="xyksolutions1" \
        org.opencontainers.image.vendor="xyksolutions1" \
        org.opencontainers.image.licenses="MIT"

ARG \
    VAULTWARDEN_VERSION="1.35.7" \
    VAULTWARDEN_REPO_URL="https://github.com/dani-garcia/vaultwarden" \
    VAULTWARDEN_WEBVAULT_VERSION="v2026.2.0+0" \
    VAULTWARDEN_WEBVAULT_REPO_URL="https://github.com/vaultwarden/vw_web_builds"

COPY CHANGELOG.md /usr/src/container/CHANGELOG.md
COPY LICENSE /usr/src/container/LICENSE
COPY README.md /usr/src/container/README.md

ENV \
    IMAGE_NAME="xyksolutions1/vaultwarden" \
    IMAGE_REPO_URL="https://github.com/xyksolutions1/container-vaultwarden/"

COPY build-assets /build-assets

RUN echo "" && \
    BUILD_ENV=" \
                ENABLE_NGINX=FALSE \
                NGINX_SITE_ENABLED=vaultwarden \
                NGINX_CREATE_SAMPLE_HTML=FALSE \
              " \
              && \
    VAULTWARDEN_BUILD_DEPS_ALPINE=" \
                                    build-base \
                                    #cargo \
                                    git \
                                    libpq-dev \
                                    mariadb-connector-c-dev \
                                    openssl-dev \
                                  " \
                                  && \
    VAULTWARDEN_WEBVAULT_BUILD_DEPS_ALPINE=" \
                                               nodejs \
                                               npm \
                                           " \
                                           && \
    VAULTWARDEN_RUN_DEPS_ALPINE=" \
                                    libpq \
                                    mariadb-connector-c \
                                  " \
                                  && \
    \
    source /container/base/functions/container/build && \
    container_build_log image && \
    create_user vaultwarden 1000 vaultwarden 1000 /dev/null && \
    package update && \
    package upgrade && \
    package install \
                        VAULTWARDEN_BUILD_DEPS \
                        VAULTWARDEN_WEBVAULT_BUILD_DEPS \
                        VAULTWARDEN_RUN_DEPS \
                        && \
    \
    ## 2025-11-25 - npm 11.6.3 is broken and need to downgrade
    echo "@321community https://dl-cdn.alpinelinux.org/alpine/v3.21/community/" >> /etc/apk/repositories && \
    package update && \
    package install npm@321community && \
    ## 2026-04-13 - Needs Rust > 1.92
    echo "@edgemain https://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    package update && \
    package install cargo@edgemain && \
    clone_git_repo "${VAULTWARDEN_REPO_URL}" "${VAULTWARDEN_VERSION}" && \
    build_assets /build-assets/vaultwarden/src "${GIT_REPO_VAULTWARDEN}" && \
    build_assets scripts /build-assets/vaultwarden/scripts && \
    touch \
            build.rs \
            src/main.rs \
            && \
    cargo build \
                --features "mysql,postgresql,sqlite,enable_mimalloc" \
                --profile "release" \
                && \
    mkdir -p /app && \
    cp -aR /usr/src/vaultwarden/target/release/vaultwarden /app && \
    mkdir -p /container/data/vaultwarden/ && \
    cp -aR .env.template /container/data/vaultwarden/env.options && \
    container_build_log add "Vaultwarden" "${VAULTWARDEN_VERSION}" "${VAULTWARDEN_REPO_URL}" && \
    \
    git clone "${VAULTWARDEN_WEBVAULT_REPO_URL}" /usr/src/vaultwarden_webvault && \
    cd /usr/src/vaultwarden_webvault && \
    git checkout "${VAULTWARDEN_WEBVAULT_VERSION}" && \
    export GIT_REPO_VAULTWARDEN_WEBVAULT="/usr/src/vaultwarden_webvault" && \
    #clone_git_repo "${VAULTWARDEN_WEBVAULT_REPO_URL}" "${VAULTWARDEN_WEBVAULT_VERSION}" /usr/src/vaultwarden_webvault && \
    \
    build_assets /build-assets/vaultwarden_webvault/src "${GIT_REPO_VAULTWARDEN_WEBVAULT}" && \
    build_assets scripts /build-assets/vaultwarden_webvault/scripts && \
    npm ci && \
    cd /usr/src/vaultwarden_webvault/apps/web && \
    npm run dist:oss:selfhost && \
    cp -aR /usr/src/vaultwarden_webvault/apps/web/build /app/web-vault && \
    container_build_log add "Vaultwarden Web Vault" "${VAULTWARDEN_WEBVAULT_VERSION}" "${VAULTWARDEN_WEBVAULT_REPO_URL}" && \
    \
    package remove \
                    VAULTWARDEN_BUILD_DEPS \
                    VAULTWARDEN_WEBVAULT_BUILD_DEPS \
                    cargo \
                    && \
    package cleanup && \
    rm -rf \
            /root/.cargo

COPY rootfs /
