#!/bin/bash -xe
# Startup script for jambonz Feature Server on AWS (Large deployment)
# Includes SNS lifecycle hook integration for graceful scale-in

# Variables passed from Terraform
MYSQL_HOST="${mysql_host}"
MYSQL_USER="${mysql_user}"
MYSQL_PASSWORD="${mysql_password}"
REDIS_HOST="${redis_host}"
REDIS_PORT="${redis_port}"
JWT_SECRET="${jwt_secret}"
MONITORING_PRIVATE_IP="${monitoring_private_ip}"
WEB_PRIVATE_IP="${web_private_ip}"
VPC_CIDR="${vpc_cidr}"
URL_PORTAL="${url_portal}"
RECORDING_WS_BASE_URL="${recording_ws_base_url}"
SNS_TOPIC_ARN="${sns_topic_arn}"

echo "Starting jambonz Feature Server configuration for AWS large deployment"

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
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

echo "Private IP: $PRIVATE_IP"
echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"

echo "Writing $HOME/apps/ecosystem.config.js..."

cat << EOF > $HOME/apps/ecosystem.config.js
module.exports = {
apps : [
{
    name: 'feature-server',
    cwd: '$HOME/apps/feature-server',
    script: 'app.js',
    instance_var: 'INSTANCE_ID',
    out_file: '$HOME/.pm2/logs/feature-server.log',
    err_file: '$HOME/.pm2/logs/feature-server.log',
    exec_mode: 'fork',
    instances: 'max',
    autorestart: true,
    watch: false,
    max_memory_restart: '5G',
    env: {
      JAMBONES_LOGLEVEL: 'info',
      JAMBONES_TTS_TRIM_SILENCE: 1,
      JWT_SECRET: '$JWT_SECRET',
      AWS_REGION: '$REGION',
      JAMBONES_API_BASE_URL: 'http://$URL_PORTAL/v1',
      ENABLE_METRICS: 1,
      STATS_HOST: '127.0.0.1',
      STATS_PORT: 8125,
      STATS_PROTOCOL: 'tcp',
      STATS_TELEGRAF: 1,
      STATS_SAMPLE_RATE: 1,
      JAMBONES_OTEL_ENABLED: 1,
      OTEL_EXPORTER_JAEGER_ENDPOINT: 'http://$MONITORING_PRIVATE_IP:14268/api/traces',
      OTEL_EXPORTER_OTLP_METRICS_INSECURE: 1,
      OTEL_EXPORTER_JAEGER_GRPC_INSECURE: 1,
      AWS_SNS_TOPIC_ARN: '$SNS_TOPIC_ARN',
      JAMBONES_NETWORK_CIDR: '$VPC_CIDR',
      JAMBONES_MYSQL_HOST: '$MYSQL_HOST',
      JAMBONES_MYSQL_USER: '$MYSQL_USER',
      JAMBONES_MYSQL_PASSWORD: '$MYSQL_PASSWORD',
      JAMBONES_MYSQL_DATABASE: 'jambones',
      JAMBONES_MYSQL_CONNECTION_LIMIT: 10,
      JAMBONES_REDIS_HOST: '$REDIS_HOST',
      JAMBONES_REDIS_PORT: $REDIS_PORT,
      JAMBONES_TIME_SERIES_HOST: '$MONITORING_PRIVATE_IP',
      HTTP_PORT: 3000,
      HTTP_PORT_MAX: 3009,
      AWS_SNS_PORT: 3010,
      AWS_SNS_PORT_MAX: 3019,
      DRACHTIO_HOST: '127.0.0.1',
      DRACHTIO_PORT: 9022,
      DRACHTIO_SECRET: 'cymru',
      JAMBONES_FEATURE_SERVERS: '127.0.0.1:9022:cymru',
      // feature-server selects its media server here: JAMBONES_MEDIAJAM
      // defaults to 127.0.0.1:8021, but naming it explicitly keeps the
      // choice visible rather than relying on a fallthrough.
      JAMBONES_MEDIAJAM: '127.0.0.1:8021',
      AUTHENTICATION_KEY: '$JWT_SECRET',
      JAMBONZ_RECORD_WS_USERNAME: 'jambonz',
      JAMBONZ_RECORD_WS_PASSWORD: '$JWT_SECRET',
      JAMBONZ_RECORD_WS_BASE_URL: '$RECORDING_WS_BASE_URL'
    }
  }]
};
EOF

echo "Finished writing config file"

# Configure the mediajam media server.
#
# The unit file this block used to configure does not exist on v11 images.
# This script runs under `set -e`, so those seds aborted cloud-init right here
# -- taking the mediajam config AND the `pm2 start` below with them, so the
# feature server never started at all.
#
# /etc/default/mediajam ships with the redis vars COMMENTED OUT for deploy-time
# injection. mediajam's licensing needs them: without JAMBONES_REDIS_HOST it
# exits 1 at startup, systemd restarts it forever, feature-server never reaches
# it, and every call fails 480. mediajam takes no MySQL configuration.
KRISP_LICENSE_KEY="${krisp_license_key}"
sudo sed -i -e "s|^#\?JAMBONES_REDIS_HOST=.*|JAMBONES_REDIS_HOST=$REDIS_HOST|" /etc/default/mediajam
sudo sed -i -e "s|^#\?JAMBONES_REDIS_PORT=.*|JAMBONES_REDIS_PORT=$REDIS_PORT|" /etc/default/mediajam
if [ -n "$KRISP_LICENSE_KEY" ]; then
    sudo sed -i -e "s|^KRISP_API_KEY=.*|KRISP_API_KEY=$KRISP_LICENSE_KEY|" /etc/default/mediajam
fi

sudo systemctl daemon-reload
# mediajam.service reads /etc/default/mediajam via EnvironmentFile, which is
# evaluated only when the process starts -- an explicit restart is required.
sudo systemctl restart mediajam

# Configure telegraf to send to the monitoring server
echo "JAMBONES_INFLUX_URL=http://$MONITORING_PRIVATE_IP:8086" | sudo tee -a /etc/default/telegraf > /dev/null
sudo systemctl restart telegraf

sudo -u $USER bash -c "pm2 start $HOME/apps/ecosystem.config.js"
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME
sudo -u $USER bash -c "pm2 save"
sudo systemctl enable pm2-$USER.service

echo "Feature Server setup complete!"
