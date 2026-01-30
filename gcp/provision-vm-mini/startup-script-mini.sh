#!/bin/bash -xe
# Startup script for jambonz Mini (all-in-one) server on GCP
# Runs all services locally: MySQL, Redis, SIP/RTP, Web, Monitoring

# Variables passed from Terraform
DB_PASSWORD="${db_password}"
JWT_SECRET="${jwt_secret}"
URL_PORTAL="${url_portal}"

FLAG_FILE="/var/lib/firstboot_completed"

if [ -f "$FLAG_FILE" ]; then
  echo "Not first boot. Skipping setup."
  exit 0
fi

echo "Running first boot setup..."

# Always use jambonz user for apps
USER=jambonz
HOME=/home/jambonz

# Stop services during configuration
systemctl stop jaeger-query || true
systemctl stop jaeger-collector || true
systemctl stop telegraf || true

# Install rtpengine kernel module and iptables rule
echo "Installing rtpengine kernel module and iptables rule..."
if lsmod | grep -q xt_RTPENGINE; then
  echo "xt_RTPENGINE module is already loaded."
else
  echo "Loading xt_RTPENGINE module."
  modprobe xt_RTPENGINE || true
  echo 'add 42' > /proc/rtpengine/control || true
  iptables -I INPUT -p udp --dport 40000:60000 -j RTPENGINE --id 42 || true
fi
echo "rtpengine module and iptables rule installed. Restarting rtpengine service."
systemctl restart rtpengine || true

# Get instance metadata from GCP Metadata Service
echo "Getting instance metadata from GCP..."
PRIVATE_IP=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/ip 2>/dev/null || hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || curl -s https://api.ipify.org)
INSTANCE_ID=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/name 2>/dev/null || hostname)

echo "Public IP: $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"
echo "Instance ID: $INSTANCE_ID"

# Change the database password
echo "Resetting database password..."
echo "alter user 'admin'@'%' identified by '$DB_PASSWORD'" | mysql -h 127.0.0.1 -u admin -D jambones -pJambonzR0ck$ || true
echo "Database password reset complete"

# Update ecosystem.config.js with database password
sudo sed -i -e "s/\(.*\)JAMBONES_MYSQL_PASSWORD.*/\1JAMBONES_MYSQL_PASSWORD: '$DB_PASSWORD',/g" $HOME/apps/ecosystem.config.js

# Replace IP addresses in ecosystem.config.js
sudo sed -i -e "s/\(.*\)PRIVATE_IP\(.*\)/\1$PRIVATE_IP\2/g" $HOME/apps/ecosystem.config.js

# Replace JWT_SECRET
sudo sed -i -e "s/\(.*\)JWT-SECRET-GOES_HERE\(.*\)/\1$JWT_SECRET\2/g" $HOME/apps/ecosystem.config.js

# Reset admin password to instance ID (user will be forced to change on first login)
echo "Resetting admin password to instance ID..."
JAMBONES_ADMIN_INITIAL_PASSWORD=$INSTANCE_ID \
JAMBONES_MYSQL_USER=admin \
JAMBONES_MYSQL_PASSWORD=$DB_PASSWORD \
JAMBONES_MYSQL_DATABASE=jambones \
JAMBONES_MYSQL_HOST=127.0.0.1 \
$HOME/apps/jambonz-api-server/db/reset_admin_password.js || true

# Configure webapp and nginx based on whether dns_name is provided
if [[ -z "$URL_PORTAL" ]]; then
  # Portals will be accessed by IP address
  echo "Configuring for IP-based access..."
  echo "VITE_API_BASE_URL=http://$PUBLIC_IP/api/v1" > $HOME/apps/jambonz-webapp/.env
  API_BASE_URL="http://$PUBLIC_IP/api/v1"
  TAG="<script>window.JAMBONZ = { API_BASE_URL: '$API_BASE_URL'};</script>"
  sed -i -e "\\@</head>@i\\ $TAG" $HOME/apps/jambonz-webapp/dist/index.html || true

  # Update JAMBONES_API_BASE_URL in ecosystem.config.js
  sudo sed -i -e "s/\(.*\)--JAMBONES_API_BASE_URL--\(.*\)/\1http:\/\/$PUBLIC_IP\/v1\2/g" $HOME/apps/ecosystem.config.js
else
  # Portals will be accessed by DNS name
  echo "Configuring for DNS-based access: $URL_PORTAL"
  echo "VITE_API_BASE_URL=http://$URL_PORTAL/api/v1" > $HOME/apps/jambonz-webapp/.env
  API_BASE_URL="http://$URL_PORTAL/api/v1"
  TAG="<script>window.JAMBONZ = { API_BASE_URL: '$API_BASE_URL'};</script>"
  sed -i -e "\\@</head>@i\\ $TAG" $HOME/apps/jambonz-webapp/dist/index.html || true

  # Update JAMBONES_API_BASE_URL in ecosystem.config.js
  sudo sed -i -e "s/\(.*\)--JAMBONES_API_BASE_URL--\(.*\)/\1http:\/\/$URL_PORTAL\/v1\2/g" $HOME/apps/ecosystem.config.js

  # Add row to system information table
  mysql -h 127.0.0.1 -u admin -D jambones -p$DB_PASSWORD -e "insert into system_information (domain_name, sip_domain_name, monitoring_domain_name) values ('$URL_PORTAL', 'sip.$URL_PORTAL', 'grafana.$URL_PORTAL')" || true

  # Determine nginx config path
  if [ -f /etc/nginx/sites-available/default ]; then
      NGINX_CONFIG=/etc/nginx/sites-available/default
  else
      NGINX_CONFIG=/etc/nginx/conf.d/default.conf
  fi

  # Configure nginx for domain-based access
  sudo cat << EOF > $NGINX_CONFIG
server {
    listen 80;
    server_name $URL_PORTAL;
    location /api/ {
        rewrite ^/api/(.*)$ /\$1 break;
        proxy_pass http://localhost:3002;
        proxy_set_header Host \$host;
    }
    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host \$host;
    }
}
server {
    listen 80;
    server_name api.$URL_PORTAL;
    location / {
        proxy_pass http://localhost:3002;
        proxy_set_header Host \$host;
    }
}
server {
  listen 80;
  server_name grafana.$URL_PORTAL;
  location / {
    proxy_pass http://127.0.0.1:3010;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_cache_bypass \$http_upgrade;
  }
}
server {
  listen 80;
  server_name homer.$URL_PORTAL;
  location / {
    proxy_pass http://127.0.0.1:9080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_cache_bypass \$http_upgrade;
  }
}
EOF
  sudo systemctl restart nginx
fi

# Restart heplify-server
sudo systemctl restart heplify-server || true

# Restart cassandra and wait for it to start
echo "Restarting cassandra..."
sudo systemctl restart cassandra.service || true
echo "Waiting 60 seconds for cassandra to start..."
sleep 60

# Restart jaeger
echo "Restarting jaeger..."
sudo systemctl restart jaeger-collector.service || true
sudo systemctl restart jaeger-query.service || true

# Configure telegraf to send to local influxdb
sudo sed -i -e "s/influxdb:8086/127.0.0.1:8086/g" /etc/telegraf/telegraf.conf
sudo systemctl restart telegraf

# Start PM2 apps
echo "Starting jambonz apps..."
sudo -u $USER bash -c "pm2 restart $HOME/apps/ecosystem.config.js"
sudo -u $USER bash -c "pm2 save"
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME
sudo systemctl enable pm2-$USER.service

# Configure upload_recordings service
sudo sed -i -e "s/MYSQL_HOST=/MYSQL_HOST=127.0.0.1/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/MYSQL_USER=/MYSQL_USER=admin/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/MYSQL_PASSWORD=/MYSQL_PASSWORD=$DB_PASSWORD/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/MYSQL_DATABASE=/MYSQL_DATABASE=jambones/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/BASIC_AUTH_USERNAME=/BASIC_AUTH_USERNAME=jambonz/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/BASIC_AUTH_PASSWORD=/BASIC_AUTH_PASSWORD=$JWT_SECRET/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/ENCRYPTION_SECRET=/ENCRYPTION_SECRET=$JWT_SECRET/g" /etc/systemd/system/upload_recordings.service

sudo systemctl daemon-reload
sudo systemctl enable upload_recordings
sudo systemctl start upload_recordings

# Configure APIBan - supports two modes:
# 1. Client credentials mode: auto-provision unique key per instance (preferred)
# 2. Single key mode: use customer-provided key
APIBAN_KEY="${apiban_key}"
APIBAN_CLIENT_ID="${apiban_client_id}"
APIBAN_CLIENT_SECRET="${apiban_client_secret}"

if [ -n "$APIBAN_CLIENT_ID" ] && [ -n "$APIBAN_CLIENT_SECRET" ]; then
    echo "Provisioning APIBan key via client credentials..."
    APIBANKEY=$(curl -X POST -u "$APIBAN_CLIENT_ID:$APIBAN_CLIENT_SECRET" \
        -d "{\"client\": \"$INSTANCE_ID\"}" \
        -s https://apiban.org/sponsor/newkey | jq -r '.ApiKey' 2>/dev/null || echo "")
    if [ -n "$APIBANKEY" ] && [ "$APIBANKEY" != "null" ] && [ -f /usr/local/bin/apiban/config.json ]; then
        sudo sed -i -e "s/API-KEY-HERE/$APIBANKEY/g" /usr/local/bin/apiban/config.json
        sudo /usr/local/bin/apiban/apiban-client-nftables FULL || true
    else
        echo "Failed to provision APIBan key via client credentials"
    fi
elif [ -n "$APIBAN_KEY" ] && [ -f /usr/local/bin/apiban/config.json ]; then
    echo "Configuring APIBan with provided key..."
    sudo sed -i -e "s/API-KEY-HERE/$APIBAN_KEY/g" /usr/local/bin/apiban/config.json
    sudo /usr/local/bin/apiban/apiban-client-nftables FULL || true
else
    echo "Skipping APIBan configuration (no credentials provided)"
fi

# Create the flag file to indicate first boot has completed
touch "$FLAG_FILE"
echo "First boot setup completed."
echo "Mini server setup complete!"
