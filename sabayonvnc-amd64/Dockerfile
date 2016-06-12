FROM sabayon/base-amd64
MAINTAINER Ettore Di Giacinto <mudler@sabayon.org>

ENV ACCEPT_LICENSE *

RUN equo up \
    && equo i x11-misc/x11vnc app-admin/supervisor \
        openssh pwgen sudo nano lxde-base/lxde-meta gcc \
        nginx dev-python/pip procps \
        xorg-server xauth\
	xdotool \
    && equo cleanup

ADD web /web/
RUN pip install -r /web/requirements.txt

ADD noVNC /noVNC/
ADD nginx.conf.default /etc/nginx/nginx.conf
ADD nginx.conf /etc/nginx/sites-enabled/default
ADD startup.sh /
ADD supervisord.conf /etc/

# Additional packages, that are not needed to make a vnc image
RUN equo up \
    && equo i terminator \
    && equo cleanup


EXPOSE 6080
WORKDIR /root
ENTRYPOINT ["/startup.sh"]
