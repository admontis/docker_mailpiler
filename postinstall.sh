#!/bin/bash


INDEXER=$(which indexer 2>/dev/null)
SEARCHD=$(which searchd 2>/dev/null)
CRON_ORIG="/tmp/crontab.piler.orig"
CRON_TMP="/tmp/crontab.piler"
PILERCONF_TMP="/tmp/config.piler.88"
SOCKET_HELPER_SCRIPT="aaa.pl"


load_default_values() {
   PILERUSER="piler"
   PILERGROUP="piler"
   SYSCONFDIR=/usr/local/etc
   LOCALSTATEDIR=/var
   LIBEXECDIR=/usr/local/libexec
   DATAROOTDIR=/usr/local/share

   KEYTMPFILE="piler.key"
   KEYFILE="${SYSCONFDIR}/piler/piler.key"

   HOSTNAME=$(hostname --fqdn)

   MYSQL_HOSTNAME="localhost"
   MYSQL_DATABASE="piler"
   MYSQL_USERNAME="piler"
   MYSQL_PASSWORD="piler"
   MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
   MYSQL_SOCKET="/var/run/mysqld/mysqld.sock"

   SPHINXCFG="${SYSCONFDIR}/piler/sphinx.conf"

   WWWGROUP="www-data"
   DOCROOT="/var/piler/www"

   SMARTHOST=""
   SMARTHOST_PORT=25

   SSL_CERT_DATA="/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com"
}


make_certificate() {
   if [[ ! -f "${SYSCONFDIR}/piler/piler.pem" ]]; then
      echo -n "Making an ssl certificate ... "
      openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "$SSL_CERT_DATA" -keyout "${SYSCONFDIR}/piler/piler.pem" -out 1.cert -sha1
      cat 1.cert >> "${SYSCONFDIR}/piler/piler.pem"
      chmod 640 "${SYSCONFDIR}/piler/piler.pem"
      chgrp "$PILERUSER" "${SYSCONFDIR}/piler/piler.pem"
      rm 1.cert
   fi
}


display_install_intro() {
  echo ""
  echo ""
  echo "This is the postinstall utility for piler"
  echo "It should be run only at the first install. DO NOT run on an existing piler installation!"
  echo ""

  askYN "Continue? [Y/N]" "N"
  if [[ "$response" != "yes" ]]; then
     echo "Aborted."
     exit
  fi

  echo ""
}


check_user() {
   user="$1"

   if [[ $(whoami) != "$user" ]]; then echo "ERROR: postinstaller must be run as ${user} user"; exit 1; fi
}


isFQDN() {
  # we need min. 2 dots
  if [ x"$1" = "xdogfood" ]; then
    echo 1
    return
  fi

  if [ x"$1" = "x" ]; then
    echo 0
    return
  fi

  NF=`echo $1 | awk -F. '{print NF}'`
  if [ $NF -ge 2 ]; then 
    echo 1
  else 
    echo 0
  fi
}


ask() {
  PROMPT=$1
  DEFAULT=$2

  echo ""
  echo -n "$PROMPT [$DEFAULT] "
  read response

  if [ -z $response ]; then
    response=$DEFAULT
  fi
}


askNoEcho() {
  PROMPT=$1
  DEFAULT=$2

  stty -echo
  ask "$PROMPT" "$DEFAULT"
  stty echo
  echo ""
}

askNonBlankNoEcho() {
  PROMPT=$1
  DEFAULT=$2

  while [ 1 ]; do
    stty -echo
    ask "$PROMPT" "$DEFAULT"
    stty echo
    echo ""
    if [ ! -z $response ]; then
      break
    fi
    echo "A non-blank answer is required"
  done
}


askNonBlank() {
  PROMPT=$1
  DEFAULT=$2

  while [ 1 ]; do
    ask "$PROMPT" "$DEFAULT"
    if [ ! -z $response ]; then
      break
    fi
    echo "A non-blank answer is required"
  done
}


askYN() {
  PROMPT=$1
  DEFAULT=$2

  if [ "x$DEFAULT" = "xyes" -o "x$DEFAULT" = "xYes" -o "x$DEFAULT" = "xy" -o "x$DEFAULT" = "xY" ]; then
    DEFAULT="Y"
  else
    DEFAULT="N"
  fi
  
  while [ 1 ]; do
    ask "$PROMPT" "$DEFAULT"
    response=$(perl -e "print lc(\"$response\");")
    if [ -z $response ]; then
      :
    else
      if [ $response = "yes" -o $response = "y" ]; then
        response="yes"
        break
      else 
        if [ $response = "no" -o $response = "n" ]; then
          response="no"
          break
        fi
      fi
    fi
    echo "A Yes/No answer is required"
  done
}


preinstall_check() {
   check_user root

   if [[ "$INDEXER" == "" ]]; then "ERROR: cannot find sphinx indexer"; echo ""; exit ; fi

   if [[ "$SEARCHD" == "" ]]; then "ERROR: cannot find sphinx searchd"; echo ""; exit 0; fi

   if [[ -f "$KEYFILE" ]]; then echo "ERROR: found existing keyfile (${KEYFILE}), aborting install"; echo ""; exit 0; fi
}


gather_webserver_data() {
   askNonBlank "Please enter the webserver groupname" "$WWWGROUP"
   WWWGROUP="$response"
}


gather_mysql_account() {

   if [[ -e /var/lib/mysql/mysql.sock ]]; then MYSQL_SOCKET="/var/lib/mysql/mysql.sock"; fi
   if [[ -e /var/run/mysqld/mysqld.sock ]]; then MYSQL_SOCKET="/var/run/mysqld/mysqld.sock"; fi

   askNonBlank "Please enter mysql hostname" "$MYSQL_HOSTNAME"
   MYSQL_HOSTNAME="$response"

   if [[ $MYSQL_HOSTNAME == "localhost" ]]; then
      askNonBlank "Please enter mysql socket path" "$MYSQL_SOCKET"
      MYSQL_SOCKET="$response"
   else
      MYSQL_SOCKET=""
   fi

   askNonBlank "Please enter mysql database" "${MYSQL_DATABASE}"
   MYSQL_DATABASE="$response"

   askNonBlank "Please enter mysql user name" "${MYSQL_USERNAME}"
   MYSQL_USERNAME="$response"

   askNoEcho "Please enter mysql password for ${MYSQL_USERNAME}" ""
   MYSQL_PASSWORD="$response"

   askNonBlankNoEcho "Please enter mysql root password" ""
   MYSQL_ROOT_PASSWORD="$response"

   s=$(echo "use information_schema; select TABLE_NAME from TABLES where TABLE_SCHEMA='${MYSQL_DATABASE}'" | mysql -h "$MYSQL_HOSTNAME" -u root --password="$MYSQL_ROOT_PASSWORD")
   if [ $? -eq 0 ];
   then
      echo "mysql connection successful"; echo;
      if [ $(echo $s | grep -c metadata) -eq 1 ]; then echo "ERROR: Detected metadata table in ${MYSQL_DATABASE}. Aborting"; exit 0; fi
   else
      echo "ERROR: failed to connect to mysql";
      gather_mysql_account
   fi

}


gather_sphinx_data() {
   askNonBlank "Please enter the path of sphinx.conf" "$SPHINXCFG"
   SPHINXCFG="$response"
}


gather_smtp_relay_data() {
   ask "Please enter smtp relay" "$SMARTHOST"
   SMARTHOST="$response"

   ask "Please enter smtp relay port" "$SMARTHOST_PORT"
   SMARTHOST_PORT="$response"
}


make_cron_entries() {

   crontab -u "$PILERUSER" -l > "$CRON_ORIG"

   grep PILERSTART "$CRON_ORIG" > /dev/null 2>&1
   if [ $? != 0 ]; then
      cat /dev/null > "$CRON_ORIG"
   fi

   grep PILEREND "$CRON_ORIG" > /dev/null 2>&1
   if [ $? != 0 ]; then
      cat /dev/null > "$CRON_ORIG"
   fi


   rm -f "$CRON_TMP"

   echo ""
   echo "### PILERSTART" >> "$CRON_TMP"
   echo "5,35 * * * * ${LIBEXECDIR}/piler/indexer.delta.sh" >> "$CRON_TMP"
   echo "30   2 * * * ${LIBEXECDIR}/piler/indexer.main.sh" >> "$CRON_TMP"
   echo "15,45 * * * * ${LIBEXECDIR}/piler/indexer.attachment.sh" >> "$CRON_TMP"
   echo "*/15 * * * * ${INDEXER} --quiet tag1 --rotate --config ${SYSCONFDIR}/piler/sphinx.conf" >> "$CRON_TMP"
   echo "*/15 * * * * ${INDEXER} --quiet note1 --rotate --config ${SYSCONFDIR}/piler/sphinx.conf" >> "$CRON_TMP"
   echo "30   6 * * * /usr/bin/php ${LIBEXECDIR}/piler/generate_stats.php --webui ${DOCROOT} >/dev/null" >> "$CRON_TMP"
   echo "*/5 * * * * /usr/bin/find ${DOCROOT}/tmp -type f -name i.\* -exec rm -f {} \;" >> "$CRON_TMP"
   echo "### PILEREND" >> "$CRON_TMP"
}


make_new_key() {
   dd if=/dev/urandom bs=56 count=1 of="$KEYTMPFILE" 2>/dev/null

   if [ $(stat -c '%s' "$KEYTMPFILE") -ne 56 ]; then echo "could not read 56 bytes from /dev/urandom to ${KEYTMPFILE}"; exit 1; fi
}


show_summary() {
   echo
   echo
   echo "INSTALLATION SUMMARY:"
   echo

   echo "piler user: ${PILERUSER}"
   echo "keyfile: ${KEYFILE}"
   echo

   echo "mysql host: ${MYSQL_HOSTNAME}"
   echo "mysql socket: ${MYSQL_SOCKET}"
   echo "mysql database: ${MYSQL_DATABASE}"
   echo "mysql username: ${MYSQL_USERNAME}"
   echo "mysql password: *******"
   echo

   echo "sphinx indexer: ${INDEXER}"
   echo "sphinx config file: ${SPHINXCFG}"
   echo

   echo "vhost docroot: ${DOCROOT}"
   echo "www group: ${WWWGROUP}"
   echo

   echo "smtp relay host: ${SMARTHOST}"
   echo "smtp relay port: ${SMARTHOST_PORT}"
   echo

   echo "piler crontab:"
   cat "$CRON_TMP"
   echo; echo;

   askYN "Correct? [Y/N]" "N"
   if [[ $response != "yes" ]]; then
      echo "Aborted."
      exit
   fi

}


execute_post_install_tasks() {

   echo;
   echo -n "Creating mysql database... ";
   sed -e "s%MYSQL_HOSTNAME%${MYSQL_HOSTNAME}%g" -e "s%MYSQL_DATABASE%${MYSQL_DATABASE}%g" -e "s%MYSQL_USERNAME%${MYSQL_USERNAME}%g" -e "s%MYSQL_PASSWORD%${MYSQL_PASSWORD}%g" "${DATAROOTDIR}/piler/db-mysql-root.sql.in" | mysql -h "$MYSQL_HOSTNAME" -u root --password="$MYSQL_ROOT_PASSWORD"
   mysql -h "$MYSQL_HOSTNAME" -u "$MYSQL_USERNAME" --password="$MYSQL_PASSWORD" "$MYSQL_DATABASE" < "${DATAROOTDIR}/piler/db-mysql.sql"
   echo "Done."

   echo -n "Writing sphinx configuration... ";
   sed -e "s%MYSQL_HOSTNAME%${MYSQL_HOSTNAME}%" -e "s%MYSQL_DATABASE%${MYSQL_DATABASE}%" -e "s%MYSQL_USERNAME%${MYSQL_USERNAME}%" -e "s%MYSQL_PASSWORD%${MYSQL_PASSWORD}%" "${SYSCONFDIR}/piler/sphinx.conf.dist" > "$SPHINXCFG"
   echo "Done."

   echo -n "Initializing sphinx indices... ";
   su "$PILERUSER" -c "indexer --all --config ${SPHINXCFG}"
   echo "Done."


   echo -n "installing cron entries for ${PILERUSER}... "
   crontab -u "$PILERUSER" "$CRON_TMP"
   echo "Done."


   echo -n "installing keyfile (${KEYTMPFILE}) to ${KEYFILE}... "
   cp "$KEYTMPFILE" "$KEYFILE"
   chgrp "$PILERUSER" "$KEYFILE"
   chmod 640 "$KEYFILE"
   rm -f "$KEYTMPFILE"
   echo "Done."

   make_certificate

cat <<SOCKHELPER > "$SOCKET_HELPER_SCRIPT"
\$a=\$ARGV[0];
\$a=~s/\//\\\\\//g;
print \$a;
SOCKHELPER

   MYSQL_SOCKET=$(perl "$SOCKET_HELPER_SCRIPT" "$MYSQL_SOCKET")

   sed -e "s/mysqlpwd=verystrongpassword/mysqlpwd=${MYSQL_PASSWORD}/" -e "s/tls_enable=0/tls_enable=1/" -e "s/mysqlsocket=\/var\/run\/mysqld\/mysqld.sock/mysqlsocket=${MYSQL_SOCKET}/" "${SYSCONFDIR}/piler/piler.conf.dist" > "$PILERCONF_TMP"
   cat "$PILERCONF_TMP" > "${SYSCONFDIR}/piler/piler.conf"
   rm -f "$PILERCONF_TMP"

   chmod 755 "${LOCALSTATEDIR}/piler/stat"

   if [[ -d webui ]]; then
      echo -n "Copying www files to ${DOCROOT}... "
      mkdir -p "$DOCROOT" || exit 1
      cp -R webui/* "$DOCROOT"
      cp webui/.htaccess "$DOCROOT"
   fi

   if [[ -d /var/www/piler.yourdomain.com ]]; then
      mv /var/www/piler.yourdomain.com "$DOCROOT"
   fi


   if [ -d "$DOCROOT" ]; then webui_install; fi

}


webui_install() {

   chmod 770 "${DOCROOT}/tmp" "${DOCROOT}/images"
   chown "$PILERUSER" "${DOCROOT}/tmp"
   chgrp "$WWWGROUP" "${DOCROOT}/tmp"

   echo "<?php" > "${DOCROOT}/config-site.php"
   echo >> "${DOCROOT}/config-site.php"

   echo "\$config['SITE_NAME'] = '$HOSTNAME';" >> "${DOCROOT}/config-site.php"
   echo "\$config['SITE_URL'] = 'http://' . \$config['SITE_NAME'] . '/';" >> "${DOCROOT}/config-site.php"
   echo "\$config['DIR_BASE'] = '$DOCROOT/';" >> "${DOCROOT}/config-site.php"

   echo >> "${DOCROOT}/config-site.php"

   echo "\$config['SMTP_DOMAIN'] = '$HOSTNAME';" >> "${DOCROOT}/config-site.php"
   echo "\$config['SMTP_FROMADDR'] = 'no-reply@$HOSTNAME';" >> "${DOCROOT}/config-site.php"
   echo "\$config['ADMIN_EMAIL'] = 'admin@$HOSTNAME';" >> "${DOCROOT}/config-site.php"

   echo >> "${DOCROOT}/config-site.php"

   echo "\$config['DB_DRIVER'] = 'mysql';" >> "${DOCROOT}/config-site.php"
   echo "\$config['DB_PREFIX'] = '';" >> "${DOCROOT}/config-site.php"
   echo "\$config['DB_HOSTNAME'] = '$MYSQL_HOSTNAME';" >> "${DOCROOT}/config-site.php"
   echo "\$config['DB_USERNAME'] = '$MYSQL_USERNAME';" >> "${DOCROOT}/config-site.php"
   echo "\$config['DB_PASSWORD'] = '$MYSQL_PASSWORD';" >> "${DOCROOT}/config-site.php"
   echo "\$config['DB_DATABASE'] = '$MYSQL_DATABASE';" >> "${DOCROOT}/config-site.php"

   echo >> "${DOCROOT}/config-site.php"

   echo "\$config['SMARTHOST'] = '$SMARTHOST';" >> "${DOCROOT}/config-site.php"
   echo "\$config['SMARTHOST_PORT'] = $SMARTHOST_PORT;" >> "${DOCROOT}/config-site.php"

   echo >> "${DOCROOT}/config-site.php"

   echo "Done."
}


clean_up_temp_stuff() {
   rm -f "$CRON_TMP"

   echo; echo "Done post installation tasks."; echo
}


load_default_values

#LOGFILE="/tmp/piler-install.log.$$"
#touch $LOGFILE
#chmod 600 $LOGFILE

preinstall_check

#display_install_intro

#gather_webserver_data
#gather_mysql_account
#gather_sphinx_data
#gather_smtp_relay_data


make_cron_entries
make_new_key

#show_summary

execute_post_install_tasks

clean_up_temp_stuff

