#!/bin/bash

mkdir -p /var/run/sshd

# PASS=`pwgen -c -n -1 10`
PASS=sabayon
# echo "Username: ubuntu Password: $PASS"
id -u sabayon &>/dev/null || useradd --create-home --shell /bin/bash --user-group --groups wheel,video sabayon
echo "sabayon:$PASS" | chpasswd
echo "root:$PASS" | chpasswd
[ -e /etc/sudoers ] && echo "sabayon ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

cd /web && ./run.py > /var/log/web.log 2>&1 &
nginx -c /etc/nginx/nginx.conf
mkdir -p /var/log/supervisord/
exec /usr/bin/supervisord -n
