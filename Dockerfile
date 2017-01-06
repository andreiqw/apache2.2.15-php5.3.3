FROM andreiqw/apache2.2.15

ENV 	PHP_VERSION=5.3.3 \
	PHP_INI_DIR=/etc/php

# Install PHP
RUN set -x \
# For redirecting sendmail during development
        && apk add --no-cache ssmtp \
# PHP Runtime deps
	&& apk add --no-cache --virtual .persistent-deps \
                curl \
                tar \
                xz \
# PHP Build deps
	&& apk add --no-cache --virtual .build-deps \
		apache2-dev \
                autoconf \
                file \
                g++ \
                gcc \
                libc-dev \
                make \
                pkgconf \
                re2c \
		readline-dev \
		libxslt-dev \
		mysql-dev \
		libmcrypt-dev \
		gmp-dev \
		gettext-dev \
		libpng-dev \
		bzip2-dev \
		curl-dev \
		libedit-dev \
		libxml2-dev \
		openssl-dev \
		sqlite-dev \
	\
# Download & Install the kit
        && mkdir -p /usr/src \
	&& cd /usr/src \
        && wget -q "http://museum.php.net/php5/php-${PHP_VERSION}.tar.gz" \
        && tar -zxvf "php-${PHP_VERSION}.tar.gz" \
# Download and apply the backward compatibility patch
	&& cd "/usr/src/php-${PHP_VERSION}/ext" \
        && wget -q http://storage.googleapis.com/google-code-attachments/php52-backports/issue-16/comment-2/libxml29_compat.patch \
        && patch -p1 < libxml29_compat.patch \
        && rm libxml29_compat.patch \
# Make it
        && cd "/usr/src/php-${PHP_VERSION}" \
        && ./configure \
                --with-apxs2 \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		--disable-posix \
		--without-sqlite \
		--with-bz2 \
		--enable-calendar \
		--with-curl \
		--enable-exif \
		--enable-ftp \
		--with-gd \
		--with-gettext \
		--with-gmp \
		--with-mcrypt \
		--with-mysql \
		--with-mysqli \
		--with-openssl \
		--enable-pcntl \
		--with-pdo-mysql \
		--with-readline \
		--enable-shmop \
		--enable-sockets \
		--enable-wddx \
		--with-xsl \
		--enable-zip \		
		--with-zlib \
	&& make -j "$(getconf _NPROCESSORS_ONLN)" \
	&& make install \
	&& { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
	&& make clean \
# Cleanup files
	&& rm -fr "/usr/src/php-${PHP_VERSION}" \
	&& rm -fr "/usr/src/php-${PHP_VERSION}.tar.gz" \
# Compute final runtime dependencies list
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --no-cache --virtual .php-rundeps $runDeps \
# Install xdebug	
	&& pecl install xdebug-2.2.7 \
# Make apache include custom conf dirs (will add php.conf here)
	&& echo "Include conf/conf.d/*.conf" | tee -a "${HTTPD_PREFIX}/conf/httpd.conf" \
# Uinstall build deps - only at the end as they are needed for xdebug install too
	&& apk del .build-deps \
# Create sessions dir - 777 should be fine in the container
	&& mkdir -p /var/lib/php/session \
        && chmod 777 /var/lib/php/session

ADD     docker/docker-php-* /usr/local/bin/
ADD     php.conf "${HTTPD_PREFIX}/conf/conf.d/php.conf"
ADD	php.ini "${PHP_INI_DIR}/php.ini"
ADD	xdebug.ini "$PHP_INI_DIR/conf.d/xdebug.ini"
