# Server Types Configuration

The `server_types.yaml` file defines expected services for each Jambonz server type, making deployment testing flexible and maintainable.

## Overview

Instead of hardcoding expected services in test scripts, we use a central configuration file that defines:
- **Systemd services** that should be running on each server type
- **PM2 processes** that should be running on each server type
- **Optional services** that won't cause test failures if missing
- **Startup script checks** for different cloud providers

## Server Types

### sbc (Session Border Controller)
Handles SIP/RTP signaling traffic.

**Systemd Services:**
- `drachtio` - SIP proxy server
- `rtpengine` - RTP media proxy
- `telegraf` - Metrics collection (optional)

**PM2 Processes:**
- `inbound` - Inbound SIP traffic handler
- `outbound` - Outbound SIP traffic handler
- `sbc-call-router` - Call routing logic
- `sbc-rtpengine-sidecar` - RTPEngine sidecar (optional)
- `sbc-sip-sidecar` - SIP sidecar (optional)

### feature-server
Handles call features and media processing.

**Systemd Services:**
- `drachtio` - SIP proxy server
- `freeswitch` - Media server
- `telegraf` - Metrics collection (optional)

**PM2 Processes:**
- `feature-server` - Main feature server process

### web-monitoring (Medium Deployment)
Combined web portal, API, and monitoring services.

**Systemd Services:**
- `cassandra` - Homer database
- `heplify-server` - HEP capture server
- `jaeger-query` - Jaeger query service
- `jaeger-collector` - Jaeger collector
- `grafana-server` - Grafana dashboards
- `influxdb` - Time series database
- `telegraf` - Metrics collection (optional)

**PM2 Processes:**
- `webapp` - Web portal UI
- `api-server` - REST API
- `public-apps` - Public applications server

### web (Large Deployment)
Web portal and API only (monitoring separate).

**Systemd Services:**
- `telegraf` - Metrics collection (optional)

**PM2 Processes:**
- `webapp` - Web portal UI
- `api-server` - REST API
- `public-apps` - Public applications server

### monitoring (Large Deployment)
Monitoring and observability only (web separate).

**Systemd Services:**
- `cassandra` - Homer database
- `heplify-server` - HEP capture server
- `jaeger-query` - Jaeger query service
- `jaeger-collector` - Jaeger collector
- `grafana-server` - Grafana dashboards
- `influxdb` - Time series database
- `telegraf` - Metrics collection (optional)

**PM2 Processes:** None

### recording
Handles call recording.

**Systemd Services:**
- `telegraf` - Metrics collection (optional)

**PM2 Processes:**
- `recording-server` - Main recording process

## Deployment Configurations

### Medium Deployment
- 1x web-monitoring server (combined)
- 1-5x SBC servers (scalable)
- 1-10x Feature servers (MIG, scalable)
- 1-5x Recording servers (MIG, scalable, optional)

### Large Deployment
- 1-2x Web servers
- 1x Monitoring server
- 2-20x SBC servers (scalable)
- 2-50x Feature servers (MIG, scalable)
- 1-10x Recording servers (MIG, scalable, optional)

## Service Checks

### Systemd Services
Checked with: `systemctl is-active <service>`
Expected output: `active`

### PM2 Processes
Checked with: `pm2 list`
Expected: Service listed and shows `online` status

### Startup Scripts by Provider

**GCP:**
- Command: `sudo systemctl status google-startup-scripts.service --no-pager`
- Success indicators:
  - Contains "Main PID:"
  - Contains "status=0/SUCCESS" or "Deactivated successfully"

**Azure/Exoscale/AWS:**
- Command: `sudo cloud-init status`
- Success indicator: Contains "status: done"

## Optional Services

Services marked as optional won't cause test failures if missing or inactive:

**Systemd:**
- `telegraf` - Metrics collection

**PM2:**
- `sbc-rtpengine-sidecar` - Optional SBC sidecar
- `sbc-sip-sidecar` - Optional SBC sidecar

## Service Aliases

The configuration supports alternative names for the same service:

**Systemd Aliases:**
- `drachtio` → `drachtio-server`, `drachtio.service`
- `rtpengine` → `rtpengine.service`, `ngcp-rtpengine-daemon`
- `grafana-server` → `grafana`, `grafana.service`

**PM2 Aliases:**
- `api-server` → `api`, `jambonz-api-server`
- `feature-server` → `fs`, `jambonz-feature-server`

## Usage

The `test_deployment.py` script automatically loads this configuration:

```python
# Loads server_types.yaml
server_types_config = load_server_types(TESTING_DIR)

# Gets expected services for server type
web_monitoring_type = server_types.get('web-monitoring', {})
expected_systemd = web_monitoring_type.get('systemd_services', [])
expected_pm2 = web_monitoring_type.get('pm2_processes', [])

# Checks services
check_systemd_services(host, expected_systemd, ssh_config, optional_services)
check_pm2_services(host, expected_pm2, ssh_config, optional_services)
```

## Adding New Server Types

To add a new server type:

1. Add entry to `server_types` section in `server_types.yaml`
2. Define `systemd_services` and `pm2_processes` lists
3. Add to appropriate deployment configuration
4. Update `test_deployment.py` if custom logic needed

Example:

```yaml
server_types:
  my-new-type:
    description: "My new server type"
    systemd_services:
      - myservice
      - myotherservice
    pm2_processes:
      - my-pm2-app
```

## Benefits

- **Maintainable**: Update services in one place
- **Flexible**: Easy to add new server types
- **Extensible**: Support multiple deployment sizes
- **Provider-agnostic**: Works with GCP, Azure, AWS, Exoscale
- **Documentation**: Central reference for all expected services
