# php:X-apache ships Apache + mod_php; host nginx in front of this container
# reverse-proxies port 80 -> 8080, so Apache must bind to a
# non-80 internal port to coexist with host nginx when run with --network host.
FROM php:8.2-apache
# libicu-dev is required by the `intl` extension — without it, pkg-config
# can't resolve icu-uc/icu-io/icu-i18n and docker-php-ext-install fails.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git unzip libpq-dev libonig-dev libxml2-dev libzip-dev libicu-dev zip \
    && docker-php-ext-install pdo pdo_pgsql pdo_mysql mbstring bcmath zip intl \
    && rm -rf /var/lib/apt/lists/*

# Laravel serves from public/, not the project root.
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri 's!/var/www/html!/var/www/html/public!g' \
        /etc/apache2/sites-available/000-default.conf /etc/apache2/apache2.conf \
    && a2enmod rewrite

# Apache listens on container port 8080, NOT 80, so it
# coexists with host nginx when the container runs with --network host.
RUN sed -ri 's!Listen 80!Listen 8080!' /etc/apache2/ports.conf \
    && sed -ri 's!<VirtualHost \*:80>!<VirtualHost *:8080>!' \
        /etc/apache2/sites-available/000-default.conf

WORKDIR /var/www/html
COPY . .

# Laravel's post-autoload-dump invokes `artisan package:discover` which needs
# bootstrap/cache and storage/framework/* to exist before composer runs — the
# UDAP scaffold uses .gitkeep but Git can't track empty bootstrap/cache.
RUN mkdir -p bootstrap/cache \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

EXPOSE 8080
CMD ["apache2-foreground"]
