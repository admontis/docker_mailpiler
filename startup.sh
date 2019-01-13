#!/bin/sh


if [ ! -d /var/lib/mysql/mysql ]; then
  mysql_install_db
  /etc/init.d/mysql start
  mysqladmin -u root password ${MYSQL_ROOT_PASSWORD}
  /etc/init.d/mysql stop
fi

if [ ! -f /usr/local/etc/piler/piler.key ]; then

  cp /usr/src/piler/etc/*.dist /usr/local/etc/piler
  cp /usr/src/piler/etc/piler.conf /usr/local/etc/piler/piler.conf.dist

  /etc/init.d/mysql start
  cd /usr/src/piler && /postinstall.sh

  indexer -c /usr/local/etc/piler/sphinx.conf --all

  sed -i 's/${prefix}\/etc\/piler/\/var\/piler\/www/g' /var/piler/www/config.php
  cp /var/piler/www/config-site.php /var/piler/www/config-site.php.bak

  cat > /var/piler/www/config-site.php  <<EOF
<?php

\$config['SITE_NAME'] = '${PILER_HOSTNAME}';
\$config['SITE_URL'] = 'http://' . \$config['SITE_NAME'] . '/';
\$config['DIR_BASE'] = '/var/piler/www/';

\$config['SMTP_DOMAIN'] = '${PILER_MAILDOMAIN}';
\$config['SMTP_FROMADDR'] = 'no-reply@${PILER_MAILDOMAIN}';
\$config['ADMIN_EMAIL'] = 'admin@${PILER_MAILDOMAIN}';

\$config['DB_DRIVER'] = 'mysql';
\$config['DB_PREFIX'] = '';
\$config['DB_HOSTNAME'] = 'localhost';
\$config['DB_USERNAME'] = 'piler';
\$config['DB_PASSWORD'] = 'piler';
\$config['DB_DATABASE'] = 'piler';

\$config['SMARTHOST'] = '';
\$config['SMARTHOST_PORT'] = 25;

EOF

  /etc/init.d/mysql stop

fi

sed -i 's/server_name\ localhost/server_name\ '${NGINX_HOSTNAME:-localhost}'/g' /etc/nginx/conf.d/default.conf

cat > /var/spool/cron/crontabs/piler <<EOF
   ### PILERSTART
   5,35 * * * * /usr/local/libexec/piler/indexer.delta.sh
   30   2 * * * /usr/local/libexec/piler/indexer.main.sh
   15,45 * * * * /usr/local/libexec/piler/indexer.attachment.sh
   */15 * * * * /usr/bin/indexer --quiet tag1 --rotate --config /usr/local/etc/piler/sphinx.conf
   */15 * * * * /usr/bin/indexer --quiet note1 --rotate --config /usr/local/etc/piler/sphinx.conf
   30   6 * * * /usr/bin/php /usr/local/libexec/piler/generate_stats.php --webui /var/piler/www >/dev/null
   */5 * * * * /usr/bin/find /var/piler/www/tmp -type f -name i.\* -exec rm -f {} \;
   ### PILEREND

EOF

chown piler:piler /var/spool/cron/crontabs/piler
chown -R piler:piler /var/piler
usermod -a -G crontab piler

/usr/bin/supervisord
