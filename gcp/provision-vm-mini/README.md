# jambonz Mini (Single VM) on GCP

This Terraform configuration deploys jambonz as a single all-in-one VM on Google Cloud Platform (GCP).

## Architecture

```
              Internet
                  │
                  ▼
           ┌─────────────┐
           │   Mini VM   │
           │             │
           │  - SBC      │
           │  - FS       │
           │  - Web/API  │
           │  - MySQL    │
           │  - Redis    │
           │  - Homer    │
           │  - Grafana  │
           └─────────────┘
```

## Components

All components run on a single VM:

| Component | Description |
|-----------|-------------|
| drachtio | SIP server |
| rtpengine | RTP media proxy |
| Feature Server | Call processing (freeswitch + jambonz apps) |
| Web Portal | jambonz admin UI |
| API Server | REST API |
| MySQL | Local database |
| Redis | Local cache/pub-sub |
| Homer | SIP capture and analysis |
| Grafana | Metrics dashboard |

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
- `ssh_public_key` - Your SSH public key

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

After deployment, create DNS A records pointing to the public IP:

```bash
terraform output public_ip
```

Create these DNS records:
- `<url_portal>` → public IP
- `api.<url_portal>` → public IP
- `grafana.<url_portal>` → public IP
- `homer.<url_portal>` → public IP

## Outputs

| Output | Description |
|--------|-------------|
| `public_ip` | Public IP address of the VM |
| `portal_url` | jambonz portal URL |
| `portal_password` | Initial admin password (instance ID) |
| `ssh_connection` | SSH command to connect |

## SSH Access

```bash
ssh jambonz@<public-ip>
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

### Check service status

```bash
sudo systemctl status drachtio
sudo systemctl status rtpengine
sudo -u jambonz pm2 list
```

## Cleanup

```bash
terraform destroy
```
