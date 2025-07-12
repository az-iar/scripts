#!/bin/bash

set -e

# Prompt for app name and password
read -p "Enter Laravel app name (e.g. myapp): " APP_NAME
read -sp "Enter password for PostgreSQL '$APP_NAME' user: " DB_PASSWORD
echo

APP_DIR="/var/www/$APP_NAME"

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
sudo -u postgres psql -c "CREATE USER $APP_NAME WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $APP_NAME OWNER $APP_NAME;"

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
cat > /etc/nginx/sites-available/$APP_NAME <<EOL
server {
    listen 80;
    server_name yourdomain.com;
    root $APP_DIR/public;

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

ln -s /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# Certbot
echo "🔐 Installing Certbot..."
apt install -y certbot python3-certbot-nginx

# Laravel Horizon via Supervisor
echo "🚦 Setting up Supervisor for Laravel Horizon..."
cat > /etc/supervisor/conf.d/horizon-$APP_NAME.conf <<EOL
[program:horizon-$APP_NAME]
process_name=%(program_name)s
command=php $APP_DIR/artisan horizon
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=/var/log/supervisor/horizon-$APP_NAME.log
EOL

supervisorctl reread
supervisorctl update

echo "✅ Done! Laravel stack installed for $APP_NAME."
echo "📂 App folder: $APP_DIR"
echo "🗃️ DB name/user: $APP_NAME"
echo "🔑 DB password: $DB_PASSWORD"
echo "📄 Vhost: /etc/nginx/sites-available/$APP_NAME"
echo "⚠️ Next steps:"
echo "- Place your Laravel code in $APP_DIR"
echo "- Set DB settings in .env"
echo "- Run certbot: certbot --nginx -d yourdomain.com"
