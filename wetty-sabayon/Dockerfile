FROM sabayon/base-amd64

MAINTAINER mudler <mudler@sabayonlinux.org>

RUN echo "3" | equo i nodejs vim
RUN echo 3 | equo i git
RUN echo 3 | equo i gcc gcc-base

RUN git clone https://github.com/krishnasrinivas/wetty.git /app
WORKDIR /app
RUN npm install
RUN useradd -d /home/term -m -s /bin/bash term
RUN echo 'term:rockandroll' | chpasswd 

EXPOSE 80

ENTRYPOINT ["node"]
CMD ["app.js", "-p", "80"]
