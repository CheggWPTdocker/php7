FROM cheggwpt/alpine:edge

RUN	apk --update --no-cache add \
	--virtual .build_package git curl php7-dev file build-base autoconf \
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
		php7-iconv \
		php7-json \
		php7-mbstring \
		php7-mcrypt \
		php7-mysqli \
		php7-openssl \
		php7-pdo \
		php7-pdo_dblib \
		php7-pdo_mysql \
		php7-pdo_pgsql \
		php7-pdo_sqlite \
		php7-phar \
		php7-soap \
		php7-sqlite3 \
		php7-xmlreader \
		php7-xmlrpc \
		php7-zip \
	--virtual .redis_tools hiredis hiredis-dev


# Add the files
COPY container_confs /

# Add the www-data user and group, fail on error
RUN set -x ; \
	addgroup -g 82 -S www-data ; \
	adduser -u 82 -D -S -G www-data www-data && exit 0 ; exit 1

# dont display errors 	sed -i -e 's/display_errors = Off/display_errors = On/g' /etc/php7/php.ini && \
# fix path off
# error log becomes stderr
# Enable php-fpm on nginx virtualhost configuration
RUN	sed -i -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php7/php.ini && \
	sed -i -e 's/;error_log = php_errors.log/error_log = \/proc\/self\/fd\/1/g' /etc/php7/php.ini

# Make php7 the default php
# Add the process control dirs for php, nginx, and supervisord.  webroot is added by copy container confs
# own up the nginx control dir
# own up the webroot dir
# make it user/group read write
RUN ln -s /usr/bin/php7 /usr/bin/php && \
	ln -s /usr/bin/php-config7 /usr/bin/php-config && \
	ln -s /usr/bin/phpize7 /usr/bin/phpize && \
	mkdir -p /run/php && \
	chown -R www-data:www-data /run/php

ENV php_ini_dir /etc/php7/conf.d

# build phpiredis
RUN cd /tmp && \
	git clone https://github.com/nrk/phpiredis.git phpiredis && \
	cd phpiredis && \
	phpize && \
	./configure && \
	make && make install && \
	echo 'extension=phpiredis.so' > "${php_ini_dir}/33-phpiredis.ini" && \
	cd /tmp && \
	rm -rf phpiredis

ENV tideways_ext_version 4.0.7
ENV tideways_php_version 2.0.14
ENV tideways_dl https://github.com/tideways/

# Build & install ext/tideways & Tideways.php
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
	php -m && php --ini && \
    ls -l "$(php-config --extension-dir)/Tideways.php" && \
	cd /tmp && rm -rf "v${tideways_ext_version}.zip" php-profiler-extension*

RUN rm -rf /var/cache/apk/*

# Expose the ports for nginx
EXPOSE 9000
