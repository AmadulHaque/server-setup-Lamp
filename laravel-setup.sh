#!/bin/bash

# VPS Laravel Production Setup Script
# Compatible with Ubuntu 20.04/22.04 and Debian 11/12

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user with sudo privileges."
    fi
}

# Check OS compatibility
check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        error "Cannot determine OS version"
    fi

    case $OS in
        "Ubuntu"*)
            if [[ ! $VERSION =~ ^(20\.04|22\.04|24\.04)$ ]]; then
                warning "Ubuntu version $VERSION might not be fully supported. Recommended: 20.04, 22.04, or 24.04"
            fi
            ;;
        "Debian"*)
            if [[ ! $VERSION =~ ^(11|12)$ ]]; then
                warning "Debian version $VERSION might not be fully supported. Recommended: 11 or 12"
            fi
            ;;
        *)
            error "Unsupported OS: $OS. This script supports Ubuntu 20.04/22.04/24.04 and Debian 11/12"
            ;;
    esac
    
    log "Detected OS: $OS $VERSION"
}

# Menu selection function
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    
    echo -e "\n${BLUE}$prompt${NC}"
    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[i]}"
    done
    
    while true; do
        read -p "Enter your choice (1-${#options[@]}): " choice
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#options[@]} ]; then
            echo "${options[$((choice-1))]}"
            return
        else
            echo "Invalid choice. Please try again."
        fi
    done
}

# Get user inputs
get_user_inputs() {
    log "Getting configuration details..."
    
    # PHP Version
    PHP_VERSION=$(select_option "Select PHP version:" "8.1" "8.2" "8.3")
    
    # Web Server
    WEB_SERVER=$(select_option "Select web server:" "Nginx" "Apache")
    
    # MySQL/MariaDB
    DB_ENGINE=$(select_option "Select database engine:" "MySQL" "MariaDB")
    
    # Domain or IP setup
    SETUP_TYPE=$(select_option "Select setup type:" "Domain (with SSL)" "IP Address with Port")
    
    if [ "$SETUP_TYPE" = "Domain (with SSL)" ]; then
        while true; do
            read -p "Enter your domain name (e.g., example.com): " DOMAIN
            if [[ $DOMAIN =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\.[a-zA-Z]{2,}$ ]]; then
                break
            else
                echo "Invalid domain format. Please try again."
            fi
        done
        read -p "Enter your email for SSL certificate: " SSL_EMAIL
    else
        read -p "Enter port number (default: 8080): " APP_PORT
        APP_PORT=${APP_PORT:-8080}
    fi
    
    # Database credentials
    read -p "Enter MySQL root password: " -s DB_ROOT_PASSWORD
    echo
    read -p "Enter Laravel database name: " DB_NAME
    read -p "Enter Laravel database user: " DB_USER
    read -p "Enter Laravel database password: " -s DB_PASSWORD
    echo
    
    # Laravel project
    read -p "Enter Laravel project name: " PROJECT_NAME
    
    log "Configuration collected successfully!"
}

# Update system
update_system() {
    log "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release
}

# Install PHP
install_php() {
    log "Installing PHP $PHP_VERSION..."
    
    # Add Ondrej PPA for latest PHP versions
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt update
    
    # Install PHP and extensions
    sudo apt install -y php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-xml php${PHP_VERSION}-bcmath php${PHP_VERSION}-curl php${PHP_VERSION}-zip \
        php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-soap php${PHP_VERSION}-xmlrpc \
        php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-redis php${PHP_VERSION}-imagick php${PHP_VERSION}-dev
    
    # Configure PHP for production
    sudo sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sudo sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sudo sed -i 's/;opcache.enable=.*/opcache.enable=1/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sudo sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=128/' /etc/php/${PHP_VERSION}/fpm/php.ini
    
    sudo systemctl enable php${PHP_VERSION}-fpm
    sudo systemctl start php${PHP_VERSION}-fpm
    
    log "PHP $PHP_VERSION installed and configured"
}

# Install Composer
install_composer() {
    log "Installing Composer..."
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
    sudo chmod +x /usr/local/bin/composer
    log "Composer installed successfully"
}

# Install Node.js and npm
install_nodejs() {
    log "Installing Node.js and npm..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    log "Node.js $(node --version) and npm $(npm --version) installed"
}

# Install database
install_database() {
    log "Installing $DB_ENGINE..."
    
    if [ "$DB_ENGINE" = "MySQL" ]; then
        sudo apt install -y mysql-server
        sudo systemctl enable mysql
        sudo systemctl start mysql
        
        # Secure MySQL installation
        sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASSWORD';"
        sudo mysql -u root -p$DB_ROOT_PASSWORD -e "DELETE FROM mysql.user WHERE User='';"
        sudo mysql -u root -p$DB_ROOT_PASSWORD -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
        sudo mysql -u root -p$DB_ROOT_PASSWORD -e "DROP DATABASE IF EXISTS test;"
        sudo mysql -u root -p$DB_ROOT_PASSWORD -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
        sudo mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
    else
        sudo apt install -y mariadb-server
        sudo systemctl enable mariadb
        sudo systemctl start mariadb
        
        # Secure MariaDB installation
        sudo mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DB_ROOT_PASSWORD');"
        sudo mysql -u root -p$DB_ROOT_PASSWORD -e "DELETE FROM mysql.user WHERE User='';"
        sudo mysql -u root -p$DB_ROOT_PASSWORD -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
        sudo mysql -u root -p$DB_ROOT_PASSWORD -e "DROP DATABASE IF EXISTS test;"
        sudo mysql -u root -p$DB_ROOT_PASSWORD -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
        sudo mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
    fi
    
    # Create Laravel database and user
    sudo mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    sudo mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
    sudo mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    sudo mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
    
    log "$DB_ENGINE installed and configured"
}

# Install and configure Nginx
install_nginx() {
    log "Installing and configuring Nginx..."
    sudo apt install -y nginx
    
    # Remove default site
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Create Laravel site configuration
    if [ "$SETUP_TYPE" = "Domain (with SSL)" ]; then
        create_nginx_domain_config
    else
        create_nginx_ip_config
    fi
    
    sudo systemctl enable nginx
    sudo systemctl start nginx
    log "Nginx installed and configured"
}

# Install and configure Apache
install_apache() {
    log "Installing and configuring Apache..."
    sudo apt install -y apache2
    
    # Enable required modules
    sudo a2enmod rewrite ssl headers
    
    # Remove default site
    sudo a2dissite 000-default
    
    # Create Laravel site configuration
    if [ "$SETUP_TYPE" = "Domain (with SSL)" ]; then
        create_apache_domain_config
    else
        create_apache_ip_config
    fi
    
    sudo systemctl enable apache2
    sudo systemctl start apache2
    log "Apache installed and configured"
}

# Create Nginx configuration for domain
create_nginx_domain_config() {
    sudo tee /etc/nginx/sites-available/$PROJECT_NAME > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root /var/www/$PROJECT_NAME/public;
    index index.php index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss;
}
EOF
    
    sudo ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
}

# Create Nginx configuration for IP
create_nginx_ip_config() {
    sudo tee /etc/nginx/sites-available/$PROJECT_NAME > /dev/null <<EOF
server {
    listen $APP_PORT;
    root /var/www/$PROJECT_NAME/public;
    index index.php index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss;
}
EOF
    
    sudo ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
}

# Create Apache configuration for domain
create_apache_domain_config() {
    sudo tee /etc/apache2/sites-available/$PROJECT_NAME.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot /var/www/$PROJECT_NAME/public

    <Directory /var/www/$PROJECT_NAME/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Security headers
    Header always set X-Frame-Options SAMEORIGIN
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"

    ErrorLog \${APACHE_LOG_DIR}/${PROJECT_NAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${PROJECT_NAME}_access.log combined
</VirtualHost>
EOF
    
    sudo a2ensite $PROJECT_NAME.conf
}

# Create Apache configuration for IP
create_apache_ip_config() {
    sudo tee /etc/apache2/sites-available/$PROJECT_NAME.conf > /dev/null <<EOF
<VirtualHost *:$APP_PORT>
    DocumentRoot /var/www/$PROJECT_NAME/public

    <Directory /var/www/$PROJECT_NAME/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Security headers
    Header always set X-Frame-Options SAMEORIGIN
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"

    ErrorLog \${APACHE_LOG_DIR}/${PROJECT_NAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${PROJECT_NAME}_access.log combined
</VirtualHost>
EOF
    
    # Add Listen directive
    echo "Listen $APP_PORT" | sudo tee -a /etc/apache2/ports.conf
    sudo a2ensite $PROJECT_NAME.conf
}

# Install Git
install_git() {
    log "Installing Git..."
    sudo apt install -y git
    log "Git installed successfully"
}

# Install SSL certificate
install_ssl() {
    if [ "$SETUP_TYPE" = "Domain (with SSL)" ]; then
        log "Installing SSL certificate with Certbot..."
        sudo apt install -y certbot
        
        if [ "$WEB_SERVER" = "Nginx" ]; then
            sudo apt install -y python3-certbot-nginx
            sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --email $SSL_EMAIL --agree-tos --no-eff-email
        else
            sudo apt install -y python3-certbot-apache
            sudo certbot --apache -d $DOMAIN -d www.$DOMAIN --email $SSL_EMAIL --agree-tos --no-eff-email
        fi
        
        # Setup auto-renewal
        echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
        
        log "SSL certificate installed and auto-renewal configured"
    fi
}

# Create Laravel project
create_laravel_project() {
    log "Creating Laravel project..."
    
    # Create project directory
    sudo mkdir -p /var/www/$PROJECT_NAME
    cd /var/www
    
    # Install Laravel
    sudo composer create-project laravel/laravel $PROJECT_NAME --prefer-dist
    
    # Set permissions
    sudo chown -R www-data:www-data /var/www/$PROJECT_NAME
    sudo chmod -R 755 /var/www/$PROJECT_NAME
    sudo chmod -R 775 /var/www/$PROJECT_NAME/storage
    sudo chmod -R 775 /var/www/$PROJECT_NAME/bootstrap/cache
    
    # Configure .env file
    cd /var/www/$PROJECT_NAME
    sudo cp .env.example .env
    sudo sed -i "s/DB_DATABASE=laravel/DB_DATABASE=$DB_NAME/" .env
    sudo sed -i "s/DB_USERNAME=root/DB_USERNAME=$DB_USER/" .env
    sudo sed -i "s/DB_PASSWORD=/DB_PASSWORD=$DB_PASSWORD/" .env
    
    # Generate application key
    sudo php artisan key:generate
    
    # Run migrations
    sudo php artisan migrate
    
    # Optimize for production
    sudo php artisan config:cache
    sudo php artisan route:cache
    sudo php artisan view:cache
    
    log "Laravel project created and configured"
}

# Configure firewall
configure_firewall() {
    log "Configuring UFW firewall..."
    sudo ufw --force enable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    if [ "$SETUP_TYPE" = "IP Address with Port" ]; then
        sudo ufw allow $APP_PORT/tcp
    fi
    
    log "Firewall configured"
}

# Install Redis (optional but recommended)
install_redis() {
    log "Installing Redis..."
    sudo apt install -y redis-server
    sudo systemctl enable redis-server
    sudo systemctl start redis-server
    
    # Configure Redis for production
    sudo sed -i 's/# maxmemory <bytes>/maxmemory 256mb/' /etc/redis/redis.conf
    sudo sed -i 's/# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
    sudo systemctl restart redis-server
    
    log "Redis installed and configured"
}

# Final system optimization
optimize_system() {
    log "Applying system optimizations..."
    
    # Increase file limits
    echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
    
    # Configure swap if not exists
    if ! swapon --show | grep -q "/swapfile"; then
        sudo fallocate -l 1G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
    
    # Setup log rotation
    sudo tee /etc/logrotate.d/$PROJECT_NAME > /dev/null <<EOF
/var/www/$PROJECT_NAME/storage/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 www-data www-data
    sharedscripts
    postrotate
        /usr/bin/systemctl reload php${PHP_VERSION}-fpm > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log "System optimizations applied"
}

# Create deployment script
create_deployment_script() {
    log "Creating deployment script..."
    
    sudo tee /var/www/$PROJECT_NAME/deploy.sh > /dev/null <<EOF
#!/bin/bash
# Laravel Deployment Script

set -e

PROJECT_PATH="/var/www/$PROJECT_NAME"
cd \$PROJECT_PATH

echo "Starting deployment..."

# Put application in maintenance mode
php artisan down

# Pull latest changes
git pull origin main

# Install/update composer dependencies
composer install --no-dev --optimize-autoloader

# Install/update npm dependencies
npm install --production
npm run production

# Run database migrations
php artisan migrate --force

# Clear caches
php artisan config:clear
php artisan route:clear
php artisan view:clear

# Cache config, routes, and views
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Optimize autoloader
composer dump-autoload --optimize

# Set proper permissions
chown -R www-data:www-data \$PROJECT_PATH
chmod -R 755 \$PROJECT_PATH
chmod -R 775 \$PROJECT_PATH/storage
chmod -R 775 \$PROJECT_PATH/bootstrap/cache

# Restart services
systemctl restart php${PHP_VERSION}-fpm
systemctl restart ${WEB_SERVER,,}

# Bring application back online
php artisan up

echo "Deployment completed successfully!"
EOF
    
    sudo chmod +x /var/www/$PROJECT_NAME/deploy.sh
    sudo chown www-data:www-data /var/www/$PROJECT_NAME/deploy.sh
    
    log "Deployment script created at /var/www/$PROJECT_NAME/deploy.sh"
}

# Display final information
display_final_info() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                 🎉 SETUP COMPLETED SUCCESSFULLY! 🎉          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}📋 INSTALLATION SUMMARY:${NC}"
    echo -e "   • PHP Version: ${GREEN}$PHP_VERSION${NC}"
    echo -e "   • Web Server: ${GREEN}$WEB_SERVER${NC}"
    echo -e "   • Database: ${GREEN}$DB_ENGINE${NC}"
    echo -e "   • Project Name: ${GREEN}$PROJECT_NAME${NC}"
    echo
    echo -e "${BLUE}🌐 ACCESS INFORMATION:${NC}"
    if [ "$SETUP_TYPE" = "Domain (with SSL)" ]; then
        echo -e "   • Website URL: ${GREEN}https://$DOMAIN${NC}"
        echo -e "   • Alt URL: ${GREEN}https://www.$DOMAIN${NC}"
        echo -e "   • SSL Certificate: ${GREEN}Installed with auto-renewal${NC}"
    else
        SERVER_IP=$(curl -s ifconfig.me)
        echo -e "   • Website URL: ${GREEN}http://$SERVER_IP:$APP_PORT${NC}"
        echo -e "   • Port: ${GREEN}$APP_PORT${NC}"
    fi
    echo
    echo -e "${BLUE}🗃️ DATABASE INFORMATION:${NC}"
    echo -e "   • Database Name: ${GREEN}$DB_NAME${NC}"
    echo -e "   • Database User: ${GREEN}$DB_USER${NC}"
    echo -e "   • Root Password: ${GREEN}[HIDDEN]${NC}"
    echo
    echo -e "${BLUE}📁 PROJECT PATHS:${NC}"
    echo -e "   • Project Root: ${GREEN}/var/www/$PROJECT_NAME${NC}"
    echo -e "   • Public Directory: ${GREEN}/var/www/$PROJECT_NAME/public${NC}"
    echo -e "   • Logs: ${GREEN}/var/www/$PROJECT_NAME/storage/logs${NC}"
    echo
    echo -e "${BLUE}🔧 USEFUL COMMANDS:${NC}"
    echo -e "   • Restart PHP-FPM: ${GREEN}sudo systemctl restart php${PHP_VERSION}-fpm${NC}"
    echo -e "   • Restart $WEB_SERVER: ${GREEN}sudo systemctl restart ${WEB_SERVER,,}${NC}"
    echo -e "   • Laravel Artisan: ${GREEN}cd /var/www/$PROJECT_NAME && php artisan${NC}"
    echo -e "   • View Logs: ${GREEN}tail -f /var/www/$PROJECT_NAME/storage/logs/laravel.log${NC}"
    echo -e "   • Deploy Script: ${GREEN}/var/www/$PROJECT_NAME/deploy.sh${NC}"
    echo
    echo -e "${BLUE}🔐 SECURITY NOTES:${NC}"
    echo -e "   • Firewall is enabled with necessary ports open"
    echo -e "   • Database is secured with custom user credentials"
    echo -e "   • PHP is optimized for production"
    echo -e "   • File permissions are properly set"
    echo
    echo -e "${YELLOW}⚠️  NEXT STEPS:${NC}"
    echo -e "   1. Point your domain to this server's IP (if using domain)"
    echo -e "   2. Initialize your Git repository in /var/www/$PROJECT_NAME"
    echo -e "   3. Configure your Laravel application settings"
    echo -e "   4. Test your application thoroughly"
    echo -e "   5. Set up monitoring and backup solutions"
    echo
    echo -e "${GREEN}🎯 Happy coding with your new Laravel production server!${NC}"
}

# Main execution function
main() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🚀 VPS LARAVEL PRODUCTION SETUP SCRIPT 🚀                ║
║                                                              ║
║    This script will install and configure:                  ║
║    • PHP (8.1/8.2/8.3) + Extensions                        ║
║    • Laravel Framework                                       ║
║    • MySQL/MariaDB                                          ║
║    • Nginx/Apache                                           ║
║    • Git, Composer, Node.js                                 ║
║    • SSL Certificate (Let's Encrypt)                        ║
║    • Production optimizations                               ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    check_root
    check_os
    
    echo -e "\n${YELLOW}⚠️  WARNING: This script will make significant changes to your system.${NC}"
    echo -e "${YELLOW}   Make sure you have a backup and understand what will be installed.${NC}"
    echo
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 1
    fi
    
    get_user_inputs
    
    log "Starting VPS Laravel setup..."
    
    update_system
    install_php
    install_composer
    install_nodejs
    install_database
    install_git
    install_redis
    
    if [ "$WEB_SERVER" = "Nginx" ]; then
        install_nginx
    else
        install_apache
    fi
    
    create_laravel_project
    install_ssl
    configure_firewall
    optimize_system
    create_deployment_script
    
    # Restart all services
    sudo systemctl restart php${PHP_VERSION}-fpm
    sudo systemctl restart ${WEB_SERVER,,}
    
    display_final_info
}

# Run the main function
main "$@"