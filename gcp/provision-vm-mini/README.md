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
# On the instance (view logs)
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
