FROM php:7.4-apache

RUN apt-get update && apt-get install -y \
        libssl-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        zlib1g-dev \
	libxslt-dev \
	    libzip-dev \
        libicu-dev \
        g++ \
        libbase58-dev \
        libyaml-dev \
        unzip \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && docker-php-ext-install -j$(nproc) iconv \
    && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install -j$(nproc) xsl \
    && docker-php-ext-install -j$(nproc) pdo_mysql \
    && docker-php-ext-install -j$(nproc) soap \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl gettext zip bcmath

RUN a2enmod rewrite
RUN pecl install mongodb && pecl install base58-0.1.3 && pecl install yaml && docker-php-ext-enable mongodb base58 yaml

RUN apt-get install -y wget libsodium-dev

RUN mkdir -p /app && rm -fr /var/www/html && ln -s /app /var/www/html
RUN cd /app && wget -qO- -O temp.zip https://github.com/devcode-it/openstamanager/releases/download/v2.4.32/openstamanager-2.4.32.zip && unzip temp.zip && rm temp.zip && chmod 777 -R ./
#ADD sample/ /app
ADD php.ini /usr/local/etc/php/php.ini

# Set dynamic memory limit
ENV phpmemory_limit=128M
RUN sed -i 's/memory_limit = .*/memory_limit = ${phpmemory_limit}/' /usr/local/etc/php/php.ini




#FROM trafex/alpine-nginx-php7
#RUN cd /var/www/html && rm index.* && wget -qO- -O temp.zip https://github.com/devcode-it/openstamanager/releases/download/v2.4.19/openstamanager-2.4.19.zip && unzip temp.zip && rm temp.zip && chmod 777 -R ./
