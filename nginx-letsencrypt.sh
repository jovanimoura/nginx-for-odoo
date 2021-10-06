#!/usr/bin/env bash

# Variables that helps to print
D="\n#######"
N="#######\n"
DONE="######DONE#######\n"
DOMAIN=$1
EMAIL="admin@$DOMAIN"

# Installing certbot and config domain
printf "$D Installing certbot $N"
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository universe
sudo add-apt-repository ppa:certbot/certbot
sudo app update && sudo apt -y upgrade
sudo apt install -y python-certbot-nginx
printf "$DONE"


# Intalling nginx and conf files
printf "$D Installing Nginx $N"
sudo apt install -y nginx
printf "$DONE"

function nginx_conf {
    	local config="/etc/nginx/sites-available/${DOMAIN}"
	sudo cat <<EOF > $config

# ODOO SERVER
upstream odoo {
    server 127.0.0.1:8069;
}

upstream odoochat {
    server 127.0.0.1:8072;
}

# HTTP -> HTTPS
server {
    listen 80;
    server_name $DOMAIN;
    rewrite ^(.*) https://\$host\$1 permanent;
}

# WWW -> NON WWW # Dani and Odoo12 Dev Cookbook
server {
    listen 443;
    server_name $DOMAIN
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    client_max_body_size 2048M;
    large_client_header_buffers 4 32k;

    # Add Headers for odoo proxy mode - Dani and cookbooks
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    # SSL parameters
    ssl on;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;


    # LOG - Dani and Cookbook
    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;

    # Redirect requests to odoo backend server on 8069 - Dani and Cookbook
    location / {
        proxy_redirect off;
        proxy_pass http://odoo;
    }

    # Manage longpooling on 8072 port - Cookbook and Dani
    location /longpolling {
        proxy_pass http://odoochat;
    }

    # Enablig static cache
      location ~* /web/static/ {
        proxy_cache_valid 200 60m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo;
      }

    # enable gzip - cookbook
    gzip on;
    gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
}
EOF
}

# Calling nginx conf
nginx_conf


printf "$D Running Certbot and making certificate for $DOMAIN $N"
certbot run --nginx --agree-tos --no-eff-email -m $EMAIL -d $DOMAIN
printf "$DONE"


# Making symbolic link in nginx files
printf "$D Making symbolic link in nginx files $N"
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
printf "$DONE"


# Removing default config on Nginx
printf "$D Removing default config on Nginx $N"
rm /etc/nginx/sites-enabled/default
printf "$DONE"

# cron for renew certbot
printf "$D Making cron for certbot renew $N"
function renew_certbot {
        local renewcertbot="/etc/cron.d/letsencrypt"
        sudo cat <<EOF > $renewcertbot
0 21 * * 5 certbot renew && systemctl reload nginx
EOF
}
# Calling function
renew_certbot

printf "$DONE"
printf "$D Quase lá... $N"

# Checking Nginx Status
printf "$D Checking Nginx Status $N"
sudo systemctl reload nginx
printf "$DONE"

printf "$D All Done... claps... $N"

