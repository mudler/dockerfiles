FROM sabayon/base-amd64

ENV CONVOS_HOME /convos-data

# Installing required software
ENV ACCEPT_LICENSE=*

RUN equo up 
# convos deps

RUN equo i net-misc/curl dev-lang/perl dev-perl/Unicode-UTF8 dev-perl/Crypt-SSLeay dev-perl/Crypt-Eksblowfish

# install convos

RUN cd / && curl https://convos.by/install.sh | sh -
  

ENTRYPOINT ["/convos/script/convos daemon"]

VOLUME ["/convos-data"]

