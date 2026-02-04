#!/bin/bash -xe
# Startup script for jambonz Feature Server on GCP (Large deployment)
# Includes graceful scale-in support via Redis polling

# Variables passed from Terraform
MYSQL_HOST="${mysql_host}"
MYSQL_USER="${mysql_user}"
MYSQL_PASSWORD="${mysql_password}"
REDIS_HOST="${redis_host}"
REDIS_PORT="${redis_port}"
JWT_SECRET="${jwt_secret}"
MONITORING_PRIVATE_IP="${monitoring_private_ip}"
VPC_CIDR="${vpc_cidr}"
URL_PORTAL="${url_portal}"
RECORDING_WS_BASE_URL="${recording_ws_base_url}"
SCALE_IN_TIMEOUT_SECONDS="${scale_in_timeout_seconds}"
PROJECT_ID="${project_id}"
ZONE="${zone}"

echo "Starting jambonz Feature Server configuration for GCP large deployment"

# Always use jambonz user for apps
USER=jambonz
HOME=/home/jambonz

# Get instance metadata from GCP Metadata Service
echo "Getting instance metadata from GCP..."

# Feature Servers don't need public IPs - they only communicate internally
PRIVATE_IP=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/ip 2>/dev/null || hostname -I | awk '{print $1}')
INSTANCE_ID=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/id 2>/dev/null || hostname)
INSTANCE_NAME=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/name 2>/dev/null || hostname)

echo "Private IP: $PRIVATE_IP"
echo "Instance ID: $INSTANCE_ID"
echo "Instance Name: $INSTANCE_NAME"

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
      DRACHTIO_HOST: '127.0.0.1',
      DRACHTIO_PORT: 9022,
      DRACHTIO_SECRET: 'cymru',
      JAMBONES_FEATURE_SERVERS: '127.0.0.1:9022:cymru',
      JAMBONES_FREESWITCH: '127.0.0.1:8021:JambonzR0ck\$',
      AUTHENTICATION_KEY: '$JWT_SECRET',
      JAMBONZ_RECORD_WS_USERNAME: 'jambonz',
      JAMBONZ_RECORD_WS_PASSWORD: '$JWT_SECRET',
      JAMBONZ_RECORD_WS_BASE_URL: '$RECORDING_WS_BASE_URL'
    }
  }]
};
EOF

echo "Finished writing config file"

# Configure freeswitch service
sudo sed -i -e "s/MYSQL_HOST=/MYSQL_HOST=$MYSQL_HOST/g" /etc/systemd/system/freeswitch.service
sudo sed -i -e "s/MYSQL_USER=/MYSQL_USER=$MYSQL_USER/g" /etc/systemd/system/freeswitch.service
sudo sed -i -e "s/MYSQL_PASSWORD=/MYSQL_PASSWORD=$MYSQL_PASSWORD/g" /etc/systemd/system/freeswitch.service
sudo sed -i -e "s/MYSQL_DATABASE=/MYSQL_DATABASE=jambones/g" /etc/systemd/system/freeswitch.service
sudo sed -i -e "s/JAMBONES_REDIS_HOST=/JAMBONES_REDIS_HOST=$REDIS_HOST/g" /etc/systemd/system/freeswitch.service
sudo sed -i -e "s/JAMBONES_REDIS_PORT=/JAMBONES_REDIS_PORT=$REDIS_PORT/g" /etc/systemd/system/freeswitch.service

sudo systemctl daemon-reload
sudo systemctl restart freeswitch

# Configure telegraf to send to the monitoring server
sudo sed -i -e "s/influxdb:8086/$MONITORING_PRIVATE_IP:8086/g" /etc/telegraf/telegraf.conf
sudo systemctl restart telegraf

sudo -u $USER bash -c "pm2 start $HOME/apps/ecosystem.config.js"
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME
sudo -u $USER bash -c "pm2 save"
sudo systemctl enable pm2-$USER.service

# Set up graceful scale-in via Redis polling
# The feature-server app handles SIGUSR1 to stop accepting new calls (but keeps running)
# Health check is at / (root path) and returns {"calls": N} with active call count
echo "Setting up graceful scale-in polling..."

cat << 'SCRIPT' > /usr/local/bin/check-scale-in.sh
#!/bin/bash
# Poll Redis for scale-in signal and handle graceful shutdown

REDIS_HOST="__REDIS_HOST__"
REDIS_PORT="__REDIS_PORT__"
INSTANCE_NAME="__INSTANCE_NAME__"
SCALE_IN_TIMEOUT="__SCALE_IN_TIMEOUT__"
PROJECT_ID="__PROJECT_ID__"
ZONE="__ZONE__"

# Check if drain flag exists in Redis
DRAIN_KEY="drain:$INSTANCE_NAME"
DRAIN_TIME=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT GET "$DRAIN_KEY" 2>/dev/null)

if [ -n "$DRAIN_TIME" ]; then
    # Check if we've already started draining
    if [ ! -f /tmp/draining ]; then
        echo "$(date): Scale-in signal received, starting graceful shutdown" >> /var/log/jambonz-scale-in.log
        touch /tmp/draining

        # Signal jambonz apps to stop accepting new calls
        # SIGUSR1 triggers drain mode: unregister from Redis, stop accepting new calls, but keep running
        sudo -u jambonz pm2 sendSignal SIGUSR1 feature-server 2>/dev/null || true

        # Start monitoring call counts in background
        (
            # Wait briefly for app to process the SIGUSR1 signal
            echo "$(date): Waiting 5 seconds for app to process SIGUSR1..." >> /var/log/jambonz-scale-in.log
            sleep 5

            START_TIME=$(date +%s)
            while true; do
                CURRENT_TIME=$(date +%s)
                ELAPSED=$((CURRENT_TIME - START_TIME))

                # Check if timeout reached
                if [ $ELAPSED -ge $SCALE_IN_TIMEOUT ]; then
                    echo "$(date): Timeout reached, proceeding with shutdown" >> /var/log/jambonz-scale-in.log
                    break
                fi

                # Check active call count via health endpoint
                # The endpoint returns {"calls": N} - sum across all feature-server instances on ports 3000-3009
                TOTAL_CALLS=0
                for PORT in $(seq 3000 3009); do
                    RESPONSE=$(curl -s --connect-timeout 1 http://localhost:$PORT/ 2>/dev/null)
                    if [ -n "$RESPONSE" ]; then
                        CALLS=$(echo "$RESPONSE" | jq -r '.calls // 0' 2>/dev/null || echo "0")
                        TOTAL_CALLS=$((TOTAL_CALLS + CALLS))
                    fi
                done

                echo "$(date): Active calls: $TOTAL_CALLS" >> /var/log/jambonz-scale-in.log

                if [ "$TOTAL_CALLS" -eq 0 ]; then
                    echo "$(date): All calls completed, proceeding with shutdown" >> /var/log/jambonz-scale-in.log
                    break
                fi

                echo "$(date): Waiting for $TOTAL_CALLS calls to complete..." >> /var/log/jambonz-scale-in.log
                sleep 10
            done

            # Delete the drain key
            redis-cli -h $REDIS_HOST -p $REDIS_PORT DEL "$DRAIN_KEY" 2>/dev/null || true

            # Request self-deletion via GCP API
            echo "$(date): Requesting self-deletion" >> /var/log/jambonz-scale-in.log

            # Get access token from metadata
            ACCESS_TOKEN=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token | jq -r '.access_token')

            # Delete this instance
            curl -s -X DELETE \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                "https://compute.googleapis.com/compute/v1/projects/$PROJECT_ID/zones/$ZONE/instances/$INSTANCE_NAME" \
                >> /var/log/jambonz-scale-in.log 2>&1
        ) &
    fi
fi
SCRIPT

# Replace placeholders
sed -i "s/__REDIS_HOST__/$REDIS_HOST/g" /usr/local/bin/check-scale-in.sh
sed -i "s/__REDIS_PORT__/$REDIS_PORT/g" /usr/local/bin/check-scale-in.sh
sed -i "s/__INSTANCE_NAME__/$INSTANCE_NAME/g" /usr/local/bin/check-scale-in.sh
sed -i "s/__SCALE_IN_TIMEOUT__/$SCALE_IN_TIMEOUT_SECONDS/g" /usr/local/bin/check-scale-in.sh
sed -i "s/__PROJECT_ID__/$PROJECT_ID/g" /usr/local/bin/check-scale-in.sh
sed -i "s/__ZONE__/$ZONE/g" /usr/local/bin/check-scale-in.sh

chmod +x /usr/local/bin/check-scale-in.sh

# Add cron job to poll every 10 seconds
echo "* * * * * root /usr/local/bin/check-scale-in.sh" >> /etc/crontab
echo "* * * * * root sleep 10 && /usr/local/bin/check-scale-in.sh" >> /etc/crontab
echo "* * * * * root sleep 20 && /usr/local/bin/check-scale-in.sh" >> /etc/crontab
echo "* * * * * root sleep 30 && /usr/local/bin/check-scale-in.sh" >> /etc/crontab
echo "* * * * * root sleep 40 && /usr/local/bin/check-scale-in.sh" >> /etc/crontab
echo "* * * * * root sleep 50 && /usr/local/bin/check-scale-in.sh" >> /etc/crontab

echo "Feature Server setup complete!"
