FROM debian:stretch-slim

RUN apt-get -y update && apt-get -y upgrade

RUN apt-get -y install sudo curl htop mc ntp ntpdate locate unzip file lftp figlet mtr-tiny dialog dnsutils lsb-release ca-certificates bash-completion \
    build-essential catdoc checkinstall gettext php-curl php-gd php-ldap php-memcache php-mysql \
    libltdl7 libssl-dev libtre-dev libtre5 memcached mysql-client mysql-common mysql-server openssl libzip4 poppler-utils sysstat tnef unrtf \
    python-mysqldb nginx php-fpm sphinxsearch libzip-dev libmysql++-dev libmemcached-dev libwrap0-dev supervisor hostname vim

RUN groupadd piler && useradd -g piler -m -s /bin/sh -d /var/piler piler && usermod -L piler && chmod 755 /var/piler

RUN mkdir -p /usr/src/piler && \
  curl -L https://bitbucket.org/jsuto/piler/downloads/piler-1.3.4.tar.gz  | tar --strip-components=1 -xzC /usr/src/piler && \
  cd /usr/src/piler && ./configure --localstatedir=/var --with-database=mysql --enable-tcpwrappers --enable-memcached && make && make install && \
  echo /usr/local/lib > /etc/ld.so.conf.d/local.conf && ldconfig && \
  sed -e'/load_default_values$/q' ./util/postinstall.sh > /tmp/postinstall.sh && \
  cd /tmp && echo $'make_cron_entries\ncrontab -u $PILERUSER $CRON_TMP\nclean_up_temp_stuff' >> postinstall.sh && sh postinstall.sh && rm postinstall.sh


RUN dpkg -P build-essential checkinstall dpkg-dev g++ libssl-dev libtre-dev libzip-dev libmysql++-dev libmemcached-dev libwrap0-dev gcc make && apt-get -y autoremove

RUN rm -rf /var/lib/mysql/*

ADD postinstall.sh /
ADD run_postinstall.sh /
ADD default.conf /
ADD startup.sh /

RUN chmod 755 /postinstall.sh
RUN chmod 755 /run_postinstall.sh
RUN chmod 755 /startup.sh


RUN mkdir -p /var/log/supervisor
RUN mkdir -p /run/php
RUN mkdir -p /var/run/mysqld && chmod 777 /var/run/mysqld

ADD ./default.conf /etc/nginx/conf.d/

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 25/tcp 80/tcp
CMD ["/startup.sh"]
