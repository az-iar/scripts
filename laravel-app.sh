#!/bin/bash

set -e

# Basic setup
echo "Updating system..."
apt update && apt upgrade -y

echo "Installing basic tools..."
apt install -y software-properties-common curl unzip git gnupg2 ca-certificates lsb-release apt-transport-https

# PHP 8.4 setup
echo "Adding PHP 8.4 repository..."
add-apt-repository ppa:ondrej/php -y
apt update

echo "Installing PHP 8.4 and required extensions..."
apt install -y php8.4 php8.4-cli php8.4-fpm php8.4-mbstring php8.4-xml php8.4-curl php8.4-pgsql php8.4-bcmath php8.4-tokenizer php8.4-redis php8.4-zip

# Nginx
echo "Installing Nginx..."
apt install -y nginx
systemctl enable nginx
systemctl start nginx

# Redis
echo "Installing Redis..."
apt install -y redis
systemctl enable redis
systemctl start redis

# PostgreSQL
echo "Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib
systemctl enable postgresql
systemctl start postgresql

# Supervisor
echo "Installing Supervisor..."
apt install -y supervisor
systemctl enable supervisor
systemctl start supervisor

# PHP-FPM config fix (optional tuning)
sed -i 's|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|' /etc/php/8.4/fpm/php.ini
systemctl restart php8.4-fpm

echo "All services installed and started successfully."

# Optional: Setup Laravel Horizon Supervisor config
cat > /etc/supervisor/conf.d/horizon.conf <<EOL
[program:horizon]
process_name=%(program_name)s
command=php /var/www/html/artisan horizon
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=/var/log/supervisor/horizon.log
EOL

supervisorctl reread
supervisorctl update

echo "✅ Laravel stack installed. Don't forget to configure Nginx site and Laravel .env!"
