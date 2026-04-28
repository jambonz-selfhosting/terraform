#!/bin/bash -xe
# Startup script for jambonz RTP server on AWS (Large deployment)
# Handles RTPEngine and RTP-related sidecars

# Variables passed from Terraform
MONITORING_PRIVATE_IP="${monitoring_private_ip}"
VPC_CIDR="${vpc_cidr}"
ENABLE_PCAPS="${enable_pcaps}"
REDIS_HOST="${redis_host}"
REDIS_PORT="${redis_port}"

echo "Starting jambonz RTP server configuration for AWS large deployment"

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

sudo systemctl stop rtpengine || true

# Get instance metadata from AWS IMDSv2
echo "Getting instance metadata from AWS..."
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

echo "Public IP: $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"
echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"

echo "Writing $HOME/apps/ecosystem.config.js..."
cat << EOF > $HOME/apps/ecosystem.config.js
module.exports = {
  apps : [
  {
    name: 'sbc-rtpengine-sidecar',
    cwd: '$HOME/apps/sbc-rtpengine-sidecar',
    script: 'app.js',
    instance_var: 'INSTANCE_ID',
    out_file: '$HOME/.pm2/logs/sbc-rtpengine-sidecar.log',
    err_file: '$HOME/.pm2/logs/sbc-rtpengine-sidecar.log',
    exec_mode: 'fork',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      LOGLEVEL: 'info',
      RTPENGINE_DTMF_LOG_PORT: 22223,
      ENABLE_METRICS: 1,
      STATS_HOST: '127.0.0.1',
      STATS_PORT: 8125,
      STATS_PROTOCOL: 'tcp',
      STATS_SAMPLE_RATE: 1,
      STATS_TELEGRAF: 1,
      JAMBONES_REDIS_HOST: '$REDIS_HOST',
      JAMBONES_REDIS_PORT: $REDIS_PORT
    }
  }
  ]
};
EOF
echo "Finished writing config file"

echo "Restarting telegraf"
# Configure telegraf to send to the monitoring server
sudo sed -i -e "s/influxdb:8086/$MONITORING_PRIVATE_IP:8086/g" /etc/telegraf/telegraf.conf
sudo systemctl restart telegraf

# Point rtpengine to the HEP endpoint on the monitoring server
if [[ "$ENABLE_PCAPS" == "true" ]]; then
  echo "Enabling PCAPs"
  sudo sed -i -e "s/--delete-delay 0/--delete-delay 0 --homer=$MONITORING_PRIVATE_IP:9060 --homer-protocol=udp --homer-id=11/g" /etc/systemd/system/rtpengine.service
fi

sudo systemctl daemon-reload
sudo systemctl restart rtpengine

echo "Starting jambonz apps"
sudo -u $USER bash -c "pm2 restart $HOME/apps/ecosystem.config.js"
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME
sudo -u $USER bash -c "pm2 save"
sudo systemctl enable pm2-$USER.service

echo "RTP server setup complete!"
