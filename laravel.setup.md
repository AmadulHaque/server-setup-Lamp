# Production-Ready VPS Setup for PHP, Laravel, MySQL, Git & Nginx

Here's a comprehensive guide to setting up a production-ready VPS for Laravel applications:

## 1. Initial Server Setup

### Connect to your VPS
```bash
ssh root@your_server_ip
```

### Create a new user (replace `deploy` with your preferred username)
```bash
adduser deploy
usermod -aG sudo deploy
```

### Set up SSH keys (on your local machine)
```bash
ssh-copy-id deploy@your_server_ip
```

### Disable root login and password authentication (edit `/etc/ssh/sshd_config`)
```
PermitRootLogin no
PasswordAuthentication no
```
```bash
sudo systemctl restart ssh
```

## 2. Install Essential Packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl unzip build-essential
```

## 3. Install Nginx

```bash
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

## 4. Install MySQL

```bash
sudo apt install -y mysql-server
sudo mysql_secure_installation
```

### Create a database user for your Laravel app
```bash
sudo mysql
```
```sql
CREATE DATABASE laravel_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'laravel_user'@'localhost' IDENTIFIED BY 'strong_password';
GRANT ALL PRIVILEGES ON laravel_db.* TO 'laravel_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

## 5. Install PHP and Extensions

```bash
sudo apt install -y php-fpm php-mysql php-mbstring php-xml php-bcmath php-curl php-zip php-gd
sudo systemctl start php-fpm
sudo systemctl enable php-fpm
```

## 6. Install Composer

```bash
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
```

## 7. Configure Nginx for Laravel

### Create a new Nginx configuration file
```bash
sudo nano /etc/nginx/sites-available/laravel
```

```nginx
server {
    listen 80;
    server_name your_domain.com;
    root /var/www/laravel/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";

    index index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### Enable the site
```bash
sudo ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 8. Deploy Your Laravel Application

### Create project directory
```bash
sudo mkdir -p /var/www/laravel
sudo chown -R deploy:deploy /var/www/laravel
```

### As the deploy user
```bash
sudo su - deploy
cd /var/www/laravel
```

### Clone your Laravel project
```bash
git clone your_repository_url .
composer install --optimize-autoloader --no-dev
```

### Set up environment file
```bash
cp .env.example .env
php artisan key:generate
```

### Configure .env file with your database credentials and other settings

### Set permissions
```bash
chmod -R 775 storage bootstrap/cache
```

## 9. Production Optimizations

### Cache routes and views
```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

### Set up queue workers (if needed)
```bash
sudo nano /etc/supervisor/conf.d/laravel-worker.conf
```
```
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/laravel/artisan queue:work --sleep=3 --tries=3
autostart=true
autorestart=true
user=deploy
numprocs=8
redirect_stderr=true
stdout_logfile=/var/www/laravel/storage/logs/worker.log
```
```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start laravel-worker:*
```

## 10. Secure Your Server with Let's Encrypt SSL

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your_domain.com
```

### Set up automatic renewal
```bash
sudo certbot renew --dry-run
```

## 11. Additional Security Hardening

### Configure firewall
```bash
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw enable
```

### Install fail2ban
```bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## 12. Set Up Automated Backups

Consider setting up regular backups for:
- Your database (using `mysqldump`)
- Your application files
- Your .env file

You can automate this with cron jobs or a backup service.

## Maintenance Tips

1. Keep your server updated regularly:
```bash
sudo apt update && sudo apt upgrade -y
```

2. Monitor your server resources:
```bash
htop
```

3. Check your Laravel logs:
```bash
tail -f /var/www/laravel/storage/logs/laravel.log
```

