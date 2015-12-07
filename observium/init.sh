#!/bin/bash

atd

if [ ! -d /data/config ]; then
	mkdir /data/config
	chown nobody:users /data/config
fi
if [ ! -d /data/rrd ]; then
	mkdir /data/rrd
	chown nobody:users /data/rrd
fi
if [ ! -d /data/logs ]; then
	mkdir /data/logs
	chown nobody:users /data/logs
fi
if [ ! -d /data/plugins ]; then
	mkdir /data/plugins
	chown nobody:users /data/plugins
fi

# Check if PHP database config exists. If not, copy in the default config
if [ ! -f /data/config/config.php ]; then
	echo "Loading PHP config from default."
	cp /opt/observium/config.php.default /data/config/config.php
	chown nobody:users /data/config/config.php
fi

ln -s /data/config/config.php /opt/observium/config.php
ln -s /data/rrd /opt/observium/rrd
chown nobody:users -R /opt/observium
chmod 755 -R /opt/observium

if [ ! -f /etc/container_environment/TZ ] ; then
	echo UTC > /etc/container_environment/TZ
	TZ="UTC"
fi

if [ ! -f /etc/container_environment/POLLER ] ; then
	echo 16 > /etc/container_environment/POLLER
	POLLER=16
fi

sed -i "s#\;date\.timezone\ \=#date\.timezone\ \=\ $TZ#g" /etc/php5/cli/php.ini
sed -i "s#\;date\.timezone\ \=#date\.timezone\ \=\ $TZ#g" /etc/php5/apache2/php.ini
sed -i "s/#PC#/$POLLER/g" /etc/cron.d/observium

DB_TYPE=${DB_TYPE:-}
DB_HOST=${DB_HOST:-}
DB_PORT=${DB_PORT:-}
DB_NAME=${DB_NAME:-}
DB_USER=${DB_USER:-}
DB_PASS=${DB_PASS:-}

if [ -n "${MYSQL_PORT_3306_TCP_ADDR}" ]; then
	DB_TYPE=${DB_TYPE:-mysql}
	DB_HOST=${DB_HOST:-${MYSQL_PORT_3306_TCP_ADDR}}
	DB_PORT=${DB_PORT:-${MYSQL_PORT_3306_TCP_PORT}}

	# support for linked sameersbn/mysql image
	DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
	DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
	DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}	
	
	# support for linked orchardup/mysql and enturylink/mysql image
	# also supports official mysql image
	DB_USER=${DB_USER:-${MYSQL_ENV_MYSQL_USER}}
	DB_PASS=${DB_PASS:-${MYSQL_ENV_MYSQL_PASSWORD}}
	DB_NAME=${DB_NAME:-${MYSQL_ENV_MYSQL_DATABASE}}
fi

if [ -z "${DB_HOST}" ]; then
  echo "ERROR: "
  echo "  Please configure the database connection."
  echo "  Cannot continue without a database. Aborting..."
  exit 1
fi

# use default port number if it is still not set
case "${DB_TYPE}" in
  mysql) DB_PORT=${DB_PORT:-3306} ;;
  *)
    echo "ERROR: "
    echo "  Please specify the database type in use via the DB_TYPE configuration option."
    echo "  Accepted value \"mysql\". Aborting..."
    exit 1
    ;;
esac

# set default user and database
DB_USER=${DB_USER:-root}
DB_NAME=${DB_NAME:-observium}

sed -i -e "s/\$config\['db_pass'\] = '.*';/\$config\['db_pass'\] = '$DB_PASS';/g" /data/config/config.php
sed -i -e "s/\$config\['db_user'\] = '.*';/\$config\['db_user'\] = '$DB_USER';/g" /data/config/config.php
sed -i -e "s/\$config\['db_host'\] = '.*';/\$config\['db_host'\] = '$DB_HOST';/g" /data/config/config.php
sed -i -e "s/\$config\['db_name'\] = '.*';/\$config\['db_name'\] = '$DB_NAME';/g" /data/config/config.php
sed -i "/\$config\['rrd_dir'\].*;/d" /data/config/config.php
sed -i "/\$config\['log_file'\].*;/d" /data/config/config.php
sed -i "/\$config\['log_dir'\].*;/d" /data/config/config.php
echo "\$config['rrd_dir']       = \"/data/rrd\";" >> /data/config/config.php
echo "\$config['log_file']      = \"/data/logs/observium.log\";" >> /data/config/config.php
echo "\$config['log_dir']       = \"/data/logs\";" >> /data/config/config.php

# checking for supported plugins
#weathermap
if [ -d /data/plugins/weathermap ]; then
	sed -i -e "s/\$observium_base = '.*';/\$observium_base = '/opt/observium/';/g" /data/plugins/weathermap/data-pick.php
	sed -i -e "s/\$ENABLED=false;/\$ENABLED=true;/g" /data/plugins/weathermap/editor.php
	chown www-data:www-data /data/plugins/weathermap/configs/
	mkdir -p /data/plugins/weathermap/maps
	chown www-data:www-data /data/plugins/weathermap/maps
	chmod +x /data/plugins/weathermap/map-poller.php
	echo "*/5 * * * *   root    php /data/plugins/weathermap/map-poller.php >> /dev/null 2>&1" > /etc/cron.d/weathermap
	rm -f /opt/observium/html/includes/navbar-custom.inc.php
	ln -s /data/plugins/weathermap/navbar-custom.inc.php /opt/observium/html/includes/navbar-custom.inc.php
	rm -f /opt/observium/html/weathermap
	ln -s /data/plugins/weathermap /opt/observium/html/weathermap
fi


prog="mysqladmin -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} ${DB_PASS:+-p$DB_PASS} status"
timeout=60
printf "Waiting for database server to accept connections"
while ! ${prog} >/dev/null 2>&1
do
	timeout=$(expr $timeout - 1)
	if [ $timeout -eq 0 ]; then
		printf "\nCould not connect to database server. Aborting...\n"
		exit 1
	fi
	printf "."
	sleep 1
done

QUERY="SELECT count(*) FROM information_schema.tables WHERE table_schema = '${DB_NAME}';"
COUNT=$(mysql -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} ${DB_PASS:+-p$DB_PASS} -ss -e "${QUERY}")

cd /opt/observium
php includes/update/update.php
if [ -z "${COUNT}" -o ${COUNT} -eq 0 ]; then
	echo "Setting up Observium for firstrun."
	php adduser.php observium observium 10
fi

echo "/opt/observium/discovery.php -u" | at -M now + 1 minute
echo "/opt/observium/discovery.php -h all" | at -M now + 2 minute