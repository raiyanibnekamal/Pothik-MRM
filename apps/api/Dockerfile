# Production PHP 8.2 base — aligned with `.github/workflows/ci.yml` (which
# installs shivammathur/setup-php 8.2 for the test job) and required by
# `laravel/reverb` (Phase 2). 8.0 was the previous default and is no longer
# supported upstream.
FROM php:8.2-cli

RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libpng-dev \
    && docker-php-ext-install pdo_mysql zip \
    && pecl install redis \
    && docker-php-ext-enable redis

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . .

RUN composer install --no-dev --optimize-autoloader --no-interaction || true

EXPOSE 8000

CMD php artisan serve --host=0.0.0.0 --port=8000
