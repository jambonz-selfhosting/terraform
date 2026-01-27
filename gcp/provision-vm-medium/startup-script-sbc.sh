#!/bin/bash -xe
# Startup script for jambonz SBC server on GCP

# Variables passed from Terraform
MYSQL_HOST="${mysql_host}"
MYSQL_USER="${mysql_user}"
MYSQL_PASSWORD="${mysql_password}"
REDIS_HOST="${redis_host}"
REDIS_PORT="${redis_port}"
JWT_SECRET="${jwt_secret}"
WEB_MONITORING_PRIVATE_IP="${web_monitoring_private_ip}"
VPC_CIDR="${vpc_cidr}"
ENABLE_PCAPS="${enable_pcaps}"

echo "Starting jambonz SBC server configuration for GCP deployment"

# Always use jambonz user for apps
USER=jambonz
HOME=/home/jambonz

sudo systemctl stop rtpengine || true
sudo systemctl stop drachtio || true

# Get instance metadata from GCP Metadata Service
echo "Getting instance metadata from GCP..."
PRIVATE_IP=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/ip 2>/dev/null || hostname -I | awk '{print $1}')
INSTANCE_ID=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/id 2>/dev/null || hostname)

# Get the public IP
PUBLIC_IP=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || curl -s https://api.ipify.org)

echo "Private IP: $PRIVATE_IP"
echo "Public IP: $PUBLIC_IP"
echo "Instance ID: $INSTANCE_ID"

# Configure drachtio service
sudo sed -i -e "s/MYSQL_HOST=/MYSQL_HOST=$MYSQL_HOST/g" /etc/systemd/system/drachtio.service
sudo sed -i -e "s/MYSQL_USER=/MYSQL_USER=$MYSQL_USER/g" /etc/systemd/system/drachtio.service
sudo sed -i -e "s/MYSQL_PASSWORD=/MYSQL_PASSWORD=$MYSQL_PASSWORD/g" /etc/systemd/system/drachtio.service
sudo sed -i -e "s/MYSQL_DATABASE=/MYSQL_DATABASE=jambones/g" /etc/systemd/system/drachtio.service
sudo sed -i -e "s/JAMBONES_REDIS_HOST=/JAMBONES_REDIS_HOST=$REDIS_HOST/g" /etc/systemd/system/drachtio.service
sudo sed -i -e "s/JAMBONES_REDIS_PORT=/JAMBONES_REDIS_PORT=$REDIS_PORT/g" /etc/systemd/system/drachtio.service

echo "Writing $HOME/apps/ecosystem.config.js..."
cat << EOF > $HOME/apps/ecosystem.config.js
module.exports = {
  apps : [
  {
    name: 'sbc-sip-sidecar',
    cwd: '$HOME/apps/sbc-sip-sidecar',
    script: 'app.js',
    instance_var: 'INSTANCE_ID',
    out_file: '$HOME/.pm2/logs/sbc-sip-sidecar.log',
    err_file: '$HOME/.pm2/logs/sbc-sip-sidecar.log',
    exec_mode: 'fork',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '2G',
    env: {
      JAMBONES_LOGLEVEL: 'info',
      JWT_SECRET: '$JWT_SECRET',
      RTPENGINE_PING_INTERVAL: 30000,
      DRACHTIO_HOST: '127.0.0.1',
      DRACHTIO_PORT: 9022,
      DRACHTIO_SECRET: 'cymru',
      JAMBONES_MYSQL_HOST: '$MYSQL_HOST',
      JAMBONES_MYSQL_USER: '$MYSQL_USER',
      JAMBONES_MYSQL_PASSWORD: '$MYSQL_PASSWORD',
      JAMBONES_MYSQL_DATABASE: 'jambones',
      JAMBONES_MYSQL_CONNECTION_LIMIT: 10,
      JAMBONES_REDIS_HOST: '$REDIS_HOST',
      JAMBONES_REDIS_PORT: $REDIS_PORT,
      JAMBONES_TIME_SERIES_HOST: '$WEB_MONITORING_PRIVATE_IP',
      ENABLE_METRICS: 1,
      STATS_HOST: '127.0.0.1',
      STATS_PORT: 8125,
      STATS_PROTOCOL: 'tcp',
      STATS_TELEGRAF: 1,
      STATS_SAMPLE_RATE: 1,
      JAMBONES_NETWORK_CIDR: '$VPC_CIDR'
    }
  },
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
  },
  {
    name: 'sbc-call-router',
    cwd: '$HOME/apps/sbc-call-router',
    script: 'app.js',
    instance_var: 'INSTANCE_ID',
    out_file: '$HOME/.pm2/logs/sbc-call-router.log',
    err_file: '$HOME/.pm2/logs/sbc-call-router.log',
    exec_mode: 'fork',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      JAMBONES_LOGLEVEL: 'info',
      HTTP_PORT: 4000,
      JAMBONES_INBOUND_ROUTE: '127.0.0.1:4002',
      JAMBONES_OUTBOUND_ROUTE: '127.0.0.1:4003',
      JAMBONZ_TAGGED_INBOUND: 1,
      ENABLE_METRICS: 1,
      STATS_HOST: '127.0.0.1',
      STATS_PORT: 8125,
      STATS_PROTOCOL: 'tcp',
      STATS_TELEGRAF: 1,
      STATS_SAMPLE_RATE: 1,
      JAMBONES_NETWORK_CIDR: '$VPC_CIDR'
    }
  },
  {
    name: 'outbound',
    cwd: '$HOME/apps/outbound',
    script: 'app.js',
    instance_var: 'INSTANCE_ID',
    out_file: '$HOME/.pm2/logs/outbound.log',
    err_file: '$HOME/.pm2/logs/outbound.log',
    exec_mode: 'fork',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '3G',
    env: {
      JAMBONES_LOGLEVEL: 'info',
      JWT_SECRET: '$JWT_SECRET',
      JAMBONES_NETWORK_CIDR: '$VPC_CIDR',
      JAMBONES_RTPENGINE_INJECT_DTMF_ALWAYS: 0,
      JAMBONES_RTPENGINE_UDP_PORT: 6000,
      JAMBONES_RTPENGINES: '127.0.0.1:22222',
      MIN_CALL_LIMIT: 9999,
      RTPENGINE_PING_INTERVAL: 30000,
      DRACHTIO_HOST: '127.0.0.1',
      DRACHTIO_PORT: 9022,
      DRACHTIO_SECRET: 'cymru',
      JAMBONES_MYSQL_HOST: '$MYSQL_HOST',
      JAMBONES_MYSQL_USER: '$MYSQL_USER',
      JAMBONES_MYSQL_PASSWORD: '$MYSQL_PASSWORD',
      JAMBONES_MYSQL_DATABASE: 'jambones',
      JAMBONES_MYSQL_CONNECTION_LIMIT: 10,
      JAMBONES_REDIS_HOST: '$REDIS_HOST',
      JAMBONES_REDIS_PORT: $REDIS_PORT,
      JAMBONES_TIME_SERIES_HOST: '$WEB_MONITORING_PRIVATE_IP',
      JAMBONES_TRACK_ACCOUNT_CALLS: 0,
      JAMBONES_TRACK_SP_CALLS: 0,
      JAMBONES_TRACK_APP_CALLS: 0,
      ENABLE_METRICS: 1,
      STATS_HOST: '127.0.0.1',
      STATS_PORT: 8125,
      STATS_PROTOCOL: 'tcp',
      STATS_SAMPLE_RATE:1,
      STATS_TELEGRAF: 1
    }
  },
  {
    name: 'inbound',
    cwd: '$HOME/apps/inbound',
    script: 'app.js',
    instance_var: 'INSTANCE_ID',
    out_file: '$HOME/.pm2/logs/inbound.log',
    err_file: '$HOME/.pm2/logs/inbound.log',
    exec_mode: 'fork',
    instances: 'max',
    autorestart: true,
    watch: false,
    max_memory_restart: '3G',
    env: {
      JAMBONES_LOGLEVEL: 'info',
      JWT_SECRET: '$JWT_SECRET',
      JAMBONES_NETWORK_CIDR: '$VPC_CIDR',
      JAMBONES_RTPENGINE_INJECT_DTMF_ALWAYS: 0,
      JAMBONES_RTPENGINE_UDP_PORT: 7000,
      JAMBONES_RTPENGINES: '127.0.0.1:22222',
      DRACHTIO_HOST: '127.0.0.1',
      DRACHTIO_PORT: 9022,
      DRACHTIO_SECRET: 'cymru',
      HTTP_PORT: 3000,
      HTTP_PORT_MAX: 3009,
      JAMBONES_MYSQL_HOST: '$MYSQL_HOST',
      JAMBONES_MYSQL_USER: '$MYSQL_USER',
      JAMBONES_MYSQL_PASSWORD: '$MYSQL_PASSWORD',
      JAMBONES_MYSQL_DATABASE: 'jambones',
      JAMBONES_MYSQL_CONNECTION_LIMIT: 10,
      JAMBONES_REDIS_HOST: '$REDIS_HOST',
      JAMBONES_REDIS_PORT: $REDIS_PORT,
      JAMBONES_TIME_SERIES_HOST: '$WEB_MONITORING_PRIVATE_IP',
      ENABLE_METRICS: 1,
      JAMBONES_TRACK_ACCOUNT_CALLS: 0,
      JAMBONES_TRACK_SP_CALLS: 0,
      JAMBONES_TRACK_APP_CALLS: 0,
      STATS_HOST: '127.0.0.1',
      STATS_PORT: 8125,
      STATS_PROTOCOL: 'tcp',
      STATS_TELEGRAF: 1,
      STATS_SAMPLE_RATE: 1,
      MS_TEAMS_SIP_PROXY_IPS: '52.114.148.0, 52.114.132.46, 52.114.75.24, 52.114.76.76, 52.114.7.24, 52.114.14.70'
    }
  }
  ]
};
EOF
echo "Finished writing config file"

echo "Restarting telegraf"
# Configure telegraf to send to the monitoring server
sudo sed -i -e "s/influxdb:8086/$WEB_MONITORING_PRIVATE_IP:8086/g" /etc/telegraf/telegraf.conf
sudo systemctl restart telegraf

# Point rtpengine to the HEP endpoint on the monitoring server
if [[ "$ENABLE_PCAPS" == "true" ]]; then
  echo "Enabling PCAPs"
  sudo sed -i -e "s/--delete-delay 0/--delete-delay 0 --homer=$WEB_MONITORING_PRIVATE_IP:9060 --homer-protocol=udp --homer-id=11/g" /etc/systemd/system/rtpengine.service
  sudo sed -i -e "s/--address 0.0.0.0 --port 9022/--address 0.0.0.0 --port 9022 --homer $WEB_MONITORING_PRIVATE_IP:9060 --homer-id 10/g" /etc/systemd/system/drachtio.service
fi

# Point drachtio to the HEP endpoint on the monitoring server
sudo sed -i "s/--homer 127.0.0.1:9060/--homer $WEB_MONITORING_PRIVATE_IP:9060/g" /etc/systemd/system/drachtio.service

sudo systemctl daemon-reload
sudo systemctl restart rtpengine
sudo systemctl restart drachtio

echo "Starting jambonz apps"
sudo -u $USER bash -c "pm2 restart $HOME/apps/ecosystem.config.js"
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME
sudo -u $USER bash -c "pm2 save"
sudo systemctl enable pm2-$USER.service

# Configure apiban if key is provided
APIBAN_KEY="${apiban_key}"
if [ -n "$APIBAN_KEY" ] && [ -f /usr/local/bin/apiban/config.json ]; then
    echo "Configuring APIBan with provided key..."
    sudo sed -i -e "s/API-KEY-HERE/$APIBAN_KEY/g" /usr/local/bin/apiban/config.json
    sudo /usr/local/bin/apiban/apiban-client-nftables FULL || true
else
    echo "Skipping APIBan configuration (no key provided)"
fi

echo "SBC server setup complete!"