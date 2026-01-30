#!/bin/bash -xe
# Startup script for jambonz Recording Server on GCP (Large deployment)

# Variables passed from Terraform
MYSQL_HOST="${mysql_host}"
MYSQL_USER="${mysql_user}"
MYSQL_PASSWORD="${mysql_password}"
JWT_SECRET="${jwt_secret}"
MONITORING_PRIVATE_IP="${monitoring_private_ip}"

echo "Starting jambonz Recording Server configuration for GCP large deployment"

# Always use jambonz user for apps
USER=jambonz
HOME=/home/jambonz

# Get instance metadata from GCP Metadata Service
echo "Getting instance metadata from GCP..."
INSTANCE_ID=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/id 2>/dev/null || hostname)

echo "Instance ID: $INSTANCE_ID"

# Configure upload_recordings service
echo "Configuring upload_recordings service"
sudo sed -i -e "s/MYSQL_HOST=/MYSQL_HOST=$MYSQL_HOST/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/MYSQL_USER=/MYSQL_USER=$MYSQL_USER/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/MYSQL_PASSWORD=/MYSQL_PASSWORD=$MYSQL_PASSWORD/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/MYSQL_DATABASE=/MYSQL_DATABASE=jambones/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/BASIC_AUTH_USERNAME=/BASIC_AUTH_USERNAME=jambonz/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/BASIC_AUTH_PASSWORD=/BASIC_AUTH_PASSWORD=$JWT_SECRET/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/ENCRYPTION_SECRET=/ENCRYPTION_SECRET=$JWT_SECRET/g" /etc/systemd/system/upload_recordings.service
sudo sed -i -e "s/--port 3017/--port 3000/g" /etc/systemd/system/upload_recordings.service

# Insert the LD_LIBRARY_PATH environment variable into the [Service] section
sudo sed -i '/\[Service\]/a Environment=LD_LIBRARY_PATH=\/usr\/local\/lib' /etc/systemd/system/upload_recordings.service

sudo systemctl daemon-reload
sudo systemctl enable upload_recordings
sudo systemctl start upload_recordings

# Configure telegraf to send to the monitoring server
sudo sed -i -e "s/influxdb:8086/$MONITORING_PRIVATE_IP:8086/g" /etc/telegraf/telegraf.conf
sudo systemctl restart telegraf

echo "Recording Server setup complete!"
