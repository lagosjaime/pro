FROM php:8.4-fpm-alpine

ARG UID=1000
ARG GID=1000
ARG MSODBCSQL_VERSION=18.7.1.1
ARG PDO_SQLSRV_VERSION=5.13.3

RUN apk add --no-cache \
        git \
        unzip \
        icu-libs \
        oniguruma \
        libzip \
        libpng \
        libjpeg-turbo \
        freetype \
    && apk add --no-cache --virtual .build-deps \
        icu-dev \
        oniguruma-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        $PHPIZE_DEPS \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        gd \
        intl \
        mbstring \
        mysqli \
        pdo_mysql \
        zip \
    && yes '' | pecl install redis \
    && docker-php-ext-enable redis \
    && apk del --no-network .build-deps \
    && php -r 'exit(extension_loaded("curl") ? 0 : 1);'

RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) odbc_arch="amd64" ;; \
        aarch64) odbc_arch="arm64" ;; \
        *) echo "Arquitectura no soportada para msodbcsql18: $arch" >&2; exit 1 ;; \
    esac; \
    apk add --no-cache --virtual .mssql-build-deps \
        unixodbc-dev \
        $PHPIZE_DEPS \
    && wget -q -O /tmp/msodbcsql18.apk \
        "https://download.microsoft.com/download/ade174b7-8cea-4543-91a6-c33ae320c2f0/msodbcsql18_${MSODBCSQL_VERSION}-1_${odbc_arch}.apk" \
    && apk add --no-cache --allow-untrusted /tmp/msodbcsql18.apk \
    && rm -f /tmp/msodbcsql18.apk \
    && MAKEFLAGS="-j2" pecl install "pdo_sqlsrv-${PDO_SQLSRV_VERSION}" \
    && docker-php-ext-enable pdo_sqlsrv \
    && apk del --no-network .mssql-build-deps

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN mkdir -p /home/app/.composer \
    && chown -R ${UID}:${GID} /home/app

ENV HOME=/home/app \
    COMPOSER_HOME=/home/app/.composer \
    COMPOSER_CACHE_DIR=/home/app/.composer/cache

WORKDIR /var/www/html

EXPOSE 9000
