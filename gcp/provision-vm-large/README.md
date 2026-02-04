# jambonz Large Cluster on GCP

This Terraform configuration deploys a jambonz large cluster on Google Cloud Platform (GCP) with fully separated SIP and RTP components.

## Architecture

```
                    Internet
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
   ┌─────────┐    ┌──────────┐    ┌─────────┐
   │   SIP   │    │   RTP    │    │   Web   │
   │  (VMs)  │    │  (VMs)   │    │  (VM)   │
   └────┬────┘    └────┬─────┘    └────┬────┘
        │              │               │
        │         ┌────┴────┐          │
        │         │   FS    │          │
        │         │  (MIG)  │          │
        │         └────┬────┘          │
        │              │               │
        └──────────────┼───────────────┘
                       │
              ┌────────┴────────┐
              │                 │
        ┌─────┴─────┐    ┌──────┴──────┐
        │Cloud SQL  │    │ Memorystore │
        │  (MySQL)  │    │   (Redis)   │
        └───────────┘    └─────────────┘
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

## Prerequisites

1. **GCP Project** with billing enabled
2. **gcloud CLI** authenticated:
   ```bash
   gcloud auth application-default login
   # Or set GOOGLE_APPLICATION_CREDENTIALS to a service account key
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your-key.json"
   ```
3. **Terraform** >= 1.0

### Enable Required APIs

```bash
gcloud services enable compute.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  servicenetworking.googleapis.com \
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
sudo journalctl -u google-startup-scripts.service
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
gcloud compute networks peerings delete servicenetworking-googleapis-com \
  --network=<name-prefix>-vpc \
  --project=<project-id>

terraform destroy
```
