#!/bin/bash -xe
# Startup script for jambonz Monitoring server on AWS (Large deployment)
# Handles Grafana, Homer, Jaeger, InfluxDB, Cassandra, HEPlify

# Variables passed from Terraform
URL_PORTAL="${url_portal}"
VPC_CIDR="${vpc_cidr}"

echo "Starting jambonz Monitoring server configuration for AWS large deployment"

# Detecting the Linux distribution
if grep -q 'ID="rhel"' /etc/os-release; then
    DEFAULT_USER=ec2-user
    NGINX_CONFIG=/etc/nginx/conf.d/default.conf

    echo "Restarting postgresql"
    systemctl restart postgresql-12

    echo "Disabling firewalld"
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
else
    DEFAULT_USER=admin
    NGINX_CONFIG=/etc/nginx/sites-available/default
fi

# Always use jambonz user for apps
USER=jambonz
HOME=/home/jambonz

# Sync SSH keys from default user to jambonz user
echo "Syncing SSH keys to jambonz user..."
if [ -f "/home/$DEFAULT_USER/.ssh/authorized_keys" ] && [ -s "/home/$DEFAULT_USER/.ssh/authorized_keys" ]; then
    mkdir -p /home/jambonz/.ssh
    cp "/home/$DEFAULT_USER/.ssh/authorized_keys" /home/jambonz/.ssh/
    chown -R jambonz:jambonz /home/jambonz/.ssh
    chmod 700 /home/jambonz/.ssh
    chmod 600 /home/jambonz/.ssh/authorized_keys
    echo "SSH keys copied from $DEFAULT_USER to jambonz"
else
    echo "Warning: No SSH keys found for $DEFAULT_USER"
fi

# Get instance metadata from AWS IMDSv2
echo "Getting instance metadata from AWS..."
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

echo "Public IP: $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"
echo "Instance ID: $INSTANCE_ID"

# Configure telegraf to send locally (this IS the monitoring server)
sudo sed -i -e "s/influxdb:8086/127.0.0.1:8086/g" /etc/telegraf/telegraf.conf
sudo systemctl restart telegraf

# Configure nginx (monitoring only: grafana, homer)
sudo tee $NGINX_CONFIG > /dev/null << EOF
server {
  listen 80;
  server_name grafana.$URL_PORTAL;
  location / {
    proxy_pass http://127.0.0.1:3010;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \\$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \\$host;
    proxy_cache_bypass \\$http_upgrade;
  }
}
server {
  listen 80;
  server_name homer.$URL_PORTAL;
  location / {
    proxy_pass http://127.0.0.1:9080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \\$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \\$host;
    proxy_cache_bypass \\$http_upgrade;
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
