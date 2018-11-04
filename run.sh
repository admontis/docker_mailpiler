#!/bin/sh

mkdir -p localstore/store
mkdir -p localstore/mysql
mkdir -p localstore/sphinx
mkdir -p localstore/stat
mkdir -p localstore/www
mkdir -p localstore/config


docker stop mailpiler

docker rm mailpiler

docker run  -d --name=mailpiler \
  -p 8080:80 \
  -p 25:25 \
  -e NGINX_HOSTNAME=localhost \
  -e PILER_HOSTNAME=localhost:8080 \
  -e PILER_MAILDOMAIN=example.com  \
  -e MYSQL_ROOT_PASSWORD=test1234  \
  -v `pwd`/localstore/store:/var/piler/store \
  -v `pwd`/localstore/sphinx:/var/piler/sphinx \
  -v `pwd`/localstore/www:/var/piler/www \
  -v `pwd`/localstore/mysql:/var/lib/mysql \
  -v `pwd`/localstore/config:/usr/local/etc/piler \
 mailpiler
