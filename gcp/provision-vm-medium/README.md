# jambonz Medium Cluster on GCP

This Terraform configuration deploys a jambonz medium cluster on Google Cloud Platform (GCP).

## Architecture

```
                    Internet
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
   ┌─────────┐    ┌──────────┐    ┌─────────┐
   │   SBC   │    │   Web/   │    │   FS    │
   │  (VM)   │    │ Monitor  │    │  (MIG)  │
   │         │    │   (VM)   │    │         │
   └────┬────┘    └────┬─────┘    └────┬────┘
        │              │               │
        └──────────────┼───────────────┘
                       │
              ┌────────┴────────┐
              │                 │
        ┌─────┴─────┐    ┌──────┴──────┐
        │Cloud SQL  │    │ Memorystore │
        │  (MySQL)  │    │   (Redis)   │
        │ No SSL    │    │  No AUTH    │
        └───────────┘    └─────────────┘
```

## Components

| Component | GCP Resource | Description |
|-----------|--------------|-------------|
| Web/Monitoring | Compute Instance (VM) | Portal, API, Grafana, Homer, Jaeger |
| SBC | Compute Instance (VM) | SIP/RTP traffic with static IP |
| Feature Server | Managed Instance Group | Manually-scaled call processing |
| Recording | Managed Instance Group | Optional recording cluster |
| MySQL | Cloud SQL | Private IP, no SSL |
| Redis | Memorystore | No AUTH, no TLS |

## Prerequisites

1. **GCP Project** with billing enabled
2. **Packer images** built for GCP (feature-server, sbc, web-monitoring, recording)
3. **gcloud CLI** authenticated:
   ```bash
   gcloud auth application-default login
   # Or set GOOGLE_APPLICATION_CREDENTIALS to a service account key
   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/application_default_credentials.json"
   ```
4. **Terraform** >= 1.0

### Enable Required APIs

```bash
gcloud services enable compute.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable redis.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

## Deployment

### 1. Copy and edit variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

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

After deployment, create DNS A records pointing to the IPs in the output:

```bash
terraform output dns_records_required
```

## Configuration

### Redis (Memorystore)

Redis is configured with:
- **No AUTH** (`auth_enabled = false`)
- **No TLS** (`transit_encryption_mode = "DISABLED"`)
- Private network access only

### MySQL (Cloud SQL)

MySQL is configured with:
- **No SSL required** (`require_ssl = false`)
- Private IP only (no public access)
- Binary logging enabled for backups

### Graceful Scale-In

Feature Servers support graceful scale-in with a configurable timeout (default 15 minutes):

1. Set `drain:<instance-name>` key in Redis to signal scale-in
2. Feature Server stops accepting new calls
3. Waits for existing calls to complete (up to timeout)
4. Instance self-deletes via GCP API

To manually trigger scale-in for testing:
```bash
# Connect to Redis and set drain flag
redis-cli -h <redis-host> SET "drain:<instance-name>" "$(date +%s)" EX 900
```

### APIBan Configuration (Optional)

[APIBan](https://www.apiban.org/) provides a community-maintained blocklist of known VoIP fraud and spam IP addresses.

#### Option 1: Single API Key (Simple)

Best for: Single deployments or when one key per email is sufficient.

1. Get a free API key at https://apiban.org/getkey.html
2. Add to `terraform.tfvars`:
   ```hcl
   apiban_key = "your-api-key-here"
   ```

#### Option 2: Client Credentials (Multiple Keys)

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
| `portal_url` | jambonz portal URL |
| `portal_password` | Initial admin password (instance ID) |
| `ssh_connection_web_monitoring` | SSH command for Web/Monitoring |
| `dns_records_required` | DNS A records to create |

## Operations

### List Feature Server Instances

```bash
# List all Feature Server instances with their IPs
gcloud compute instances list \
  --filter="name~-fs-" \
  --format="table(name,zone,INTERNAL_IP,EXTERNAL_IP,status)" \
  --project=<project-id>

# Get detailed network info for a specific instance
gcloud compute instances describe <instance-name> \
  --zone=<zone> \
  --project=<project-id> \
  --format="yaml(networkInterfaces)"
```

### Manual Scaling

Feature Servers use manual scaling (no CPU-based autoscaler). To resize the cluster:

```bash
# Scale up or down
gcloud compute instance-groups managed resize <name-prefix>-fs-mig \
  --size=<desired-count> \
  --zone=<zone> \
  --project=<project-id>

# Example: scale to 3 instances
gcloud compute instance-groups managed resize jambonz-fs-mig \
  --size=3 \
  --zone=us-west1-a \
  --project=drachtio-cpaas
```

### Graceful Drain Procedure

To gracefully remove a Feature Server instance:

1. Get the instance name:
   ```bash
   gcloud compute instances list --filter="name~-fs-" --project=<project-id>
   ```

2. Set the drain key in Redis (from any instance with Redis access):
   ```bash
   redis-cli -h <redis-host> SET "drain:<instance-name>" "$(date +%s)" EX 900
   ```

3. The instance will:
   - Stop accepting new calls (via SIGUSR1 signal)
   - Wait for active calls to complete (up to 15 min timeout)
   - Self-delete via GCP API

4. Monitor progress:
   ```bash
   # SSH to the instance and check logs
   tail -f /var/log/jambonz-scale-in.log
   ```

## SSH Access

### Direct Access (instances with public IPs)

```bash
# Web/Monitoring server
ssh jambonz@<web-monitoring-ip>

# SBC
ssh jambonz@<sbc-ip>

# Feature Server (if public IP enabled)
ssh jambonz@<feature-server-public-ip>
```

### SSH via Jump Host (Feature Servers without public IPs)

When `feature_server_public_ip = false` (default), Feature Servers only have private IPs. Use the SBC or Web/Monitoring server as a jump host:

```bash
# Option 1: SSH ProxyJump (recommended)
ssh -J jambonz@<sbc-public-ip> jambonz@<fs-private-ip>

# Option 2: Configure in ~/.ssh/config for convenience
```

Add to `~/.ssh/config`:
```
Host jambonz-sbc
    HostName <sbc-public-ip>
    User jambonz
    IdentityFile ~/.ssh/your-key

Host jambonz-fs-*
    User jambonz
    IdentityFile ~/.ssh/your-key
    ProxyJump jambonz-sbc

# Then connect with:
# ssh jambonz-fs-1   (where 1 maps to the private IP)
```

Or use a wildcard pattern with private IPs:
```
Host 172.20.*
    User jambonz
    IdentityFile ~/.ssh/your-key
    ProxyJump jambonz-sbc
```

Then connect directly:
```bash
ssh 172.20.10.5
```

### Using gcloud (IAP tunnel)

```bash
# Feature Server via IAP (no public IP needed)
gcloud compute ssh <instance-name> --zone=<zone> --tunnel-through-iap --project=<project-id>
```

## Cleanup

### Standard Cleanup

```bash
terraform destroy
```

### Common Issue: Service Networking Connection Error

If `terraform destroy` fails with this error:
```
Error: Unable to remove Service Networking Connection, err: Error waiting for Delete Service Networking Connection:
Error code 9, message: Failed to delete connection; Producer services (e.g. CloudSQL, Cloud Memstore, etc.) are still using this connection.
```

**Solution:** Manually delete the VPC peering, then retry destroy:

```bash
# Step 1: Delete the service networking peering
gcloud compute networks peerings delete servicenetworking-googleapis-com \
  --network=<name-prefix>-vpc \
  --project=<project-id>

# Step 2: Retry terraform destroy
terraform destroy
```

This error occurs because GCP doesn't always fully release the service networking connection when Cloud SQL/Redis are deleted. The manual peering deletion resolves this immediately.

## Known Issues & Fixes

### Recording Server Health Check

**Issue:** Recording servers may show as UNHEALTHY in the load balancer.

**Cause:** The health check must use the `/health` endpoint, not `/` (which returns 404).

**Fix:** Ensure [compute.tf:297](compute.tf#L297) has:
```hcl
http_health_check {
  port         = 3000
  request_path = "/health"  # Not "/"
}
```

### Recording Load Balancer Port

**Issue:** Recording load balancer not responding.

**Cause:** The forwarding rule port must match the backend service port (3000).

**Fix:** Ensure [compute.tf:267](compute.tf#L267) has:
```hcl
resource "google_compute_forwarding_rule" "recording" {
  ports = ["3000"]  # Not ["80"]
  ...
}
```

## Troubleshooting

### Check startup script logs

```bash
# On any instance (view logs)
sudo journalctl -u google-startup-scripts.service

# Or filter syslog
sudo cat /var/log/syslog | grep startup-script

# From your local machine (stream logs via gcloud)
gcloud compute instances get-serial-port-output <instance-name> \
  --zone=<zone> \
  --project=<project-id>
```

### Check jambonz app logs

```bash
# On Feature Server or SBC
sudo -u jambonz pm2 logs
```

### Test Redis connectivity

```bash
redis-cli -h <redis-host> -p 6379 PING
```

### Test MySQL connectivity

```bash
mysql -h <mysql-private-ip> -u jambonz -p<password> jambones
```