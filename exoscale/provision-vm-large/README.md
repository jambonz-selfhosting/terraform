# jambonz Large Cluster on Exoscale

This Terraform configuration deploys a jambonz large cluster on Exoscale with fully separated SIP and RTP components.

## Architecture

```
                                 Internet
                                     |
      +--------------+---------------+---------------+--------------+
      |              |               |               |              |
      v              v               v               v              v
 +---------+   +----------+   +---------+    +----------+   +-----------+
 |   SIP   |   |   RTP    |   |   Web   |    | Monitor  |   |  Feature  |
 |  (VMs)  |   |  (VMs)   |   |  (VM)   |    |  (VM)    |   |  Servers  |
 +---------+   +----------+   +---------+    +----------+   |  (VMs)    |
      |             |              |              |          +-----------+
      |             |              |              |               |
======+=============+==============+==============+===============+=======
      |             |              |              |    Private    |
      |             |              |         +----+-----+        |
      |             |              |         |          |        |
      |             |              |    +----+----+ +---+------+ |
      |             |              |    |   DB    | |Recording | |
      |             |              |    |  (VM)   | |  (VMs)   | |
      |             |              |    | MySQL + | | Optional | |
      |             |              |    |  Redis  | +----------+ |
      |             |              |    +---------+              |
      +--------------+--------------+----------------------------+

====== All servers connect via private network (172.20.0.0/16)
```

## Components

| Component | Description |
|-----------|-------------|
| Web | Portal, API |
| Monitoring | Grafana, Homer, Jaeger, InfluxDB |
| SIP | drachtio SIP signaling with static IP |
| RTP | rtpengine media with static IP |
| Feature Server | Call processing (freeswitch + jambonz apps) |
| Recording | Optional recording cluster with load balancer |
| Database | Dedicated VM running MySQL + Redis |

## Network Architecture

- **Public-facing components**: SIP, RTP, Web, and Monitoring VMs have public IPs
- **Internal components**: DB, Feature Server, and Recording VMs communicate over the private network
- **Separated SIP/RTP**: Unlike the medium cluster (which uses a combined SBC), the large cluster separates SIP signaling (drachtio) and RTP media (rtpengine) onto dedicated VMs for independent scaling
- **Database**: MySQL and Redis run on a dedicated VM (not a managed service)
- **Private network**: All inter-server communication flows over 172.20.0.0/16

## Prerequisites

1. **Exoscale account** with API credentials
2. **Terraform** >= 1.0
3. **Register VM templates** into your Exoscale account

### Authentication

Set your Exoscale API credentials via environment variables:

```bash
export EXOSCALE_API_KEY="your-api-key"
export EXOSCALE_API_SECRET="your-api-secret"
```

### Register Templates

Before deploying, register the jambonz VM templates into your Exoscale account. This is a one-time step per version per zone:

```bash
cd exoscale/
./prepare-images.sh
# Select: 3) large, then choose your target zone
```

This registers seven templates: `jambonz-sip`, `jambonz-rtp`, `jambonz-fs`, `jambonz-web`, `jambonz-monitoring`, `jambonz-recording`, and `jambonz-db`.

## Deployment

### 1. Copy and edit variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

At minimum, you must set:
- `name_prefix` - Resource naming prefix
- `zone` - Exoscale zone (must match where you registered templates)
- `url_portal` - Your domain name
- `ssh_public_key` - Your SSH public key (or `ssh_key_name` for existing key)

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan and apply

```bash
terraform plan
terraform apply
```

### 4. Configure DNS

After deployment, create DNS A records:

```bash
terraform output dns_records_required
```

Or use the automated post-install script:
```bash
python ../../post_install.py --email admin@example.com
```

## Configuration

### Separate SIP and RTP

Unlike the medium cluster (which uses a combined SBC), the large cluster separates:
- **SIP nodes** - Handle SIP signaling only (drachtio)
- **RTP nodes** - Handle media only (rtpengine)

This allows independent scaling and different machine types for each workload.

### Monitoring & Observability

Both PCAP capture and OpenTelemetry tracing are **enabled by default**. To disable either, add to `terraform.tfvars`:

```hcl
# Disable SIP/RTP packet capture (Homer HEP)
enable_pcaps = "false"

# Disable OpenTelemetry tracing (Cassandra + Jaeger)
enable_otel = "false"
```

- **`enable_pcaps`** controls HEP flags on drachtio (SIP servers) and rtpengine (RTP servers)
- **`enable_otel`** controls Cassandra and Jaeger services (on monitoring server) and the `JAMBONES_OTEL_ENABLED` flag (on feature servers)

### Instance Types

Servers default to `standard.medium` (2 vCPU, 4 GB RAM). Adjust instance types in `terraform.tfvars`:

```hcl
instance_type_web        = "standard.large"
instance_type_monitoring = "standard.large"
instance_type_sip        = "standard.large"
instance_type_rtp        = "standard.large"
instance_type_feature    = "standard.large"
instance_type_db         = "standard.medium"
```

### Scaling

You can scale SIP, RTP, Feature Server, and Recording counts (1-10 each) by updating `terraform.tfvars` and running `terraform apply`.

## APIBan Configuration (Optional)

[APIBan](https://www.apiban.org/) provides a community-maintained blocklist of known VoIP fraud and spam IP addresses.

### Option 1: Single API Key (Simple)

Best for: Single deployments or when one key per email is sufficient.

1. Get a free API key at https://apiban.org/getkey.html
2. Add to `terraform.tfvars`:
   ```hcl
   apiban_key = "your-api-key-here"
   ```

### Option 2: Client Credentials (Multiple Keys)

Best for: Multiple deployments needing unique keys per instance.

1. Contact APIBan to obtain client credentials
2. Add to `terraform.tfvars`:
   ```hcl
   apiban_client_id     = "your-client-id"
   apiban_client_secret = "your-client-secret"
   ```

Each instance will automatically provision its own unique API key at boot time.

**Note:** If both are provided, client credentials take precedence.

## Outputs

| Output | Description |
|--------|-------------|
| `web_public_ip` | Public IP for Web server |
| `monitoring_public_ip` | Public IP for Monitoring server |
| `sip_public_ips` | Public IPs for SIP servers |
| `rtp_public_ips` | Public IPs for RTP servers |
| `feature_server_public_ips` | Public IPs for Feature Server instances |
| `db_private_ip` | Database server private IP |
| `portal_url` | jambonz portal URL |
| `portal_password` | Initial admin password (instance ID) |
| `dns_records_required` | DNS A records to create |
| `ssh_config_snippet` | SSH config for `~/.ssh/config` |

## SSH Access

### Direct Access (servers with public IPs)

```bash
# Web server
ssh jambonz@<web-ip>

# Monitoring server
ssh jambonz@<monitoring-ip>

# SIP server
ssh jambonz@<sip-ip>

# RTP server
ssh jambonz@<rtp-ip>
```

### SSH via Jump Host (Database, Feature, and Recording servers)

The database server only has a private IP. Use a SIP server as a jump host:

```bash
ssh -J jambonz@<sip-ip> jambonz@<db-private-ip>
```

For a convenient SSH config, run:
```bash
terraform output ssh_config_snippet
```

## Troubleshooting

### Check cloud-init logs

```bash
sudo cat /var/log/cloud-init-output.log
```

### Check jambonz app logs

```bash
# On Feature Server or Web server
sudo -u jambonz pm2 logs
```

### Test Redis connectivity

```bash
redis-cli -h <db-private-ip> -p 6379 PING
```

### Test MySQL connectivity

```bash
mysql -h <db-private-ip> -u admin -p jambones
```

## Cleanup

```bash
terraform destroy
```
