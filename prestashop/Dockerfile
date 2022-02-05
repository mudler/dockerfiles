FROM prestashop/prestashop:1.6.1.7

WORKDIR /

RUN apt-get update && apt-get install -y unzip build-essential apache2-threaded-dev

RUN wget https://github.com/gnif/mod_rpaf/archive/stable.zip && unzip stable.zip && cd mod_rpaf-stable && make && make install

COPY rpaf.load /etc/apache2/mods-available/rpaf.load
COPY rpaf.conf /etc/apache2/mods-available/rpaf.conf
RUN apt-get remove -y unzip build-essential
RUN a2enmod rpaf
CMD ["/tmp/docker_run.sh"]
