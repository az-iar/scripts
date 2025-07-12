#!/bin/bash

set -e

# Prompt for PostgreSQL password
read -sp "Enter password for PostgreSQL 'laravel' user: " DB_PASSWORD
echo

# Update system
echo "🔄 Updating system..."
apt update && apt upgrade -y
apt install -y software-properties-common curl unzip git gnupg2 ca-certificates lsb-release apt-transport-https

# PHP 8.4 setup
echo "⚙️ Installing PHP 8.4..."
add-apt-repository ppa:ondrej/php -y
apt update
apt install -y php8.4 php8.4-cli php8.4-fpm php8.4-mbstring php8.4-xml php8.4-curl php8.4-pgsql php8.4-bcmath php8.4-tokenizer php8.4-redis php8.4-zip

# Nginx
echo "🌐 Installing Nginx..."
apt install -y nginx
systemctl enable nginx
systemctl start nginx

# Redis
echo "🧠 Installing Redis..."
apt install -y redis
systemctl enable redis-server
systemctl start redis-server

# PostgreSQL
echo "🗄️ Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib
systemctl enable postgresql
systemctl start postgresql

# Create PostgreSQL user and DB
echo "🧰 Setting up PostgreSQL user and DB..."
sudo -u postgres psql -c "CREATE USER laravel WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE laravel OWNER laravel;"

# Supervisor
echo "📦 Installing Supervisor..."
apt install -y supervisor
systemctl enable supervisor
systemctl start supervisor

# Composer
echo "🎼 Installing Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Node.js via NVM
echo "🟢 Installing Node.js via NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# Laravel Nginx vhost
echo "📜 Setting up Laravel Nginx vhost..."
cat > /etc/nginx/sites-available/laravel <<EOL
server {
    listen 80;
    server_name yourdomain.com;
    root /var/www/html/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# Certbot
echo "🔐 Installing Certbot..."
apt install -y certbot python3-certbot-nginx

# Laravel Horizon via Supervisor
echo "🚦 Setting up Supervisor for Laravel Horizon..."
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

echo "✅ Done! Laravel stack installed successfully."
echo "⚠️ Don't forget to:"
echo "- Set your correct domain in /etc/nginx/sites-available/laravel"
echo "- Run 'certbot --nginx -d yourdomain.com' to enable HTTPS"
echo "- Place your Laravel app at /var/www/html"
echo "- Set your DB password in .env to: $DB_PASSWORD"
