#!/bin/bash -xe
# Startup script for jambonz Monitoring server on GCP (Large deployment)
# Handles Grafana, Homer, Jaeger, InfluxDB, Cassandra, HEPlify

# Variables passed from Terraform
URL_PORTAL="${url_portal}"
VPC_CIDR="${vpc_cidr}"

echo "Starting jambonz Monitoring server configuration for GCP large deployment"

# Get instance metadata from GCP Metadata Service
echo "Getting instance metadata from GCP..."
PRIVATE_IP=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/ip 2>/dev/null || hostname -I | awk '{print $1}')
INSTANCE_ID=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/id 2>/dev/null || hostname)

# Get the public IP
PUBLIC_IP=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || curl -s https://api.ipify.org)

echo "Public IP: $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"
echo "Instance ID: $INSTANCE_ID"

# Configure telegraf to send locally (this IS the monitoring server)
sudo sed -i -e "s/influxdb:8086/127.0.0.1:8086/g" /etc/telegraf/telegraf.conf
sudo systemctl restart telegraf

# Determine nginx config path
if [ -f /etc/nginx/sites-available/default ]; then
    NGINX_CONFIG=/etc/nginx/sites-available/default
else
    NGINX_CONFIG=/etc/nginx/conf.d/default.conf
fi

# Configure nginx (monitoring only: grafana, homer)
sudo cat << EOF > $NGINX_CONFIG
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

# Start/restart HEPlify server (receives HEP packets from SIP/RTP servers)
sudo systemctl restart heplify-server.service || true

# Restart cassandra and give it time to come up
echo "Restarting cassandra..."
sudo systemctl restart cassandra.service || true
sleep 60
echo "Restarting jaeger"
sudo systemctl restart jaeger-collector.service || true
sudo systemctl restart jaeger-query.service || true

echo "Monitoring server setup complete!"
