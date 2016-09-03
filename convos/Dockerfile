FROM sabayon/base-amd64

# Define custom Convos home
ENV CONVOS_HOME /convos-data

# Accepting all licenses when running equo commands
ENV ACCEPT_LICENSE=*

# Installing Convos dependencies
RUN equo up && equo i net-misc/curl dev-lang/perl dev-perl/Unicode-UTF8 dev-perl/Crypt-SSLeay dev-perl/Crypt-Eksblowfish

# install convos

RUN cd / && curl https://convos.by/install.sh | sh -
  

ENTRYPOINT ["/convos/script/convos", "daemon"]

VOLUME ["/convos-data"]

