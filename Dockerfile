FROM php:8.1-fpm-alpine

RUN apk add --no-cache \
    bash curl wget zip unzip \
    libzip-dev libpng-dev libjpeg-turbo-dev freetype-dev \
    libxml2-dev icu-dev curl-dev oniguruma-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mysqli gd zip intl mbstring xml curl opcache \
    && docker-php-ext-enable opcache \
    && rm -rf /var/cache/apk/*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/html

COPY docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY . .

RUN mkdir -p application/cache application/logs uploads frequent_changing images/table_draw_object \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 application/cache application/logs uploads frequent_changing \
    && chmod -R o+rX /var/www/html

RUN if [ -f composer.json ]; then composer install --no-dev --optimize-autoloader --no-interaction; fi

HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
    CMD php-fpm -t || exit 1

CMD ["php-fpm"]
