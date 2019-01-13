# docker_mailpiler

To create a new container:

docker stop mailpiler

mkdir -p store
mkdir -p mysql
mkdir -p sphinx
mkdir -p stat
mkdir -p www
mkdir -p config

docker rm mailpiler

docker run  -d --name=mailpiler \
  -p 8080:80 \
  -p 25:25 \
  -e NGINX_HOSTNAME=localhost.local \
  -e PILER_HOSTNAME=localhost.local:8080 \
  -e PILER_MAILDOMAIN=local.local  \
  -e MYSQL_ROOT_PASSWORD=change_me_immediately  \
  -v /volume1/docker/mailpiler/store:/var/piler/store \
  -v /volume1/docker/mailpiler/sphinx:/var/piler/sphinx \
  -v /volume1/docker/mailpiler/www:/var/piler/www \
  -v /volume1/docker/mailpiler/mysql:/var/lib/mysql \
  -v /volume1/docker/mailpiler/config:/usr/local/etc/piler \
  --restart unless-stopped \
  mailpiler
