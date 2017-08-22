FROM sabayon/base-amd64
MAINTAINER Ettore Di Giacinto <mudler@sabayon.org>

ENV ACCEPT_LICENSE *

RUN equo up \
    && equo i x11-misc/x11vnc app-admin/supervisor \
        openssh pwgen sudo nano lxde-base/lxde-meta gcc \
        nginx dev-python/pip procps \
	sys-auth/pambase \
	sys-apps/grep sys-apps/busybox \
	sys-devel/binutils app-misc/sabayon-version xorg-server xauth\
	xdotool \
    && equo cleanup

ADD web /web/
RUN pip install --user -r /web/requirements.txt

ADD noVNC /noVNC/
ADD nginx.conf.default /etc/nginx/nginx.conf
ADD nginx.conf /etc/nginx/sites-enabled/default
ADD startup.sh /
ADD supervisord.conf /etc/

# Additional packages, that are not needed to make a vnc image
RUN equo up \
    && equo i terminator \
    && equo cleanup

RUN useradd --create-home --shell /bin/bash --user-group --groups lp,wheel,uucp,console,audio,video,users,lpadmin,portage,messagebus,plugdev,entropy sabayon
RUN echo "sabayon:sabayon" | chpasswd
RUN echo "root:sabayon" | chpasswd
RUN echo "sabayon ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Fix su
RUN rm -rf /etc/security/limits.d/*

EXPOSE 6080
WORKDIR /root
ENTRYPOINT ["/startup.sh"]
