#!/bin/sh

docker stop mailpiler

docker rm mailpiler

docker run --rm  -d --name=mailpiler -p 8080:80 \
  -e PILER_HOSTNAME=localhost:8080 \
  -e PILER_MAILDOMAIN=wbstech.com  \
  -e MYSQL_ROOT_PASSWORD=test1234  \
  -v `pwd`/localstore/store:/var/piler/store \
  -v `pwd`/localstore/sphinx:/var/piler/sphinx \
  -v `pwd`/localstore/www:/var/piler/www \
  -v `pwd`/localstore/mysql:/var/lib/mysql \
  -v `pwd`/localstore/config:/usr/local/etc/piler \
 mailpiler
