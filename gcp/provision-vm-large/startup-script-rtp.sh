#!/bin/bash -xe
# Startup script for jambonz RTP server on GCP (Large deployment)
# Handles RTPEngine and RTP-related sidecars only (no Drachtio)

# Variables passed from Terraform
MONITORING_PRIVATE_IP="${monitoring_private_ip}"
VPC_CIDR="${vpc_cidr}"
ENABLE_PCAPS="${enable_pcaps}"

echo "Starting jambonz RTP server configuration for GCP large deployment"

# Always use jambonz user for apps
USER=jambonz
HOME=/home/jambonz

sudo systemctl stop rtpengine || true

# Get instance metadata from GCP Metadata Service
echo "Getting instance metadata from GCP..."
PRIVATE_IP=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/ip 2>/dev/null || hostname -I | awk '{print $1}')
INSTANCE_ID=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/id 2>/dev/null || hostname)

# Get the public IP
PUBLIC_IP=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || curl -s https://api.ipify.org)

echo "Private IP: $PRIVATE_IP"
echo "Public IP: $PUBLIC_IP"
echo "Instance ID: $INSTANCE_ID"

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
      DTMF_ONLY: true,
      RTPENGINE_DTMF_LOG_PORT: 22223,
      ENABLE_METRICS: 1,
      STATS_HOST: '127.0.0.1',
      STATS_PORT: 8125,
      STATS_PROTOCOL: 'tcp',
      STATS_SAMPLE_RATE:1,
      STATS_TELEGRAF: 1
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
