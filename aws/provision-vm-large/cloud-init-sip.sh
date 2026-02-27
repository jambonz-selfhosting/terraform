#!/bin/bash -xe
# Startup script for jambonz SIP server on AWS (Large deployment)
# Handles Drachtio and SIP-related applications only (no RTPEngine)

# Variables passed from Terraform
MYSQL_HOST="${mysql_host}"
MYSQL_WRITE_HOST="${mysql_write_host}"
MYSQL_READ_HOST="${mysql_read_host}"
MYSQL_USER="${mysql_user}"
MYSQL_PASSWORD="${mysql_password}"
REDIS_HOST="${redis_host}"
REDIS_PORT="${redis_port}"
JWT_SECRET="${jwt_secret}"
MONITORING_PRIVATE_IP="${monitoring_private_ip}"
VPC_CIDR="${vpc_cidr}"
ENABLE_PCAPS="${enable_pcaps}"
APIBAN_KEY="${apiban_key}"
APIBAN_CLIENT_ID="${apiban_client_id}"
APIBAN_CLIENT_SECRET="${apiban_client_secret}"
RTP_PRIVATE_IPS="${rtp_private_ips}"

echo "Starting jambonz SIP server configuration for AWS large deployment"

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

sudo systemctl stop drachtio || true

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
echo "RTP Private IPs: $RTP_PRIVATE_IPS"

# Build RTP engines connection string (IP:port format)
# Convert comma-separated IPs to comma-separated IP:22222 format
RTPENGINES=""
IFS=',' read -ra RTP_IPS <<< "$RTP_PRIVATE_IPS"
for i in "$${!RTP_IPS[@]}"; do
    IP="$(echo "$${RTP_IPS[$i]}" | tr -d ' ')"
    if [ -n "$IP" ]; then
        if [ -n "$RTPENGINES" ]; then
            RTPENGINES="$RTPENGINES,$IP:22222"
        else
            RTPENGINES="$IP:22222"
        fi
    fi
done

echo "RTPEngines connection string: $RTPENGINES"

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
      JAMBONES_MYSQL_WRITE_HOST: '$MYSQL_WRITE_HOST',
      JAMBONES_MYSQL_WRITE_USER: '$MYSQL_USER',
      JAMBONES_MYSQL_WRITE_PASSWORD: '$MYSQL_PASSWORD',
      JAMBONES_MYSQL_WRITE_DATABASE: 'jambones',
      JAMBONES_MYSQL_HOST: '$MYSQL_READ_HOST',
      JAMBONES_MYSQL_USER: '$MYSQL_USER',
      JAMBONES_MYSQL_PASSWORD: '$MYSQL_PASSWORD',
      JAMBONES_MYSQL_DATABASE: 'jambones',
      JAMBONES_MYSQL_CONNECTION_LIMIT: 5,
      JAMBONES_REDIS_HOST: '$REDIS_HOST',
      JAMBONES_REDIS_PORT: $REDIS_PORT,
      JAMBONES_TIME_SERIES_HOST: '$MONITORING_PRIVATE_IP',
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
      JAMBONES_RTPENGINES: '$RTPENGINES',
      MIN_CALL_LIMIT: 9999,
      RTPENGINE_PING_INTERVAL: 30000,
      DRACHTIO_HOST: '127.0.0.1',
      DRACHTIO_PORT: 9022,
      DRACHTIO_SECRET: 'cymru',
      JAMBONES_MYSQL_WRITE_HOST: '$MYSQL_WRITE_HOST',
      JAMBONES_MYSQL_WRITE_USER: '$MYSQL_USER',
      JAMBONES_MYSQL_WRITE_PASSWORD: '$MYSQL_PASSWORD',
      JAMBONES_MYSQL_WRITE_DATABASE: 'jambones',
      JAMBONES_MYSQL_HOST: '$MYSQL_READ_HOST',
      JAMBONES_MYSQL_USER: '$MYSQL_USER',
      JAMBONES_MYSQL_PASSWORD: '$MYSQL_PASSWORD',
      JAMBONES_MYSQL_DATABASE: 'jambones',
      JAMBONES_MYSQL_CONNECTION_LIMIT: 10,
      JAMBONES_REDIS_HOST: '$REDIS_HOST',
      JAMBONES_REDIS_PORT: $REDIS_PORT,
      JAMBONES_TIME_SERIES_HOST: '$MONITORING_PRIVATE_IP',
      JAMBONES_TRACK_ACCOUNT_CALLS: 0,
      JAMBONES_TRACK_SP_CALLS: 0,
      JAMBONES_TRACK_APP_CALLS: 0,
      ENABLE_METRICS: 1,
      STATS_HOST: '127.0.0.1',
      STATS_PORT: 8125,
      STATS_PROTOCOL: 'tcp',
      STATS_SAMPLE_RATE: 1,
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
      AWS_REGION: '$REGION',
      JAMBONES_NETWORK_CIDR: '$VPC_CIDR',
      JAMBONES_RTPENGINE_INJECT_DTMF_ALWAYS: 0,
      JAMBONES_RTPENGINE_UDP_PORT: 7000,
      JAMBONES_RTPENGINES: '$RTPENGINES',
      DRACHTIO_HOST: '127.0.0.1',
      DRACHTIO_PORT: 9022,
      DRACHTIO_SECRET: 'cymru',
      HTTP_PORT: 3000,
      HTTP_PORT_MAX: 3009,
      AWS_SNS_PORT: 3010,
      AWS_SNS_PORT_MAX: 3019,
      JAMBONES_MYSQL_HOST: '$MYSQL_READ_HOST',
      JAMBONES_MYSQL_USER: '$MYSQL_USER',
      JAMBONES_MYSQL_PASSWORD: '$MYSQL_PASSWORD',
      JAMBONES_MYSQL_DATABASE: 'jambones',
      JAMBONES_MYSQL_CONNECTION_LIMIT: 10,
      JAMBONES_REDIS_HOST: '$REDIS_HOST',
      JAMBONES_REDIS_PORT: $REDIS_PORT,
      JAMBONES_TIME_SERIES_HOST: '$MONITORING_PRIVATE_IP',
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
sudo sed -i -e "s/influxdb:8086/$MONITORING_PRIVATE_IP:8086/g" /etc/telegraf/telegraf.conf
sudo systemctl restart telegraf

# Point drachtio to the HEP endpoint on the monitoring server
if [[ "$ENABLE_PCAPS" == "true" ]]; then
  echo "Enabling PCAPs"
  sudo sed -i -e "s/--address 0.0.0.0 --port 9022/--address 0.0.0.0 --port 9022 --homer $MONITORING_PRIVATE_IP:9060 --homer-id 10/g" /etc/systemd/system/drachtio.service
fi

# Point drachtio to the HEP endpoint on the monitoring server
sudo sed -i "s/--homer 127.0.0.1:9060/--homer $MONITORING_PRIVATE_IP:9060/g" /etc/systemd/system/drachtio.service

sudo systemctl daemon-reload
sudo systemctl restart drachtio

echo "Starting jambonz apps"
sudo -u $USER bash -c "pm2 restart $HOME/apps/ecosystem.config.js"
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME
sudo -u $USER bash -c "pm2 save"
sudo systemctl enable pm2-$USER.service

# Configure APIBan - supports two modes:
# 1. Client credentials mode: auto-provision unique key per instance (preferred)
# 2. Single key mode: use customer-provided key
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

echo "SIP server setup complete!"
