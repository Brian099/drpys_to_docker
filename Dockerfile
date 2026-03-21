# 构建器阶段
# 使用node:20-alpine(17 < version < 23)作为基础镜像
FROM node:20-alpine AS builder

RUN apk add --no-cache git python3 build-base linux-headers
ENV PYTHON=/usr/bin/python3
ENV PUPPETEER_SKIP_DOWNLOAD=true

# 如果您需要配置git以使用特定的HTTP版本，请确保这是出于必要和安全考虑
RUN git config --global http.version HTTP/1.1

# 创建一个工作目录
WORKDIR /app

# 克隆GitHub仓库到工作目录
RUN git clone https://github.com/hjdhnx/drpy-node.git .

# 安装项目依赖项和puppeteer
RUN rm -f package-lock.json && yarn && yarn add puppeteer

# 复制工作目录中的所有文件到一个临时目录中
# 以便在运行器阶段中使用
RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/


# 运行器阶段
# 使用alpine:latest作为基础镜像来创建一个更小的镜像
# 但是无法用pm2
FROM node:20-alpine AS runner
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# 创建一个工作目录
WORKDIR /app

# 复制构建器阶段中准备好的文件和依赖项到运行器阶段的工作目录中
COPY --from=builder /tmp/drpys/. /app
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

RUN apk add --no-cache chromium nss freetype harfbuzz ca-certificates ttf-freefont && \
    if [ ! -e /usr/bin/chromium-browser ] && [ -e /usr/bin/chromium ]; then ln -s /usr/bin/chromium /usr/bin/chromium-browser; fi

# 安装php8.3及其扩展
RUN apk add --no-cache \
    php83 \
    php83-cli \
    php83-curl \
    php83-mbstring \
    php83-xml \
    php83-pdo \
    php83-pdo_mysql \
    php83-pdo_sqlite \
    php83-openssl \
    php83-sqlite3 \
    php83-json
RUN ln -sf /usr/bin/php83 /usr/bin/php

# 安装python3依赖
RUN apk add --no-cache python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel

# 激活python3虚拟环境并安装requirements依赖
RUN python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip3 install -r /app/spider/py/base/requirements.txt

# 暴露应用程序端口（根据您的项目需求调整）
EXPOSE 5757

# 指定容器启动时执行的命令
CMD ["node", "index.js"]
