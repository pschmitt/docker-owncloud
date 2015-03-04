FROM debian:8.0

MAINTAINER Philipp Schmitt <philipp@schmitt.co>

ENV OWNCLOUD_VERSION=8.0.0.7

# Dependencies
# TODO: Add NFS support
RUN export DEBIAN_FRONTEND=noninteractive; \
    apt-get update && \
    apt-get install -y cron bzip2 php5-cli php5-gd php5-pgsql php5-sqlite \
    php5-mysqlnd php5-curl php5-intl php5-mcrypt php5-ldap php5-gmp php5-apcu \
    php5-imagick php5-fpm smbclient nginx supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Config files
ADD https://download.owncloud.org/community/owncloud-8.0.1.tar.bz2 /tmp/owncloud.tar.bz2
ADD nginx_nossl.conf /etc/nginx/nginx_nossl.conf
ADD nginx_ssl.conf /etc/nginx/nginx_ssl.conf
ADD php.ini /etc/php5/fpm/php.ini
ADD cron.conf /etc/owncloud-cron.conf
ADD supervisor-owncloud.conf /etc/supervisor/conf.d/supervisor-owncloud.conf
ADD run.sh /usr/bin/run.sh

# Install owncloud
RUN mkdir -p /var/www/owncloud /owncloud /var/log/cron && \
    tar -C /var/www/ -xvf /tmp/owncloud.tar.bz2 && \
    chmod +x /usr/bin/run.sh && \
    rm /tmp/owncloud.tar.bz2 && \
    crontab /etc/owncloud-cron.conf

EXPOSE 80 443

VOLUME ["/var/www/owncloud/config"]
VOLUME ["/var/www/owncloud/data"]
VOLUME ["/var/www/owncloud/apps"]
VOLUME ["/etc/ssl/certs/owncloud.crt"]
VOLUME ["/etc/ssl/private/owncloud.key"]
VOLUME ["/var/log/nginx"]

WORKDIR /var/www/owncloud
# USER www-data
CMD ["/usr/bin/run.sh"]
