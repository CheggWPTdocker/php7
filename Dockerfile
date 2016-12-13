FROM cheggwpt/alpine:edge

RUN	apk --update --no-cache add \
	--virtual .build_package git curl php7-dev build-base autoconf \
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
	mkdir -p /run/php && \
	chown -R www-data:www-data /run/php 

# build phpiredis
RUN cd /tmp && \
	git clone https://github.com/nrk/phpiredis.git phpiredis && \
	cd phpiredis && \
	ln -s /usr/bin/php-config7 /usr/bin/php-config && \
	/usr/bin/phpize7 && \
	./configure && \
	make && \
	make install && \
	echo 'extension=phpiredis.so' > /etc/php7/conf.d/33-phpiredis.ini && \
	cd /tmp && \
	rm -rf phpiredis /var/cache/apk/* 

# Expose the ports for nginx
EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["supervisor"]
