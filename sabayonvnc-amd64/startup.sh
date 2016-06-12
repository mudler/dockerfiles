#!/bin/bash

mkdir -p /var/run/sshd

cd /web && ./run.py > /var/log/web.log 2>&1 &
nginx -c /etc/nginx/nginx.conf
mkdir -p /var/log/supervisord/
exec /usr/bin/supervisord -n
