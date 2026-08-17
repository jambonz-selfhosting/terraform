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


# nginx deliberately does NOT run on the monitoring host in a large
# deployment -- it runs on the web host, which already proxies
# grafana.<portal> -> monitoring:3010 and homer.<portal> -> monitoring:9080
# (see startup-script-web.sh). Writing an nginx config here targeted a
# package that is not installed: neither /etc/nginx/sites-available/default
# nor /etc/nginx/conf.d/ exists, so the redirect failed and -- because this
# script runs under `bash -xe` -- aborted provisioning before heplify-server,
# cassandra and jaeger were restarted.

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
