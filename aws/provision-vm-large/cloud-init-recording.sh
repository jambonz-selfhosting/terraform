#!/bin/bash -xe
# Startup script for jambonz Recording Server on AWS (Large deployment)

# Variables passed from Terraform
MYSQL_HOST="${mysql_host}"
MYSQL_USER="${mysql_user}"
MYSQL_PASSWORD="${mysql_password}"
JWT_SECRET="${jwt_secret}"
MONITORING_PRIVATE_IP="${monitoring_private_ip}"

echo "Starting jambonz Recording Server configuration for AWS large deployment"

# Detecting the Linux distribution
if grep -q 'ID="rhel"' /etc/os-release; then
    DEFAULT_USER=ec2-user

    echo "Disabling firewalld"
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
else
    DEFAULT_USER=admin
fi

# Always use jambonz user for apps
USER=jambonz
HOME=/home/jambonz

# Sync SSH keys from default user to jambonz user
echo "Syncing SSH keys to jambonz user..."
if [ -f "/home/$DEFAULT_USER/.ssh/authorized_keys" ] && [ -s "/home/$DEFAULT_USER/.ssh/authorized_keys" ] && [ "$DEFAULT_USER" != "jambonz" ]; then
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
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

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
