# FROM alpine:edge
FROM alpine:3.5
MAINTAINER jgilley@chegg.com

# set our environment
ENV APP_ENV='DEVELOPMENT'
# ENV APP_ENV='PRODUCTION'
ENV php_ini_dir /etc/php7/conf.d
ENV tideways_ext_version 4.0.7
ENV tideways_php_version 2.0.14
ENV tideways_dl https://github.com/tideways/

ENV PHP_OC_ENABLE 0
ENV PHP_OC_ENABLE_CLI 0
ENV PHP_OC_VALIDATE_TIMESTAMPS 1
ENV PHP_OC_MEMORY_CONSUMPTION 64

# if edge libraries are needed use the following:
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# install base packages - BASH should only be used for debugging, it's almost a meg in size
# install ca-certificates
# clean up the apk cache (no-cache still caches the indexes)
# update the ca-certificates
RUN	apk --update \
	add bash ca-certificates supervisor && \
	update-ca-certificates

RUN	apk add \
	--virtual .build_package \
		git curl file build-base autoconf

RUN apk add \
	--virtual .build_libraries \
		pcre-dev \
		cyrus-sasl-dev \
		libmemcached-dev \
		hiredis-dev \
		zlib-dev \
		php7-dev

RUN apk add \
	--virtual .php_service \
		mysql-client \
		php7 \
		php7-bcmath \
		php7-bz2 \
		php7-ctype \
		php7-curl \
		php7-dom \
		php7-fpm \
		php7-gd \
		php7-gettext \
		php7-gmp \
		php7-intl \
		php7-iconv \
		php7-json \
		php7-mbstring \
		php7-mcrypt \
		php7-mysqli \
		php7-openssl \
		php7-opcache \
		php7-pdo \
		php7-pdo_dblib \
		php7-pdo_mysql \
		php7-pdo_pgsql \
		php7-pdo_sqlite \
		php7-phar \
		php7-soap \
		php7-session \
		php7-sqlite3 \
		php7-tidy \
		php7-xmlreader \
		php7-xmlrpc \
		php7-zip

RUN	apk add \
	--virtual .redis_tools hiredis hiredis-dev

# Add the container config files
COPY container_confs /

# create the supervisor run dir
# make sure that entrypoint and other scripts are executeable
RUN mkdir -p /run/supervisord && \
	mv /etc/profile.d/color_prompt /etc/profile.d/color_prompt.sh && \
	chmod +x /entrypoint.sh /wait-for-it.sh /etc/profile /etc/profile.d/*.sh

# Add the www-data user and group, fail on error
RUN set -x ; \
	addgroup -g 82 -S www-data ; \
	adduser -u 82 -D -S -G www-data www-data && exit 0 ; exit 1

# Configure PHP
# dont display errors 	sed -i -e 's/display_errors = Off/display_errors = On/g' /etc/php7/php.ini && \
# fix path off
# error log becomes stderr
# Enable php-fpm on nginx virtualhost configuration
RUN	sed -i -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php7/php.ini && \
	sed -i -e 's/;error_log = php_errors.log/error_log = \/proc\/self\/fd\/1/g' /etc/php7/php.ini

# Add the process control dirs for php
# make it user/group read write
RUN mkdir -p /run/php && \
	chown -R www-data:www-data /run/php

RUN ln -s /usr/bin/php-config7 /usr/bin/php-config && \
	ln -s /usr/bin/php-fpm7  /usr/bin/php-fpm && \
	ln -s /usr/bin/php7  /usr/bin/php && \
	ln -s /usr/bin/phpize7 /usr/bin/phpize

#
# BUILD PHP Extensions that are missing or out of date in alpine edge
#

# Build & install ext/tideways & Tideways.php (props to till)
RUN cd /tmp && \
	curl -L "${tideways_dl}/php-profiler-extension/archive/v${tideways_ext_version}.zip" \
	--output "/tmp/v${tideways_ext_version}.zip" && \
	cd /tmp && unzip "v${tideways_ext_version}.zip" && \
	cd "php-profiler-extension-${tideways_ext_version}" && \
	phpize && \
	./configure && \
	make && make install && \
	echo 'extension=tideways.so' > "${php_ini_dir}/22_tideways.ini" && \
	curl -L "${tideways_dl}/profiler/releases/download/v${tideways_php_version}/Tideways.php" \
	--output "$(php-config --extension-dir)/Tideways.php" && \
	ls -l "$(php-config --extension-dir)/Tideways.php"

# Build & install php7_apcu (Alpine PHP7_apcu is built to out of date php7 backend)
RUN cd /tmp && \
	curl -fsSL 'http://pecl.php.net/get/apcu-5.1.8.tgz' \
	--output /tmp/apcu.tgz && \
	tar -zxvf apcu.tgz && \
	cd /tmp/apcu-5.1.8 && \
	phpize && \
	./configure --enable-memcache && \
	make && make install && \
	echo 'extension=apcu.so' > "${php_ini_dir}/35_apcu.ini"

# Build & install php7_apcu_BC (Alpine PHP7_apcu_BC DOES NOT EXIST)
RUN cd /tmp && \
	curl -fsSL 'http://pecl.php.net/get/apcu_bc-1.0.3.tgz' \
	--output /tmp/apcu_bc.tgz && \
	tar -zxvf apcu_bc.tgz && \
	cd /tmp/apcu_bc-1.0.3 && \
	phpize && \
	./configure && \
	make && make install && \
	echo 'extension=apc.so' > "${php_ini_dir}/45_apc_bc.ini"

# Build & install php_redis (Alpine PHP7_redis is built to out of date php7 backend)
RUN cd /tmp && \
	git clone https://github.com/nrk/phpiredis.git phpiredis && \
	cd phpiredis && \
	phpize && \
	./configure && \
	make && make install && \
	echo 'extension=phpiredis.so' > "${php_ini_dir}/33-phpiredis.ini"

# Build & install php7_memcached (Alpine Package is built from old source)
RUN cd /tmp && \
	curl -fsSL 'http://pecl.php.net/get/memcached-3.0.3.tgz' \
	--output /tmp/memcached-3.0.3.tgz && \
	tar -zxvf memcached-3.0.3.tgz && \
	cd /tmp/memcached-3.0.3 && \
	phpize && \
	./configure && \
	make && make install && \
	echo 'extension=memcached.so' > "${php_ini_dir}/35_memcached.ini"

# Build & install php7_memcache (Alpine Package does not exists at this time - source from pecl is blocking)
RUN cd /tmp && \
	curl -fsSL 'https://github.com/websupport-sk/pecl-memcache/archive/NON_BLOCKING_IO_php7.zip' \
	--output /tmp/memcache.zip && \
	unzip memcache.zip && \
	cd /tmp/pecl-memcache-NON_BLOCKING_IO_php7 && \
	phpize && \
	./configure --enable-memcache && \
	make && make install && \
	echo 'extension=memcache.so' > "${php_ini_dir}/35_memcache.ini"

# dump some build done info on PHP
RUN php -m && php --ini

# Clean up the apk cache and tmp just in case
RUN rm -rf /var/cache/apk/* && \
	rm -rf /tmp/*

# Expose the ports for nginx
EXPOSE 9000

# the entry point definition
ENTRYPOINT ["/entrypoint.sh"]

# default command for entrypoint.sh
CMD ["supervisor"]
