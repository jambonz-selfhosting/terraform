# jambonz Medium Cluster on Hetzner Cloud

This Terraform configuration deploys a jambonz medium cluster on Hetzner Cloud.

## Architecture

```
                               Internet
                                   │
      ┌────────────────────────────┼────────────────────────────┐
      │                            │                            │
      ▼                            ▼                            ▼
 ┌─────────┐                ┌──────────┐                 ┌───────────┐
 │   SBC   │                │   Web/   │                 │  Feature  │
 │  (VMs)  │                │ Monitor  │                 │  Servers  │
 └────┬────┘                │  (VM)    │                 │  (VMs)    │
      │                     └────┬─────┘                 └─────┬─────┘
      │                          │                             │
══════╪══════════════════════════╪═════════════════════════════╪═══════
      │                          │          Private Network    │
      │                     ┌────┴──────────────┐              │
      │                     │                   │              │
      │                ┌────┴────┐        ┌─────┴─────┐        │
      │                │   DB    │        │ Recording │        │
      │                │  (VM)   │        │  (VMs)    │        │
      │                │ MySQL + │        │ Optional  │        │
      │                │  Redis  │        └───────────┘        │
      │                └─────────┘                             │
      └────────────────────────────────────────────────────────┘

══════ All servers connect via private network (172.20.0.0/16)
```

## Components

| Component | Description |
|-----------|-------------|
| Web/Monitoring | Portal, API, Grafana, Homer, Jaeger |
| SBC | SIP/RTP traffic (drachtio + rtpengine) |
| Feature Server | Call processing (freeswitch + jambonz apps) |
| Recording | Recording cluster with load balancer |
| Database | Dedicated VM running MySQL + Redis |

## Network Architecture

- **Public-facing components**: SBC and Web/Monitoring VMs have public IPs
- **Internal components**: DB, Feature Server, and Recording VMs communicate over the private network
- **Database**: MySQL and Redis run on a dedicated VM (not a managed service)
- **Private network**: All inter-server communication flows over 172.20.0.0/16

## Prerequisites

1. **Hetzner Cloud account** with a project created
2. **Terraform** >= 1.0
3. **Packer-built snapshots** for each server role

### Authentication

Provide your Hetzner Cloud API token using one of these methods:

**Option A: Environment variable (recommended)**
```bash
export HCLOUD_TOKEN="your-api-token"
```

**Option B: In terraform.tfvars**
```hcl
hcloud_token = "your-api-token"
```

Generate a token in the Hetzner Cloud Console: Project → Security → API Tokens → Generate API Token (Read & Write).

### Build Snapshots

Build the jambonz snapshots using Packer before deploying:
```bash
# Build each snapshot type and note the IDs:
# - jambonz-web-monitoring
# - jambonz-sip-rtp (SBC)
# - jambonz-fs (Feature Server)
# - jambonz-db (Database)
# - jambonz-recording
```

## Deployment

### 1. Copy and edit variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

At minimum, you must set:
- `name_prefix` - Resource naming prefix
- `location` - Hetzner Cloud location
- `url_portal` - Your domain name
- `ssh_public_key` - Your SSH public key (or `ssh_key_name` for existing key)
- `image_web_monitoring`, `image_sbc`, `image_feature_server`, `image_db` - Packer snapshot IDs

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

### Monitoring & Observability

Both PCAP capture and OpenTelemetry tracing are **enabled by default**. To disable either, add to `terraform.tfvars`:

```hcl
# Disable SIP/RTP packet capture (Homer HEP)
enable_pcaps = "false"

# Disable OpenTelemetry tracing (Cassandra + Jaeger)
enable_otel = "false"
```

- **`enable_pcaps`** controls HEP flags on drachtio and rtpengine (on SBC servers)
- **`enable_otel`** controls Cassandra and Jaeger services (on web/monitoring server) and the `JAMBONES_OTEL_ENABLED` flag (on feature servers)

### Graceful Scale-In

Feature Servers support graceful scale-in with a configurable timeout (default 15 minutes):

1. Set `drain:<instance-name>` key in Redis to signal scale-in
2. Feature Server stops accepting new calls
3. Waits for existing calls to complete (up to timeout)
4. Instance self-deletes via Hetzner API

### Server Types

All servers default to `cx33` (4 vCPU, 8 GB RAM, 80 GB disk). Not all server types are available in all locations. To list available types:
```bash
hcloud server-type list
```

### Scaling

You can scale SBC, Feature Server, and Recording counts (1-10 each) by updating `terraform.tfvars` and running `terraform apply`.

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
| `web_monitoring_public_ip` | Public IP for Web/Monitoring (DNS records) |
| `sbc_public_ips` | Public IPs for SBC instances (SIP traffic) |
| `feature_server_public_ips` | Public IPs for Feature Server instances |
| `db_private_ip` | Database server private IP |
| `portal_url` | jambonz portal URL |
| `portal_password` | Initial admin password (instance ID) |
| `dns_records_required` | DNS A records to create |
| `ssh_config_snippet` | SSH config for `~/.ssh/config` |

## SSH Access

### Direct Access (servers with public IPs)

```bash
# Web/Monitoring server
ssh jambonz@<web-monitoring-ip>

# SBC
ssh jambonz@<sbc-ip>

# Feature Server
ssh jambonz@<feature-server-ip>
```

### SSH via Jump Host (Database server)

The database server only has a private IP. Use the SBC as a jump host:

```bash
ssh -J jambonz@<sbc-ip> jambonz@<db-private-ip>
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
# On Feature Server or SBC
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
