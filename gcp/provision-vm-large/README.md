# jambonz Large Cluster on GCP

This Terraform configuration deploys a jambonz large cluster on Google Cloud Platform (GCP) with fully separated SIP and RTP components.

## Architecture

```
                                 Internet
                                     │
      ┌──────────────┬───────────────┼───────────────┬──────────────┐
      │              │               │               │              │
      ▼              ▼               ▼               ▼              ▼
 ┌─────────┐   ┌──────────┐   ┌─────────┐    ┌──────────┐   ┌───────────┐
 │   SIP   │   │   RTP    │   │   Web   │    │ Monitor  │   │Cloud NAT  │
 │  (VMs)  │   │  (VMs)   │   │  (VM)   │    │  (VM)    │   └─────┬─────┘
 └────┬────┘   └────┬─────┘   └────┬────┘    └────┬─────┘         │
      │             │              │              │               │
══════╪═════════════╪══════════════╪══════════════╪═══════════════╪═══════
      │             │              │              │               │
      │             │              │    ┌─────────┴───────────────┤
      │             │              │    │                         │
      │             │         ┌────┴────┴────┐         ┌──────────┴──────────┐
      │             │         │      FS      │         │  Internal LB        │
      │             │         │    (MIG)     │─────────│  ┌───────────────┐  │
      │             │         └──────┬───────┘         │  │   Recording   │  │
      │             │                │                 │  │     (MIG)     │  │
      │             │                │                 │  └───────────────┘  │
      │             │                │                 └─────────────────────┘
      └─────────────┴────────────────┼────────────────────────────┘
                                     │
                            ┌────────┴────────┐
                            │                 │
                      ┌─────┴─────┐    ┌──────┴──────┐
                      │Cloud SQL  │    │ Memorystore │
                      │  (MySQL)  │    │   (Redis)   │
                      └───────────┘    └─────────────┘

══════ Public/Private boundary (VMs above line have static public IPs)
```

## Components

| Component | GCP Resource | Description |
|-----------|--------------|-------------|
| Web | Compute Instance (VM) | Portal, API |
| Monitoring | Compute Instance (VM) | Grafana, Homer, Jaeger |
| SIP | Compute Instance (VM) | drachtio SIP signaling with static IP |
| RTP | Compute Instance (VM) | rtpengine media with static IP |
| Feature Server | Managed Instance Group | Scalable call processing |
| Recording | Managed Instance Group | Optional recording cluster |
| MySQL | Cloud SQL | Private IP, no SSL |
| Redis | Memorystore | No AUTH, no TLS |

## Network Architecture

- **Public-facing components**: SIP, RTP, Web, and Monitoring VMs have static public IPs for inbound traffic
- **Internal components**: Feature Server and Recording MIGs have private IPs only
- **Cloud NAT**: Provides outbound internet access for internal components (software updates, external API calls)
- **Internal Load Balancer**: Routes traffic from Feature Servers to the Recording MIG
- **Managed Services**: Cloud SQL (MySQL) and Memorystore (Redis) are accessible only via private IP within the VPC

## Prerequisites

1. **GCP Project** with billing enabled
2. **Terraform** >= 1.0
3. **gcloud CLI** installed and configured

### Authentication

There are two ways to authenticate Terraform with GCP. Choose one:

#### Option A: Service Account Key (Recommended)

This is the most reliable method and what GCP recommends for Terraform.

1. Go to the [GCP Console](https://console.cloud.google.com/) → IAM & Admin → Service Accounts
2. Create a service account (or use an existing one) with **Editor** role
3. Create a JSON key for the service account and download it
4. Run these commands (replace the path and project ID with your values):
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your-service-account-key.json"
   gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
   gcloud config set project YOUR_PROJECT_ID
   ```

#### Option B: User Account (Application Default Credentials)

Use this if you don't want to create a service account.

```bash
# Login to gcloud CLI
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Verify you have access (this MUST succeed before continuing)
gcloud projects describe YOUR_PROJECT_ID

# Create application default credentials for Terraform
gcloud auth application-default login
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
```

If the `application-default login` command fails with browser issues, use `--no-browser` flag and follow the manual flow.

### Enable Required APIs

```bash
gcloud services enable compute.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project=YOUR_PROJECT_ID
```

## Deployment

### 1. Copy and edit variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

At minimum, you must set:
- `project_id` - Your GCP project ID
- `url_portal` - Your domain name
- `region` - GCP region
- `zone` - GCP zone

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

### Separate SIP and RTP

Unlike the medium cluster (which uses a combined SBC), the large cluster separates:
- **SIP nodes** - Handle SIP signaling only (drachtio)
- **RTP nodes** - Handle media only (rtpengine)

This allows independent scaling and different machine types for each workload.

### Redis (Memorystore)

Redis is configured with:
- **No AUTH** (`auth_enabled = false`)
- **No TLS** (`transit_encryption_mode = "DISABLED"`)
- Private network access only

### MySQL (Cloud SQL)

MySQL is configured with:
- **No SSL required** (`require_ssl = false`)
- Private IP only (no public access)

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
| `portal_url` | jambonz portal URL |
| `portal_password` | Initial admin password |
| `dns_records_required` | DNS A records to create |

## SSH Access

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

## Cleanup

```bash
terraform destroy
```

### Common Issue: Service Networking Connection Error

If `terraform destroy` fails with a service networking error, manually delete the VPC peering:

```bash
# Step 1: Find your VPC name
gcloud compute networks list --project=<project-id>

# Step 2: Delete the service networking peering
gcloud compute networks peerings delete servicenetworking-googleapis-com \
  --network=<vpc-name-from-step-1> \
  --project=<project-id>

# Step 3: Retry terraform destroy
terraform destroy
```
