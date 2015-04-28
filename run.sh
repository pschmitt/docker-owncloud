#!/usr/bin/env bash

set -e

DB_TYPE=${DB_TYPE:-sqlite}
DB_HOST=${DB_HOST:-localhost}
DB_NAME=${DB_NAME:-owncloud}
DB_USER=${DB_USER:-owncloud}
DB_PASS=${DB_PASS:-owncloud}
DB_TABLE_PREFIX=${DB_TABLE_PREFIX:-oc_}
ADMIN_USER=${ADMIN_USER:-admin}
ADMIN_PASS=${ADMIN_PASS:-changeme}
DATA_DIR=${DATA_DIR:-/var/www/owncloud/data}

HTTPS_ENABLED=${HTTPS_ENABLED:-false}

# FIXME: This next check is always true since there are default values to both
# crt and key
# Enable HTTPS if both crt and key are passed
# if [[ -n "$SSL_KEY" && -n "$SSL_CERT" ]]
# then
#     HTTPS_ENABLED=true
# fi

# Database vars
# TODO: Add support for Oracle DB (and SQLite?)
if [[ "$DB_PORT_5432_TCP_ADDR" ]]
then
    DB_TYPE=${DB_TYPE:-pgsql}
    DB_HOST=$DB_PORT_5432_TCP_ADDR
elif [[ "DB_PORT_3306_TCP_ADDR" ]]
then
    DB_TYPE=${DB_TYPE:-mysql}
    DB_HOST=$DB_PORT_3306_TCP_ADDR
fi

# echo "The $DB_TYPE database is listening on ${DB_HOST}:${DB_PORT}"
update_config_line() {
    local -r config="$1" option="$2" value="$3"
    if grep "$option" "$config" >/dev/null 2>&1
    then
        # Update existing option
        sed -i "s|\([\"']$option[\"']\s\+=>\).*|\1 '$value',|" "$config"
    else
        # Create autoconfig.php if necessary
        [[ -f "$config" ]] || {
            echo -e '<?php\n$AUTOCONFIG = array (' > "$config"
        }
        # Append to config
        echo "  \"$option\" => \"$value\"," >> "$config"
    fi
}

# TODO: Try to ignore unset variables, according to [1] those should be prompted
# when first launching the web UI
# 1: https://doc.owncloud.org/server/8.0/admin_manual/configuration_server/automatic_configuration.html?highlight=automatic%20configuration
owncloud_autoconfig() {
    echo -n "Creating autoconfig.php... "
    local -r config=/var/www/owncloud/config/autoconfig.php
    # Remove existing autoconfig
    rm -f "$config"
    update_config_line "$config" dbtype "$DB_TYPE"
    update_config_line "$config" dbhost "$DB_HOST"
    update_config_line "$config" dbname "$DB_NAME"
    update_config_line "$config" dbuser "$DB_USER"
    update_config_line "$config" dbpass "$DB_PASS"
    update_config_line "$config" dbtableprefix "$DB_TABLE_PREFIX"
    update_config_line "$config" adminlogin "$ADMIN_USER"
    update_config_line "$config" adminpass "$ADMIN_PASS"
    update_config_line "$config" directory "$DATA_DIR"
    # Add closing tag
    if ! grep ');' "$config"
    then
        echo ');' >> "$config"
    fi
    echo "Done !"
}

update_owncloud_config() {
    echo -n "Updating config.php... "
    local -r config=/var/www/owncloud/config/config.php
    update_config_line "$config" dbtype "$DB_TYPE"
    update_config_line "$config" dbhost "$DB_HOST"
    update_config_line "$config" dbname "$DB_NAME"
    update_config_line "$config" dbuser "$DB_USER"
    update_config_line "$config" dbpassword "$DB_PASS"
    update_config_line "$config" dbtableprefix "$DB_TABLE_PREFIX"
    update_config_line "$config" directory "$DATA_DIR"
    echo "Done !"
}

# Update the config if the config file exists, otherwise autoconfigure owncloud
if [[ -f /var/www/owncloud/config/config.php ]]
then
    update_owncloud_config
else
    owncloud_autoconfig
fi

update_nginx_config() {
    echo -n "Updating nginx.conf... "
    local -r config=/etc/nginx/nginx.conf
    # mv /etc/nginx/nginx.conf /etc/nginx.orig
    rm /etc/nginx/nginx.conf
    [[ "$HTTPS_ENABLED" == "true" ]] && {
        echo -n "SSL is enabled "
        ln -s /etc/nginx/nginx_ssl.conf /etc/nginx/nginx.conf
    } || {
        echo -n "SSL is disabled! "
        ln -s /etc/nginx/nginx_nossl.conf /etc/nginx/nginx.conf
    }
    echo "Done !"
}
update_nginx_config

# Create data directory
mkdir -p "$DATA_DIR"

# Fix permissions
chown -R www-data:www-data /var/www/owncloud

# FIXME: This setup is intended for running supervisord as www-data
# Supervisor setup
# touch /var/run/supervisord.pid
# chown www-data:www-data /var/run/supervisord.pid
# touch /var/log/supervisor/supervisord.log
# chown www-data:www-data /var/log/supervisor/supervisord.log
# mkdir -p /var/log/supervisor
# chown www-data:www-data /var/log/supervisor

# PHP-FPM setup
# touch /var/log/php5-fpm.log
# chown www-data:www-data /var/log/php5-fpm.log

# nginx setup
# mkdir -p /var/log/nginx
# chown www-data:www-data /var/log/nginx

update_timezone() {
    echo -n "Setting timezone to $1... "
    ln -sf "/usr/share/zoneinfo/$1" /etc/localtime
    [[ $? -eq 0 ]] && echo "Done !" || echo "FAILURE"
}
if [[ -n "$TIMEZONE" ]]
then
    update_timezone "$TIMEZONE"
fi

supervisord -n -c /etc/supervisor/supervisord.conf
