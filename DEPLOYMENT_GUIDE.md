# Jambonz Terraform Deployment Guide

Complete guide for deploying and configuring Jambonz on GCP, Azure, or Exoscale.

---

## Prerequisites

1. **Terraform installed** (v1.0+)
2. **Cloud provider CLI authenticated**
   - GCP:
     ```bash
     gcloud auth application-default login
     # Or set GOOGLE_APPLICATION_CREDENTIALS to a service account key
     export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/application_default_credentials.json"
     ```
   - Azure: `az login`
   - Exoscale: Configure credentials
3. **Python 3.7+** with dependencies installed:
   ```bash
   cd testing
   pip install -r requirements.txt
   ```
4. **SSH key configured** in `testing/config.yaml`
5. **DNS provider credentials** configured in `testing/config.yaml` (DNSMadeEasy)

---

## Quick Start

### 1. Deploy Infrastructure with Terraform

```bash
cd gcp/provision-vm-medium

# Review and customize terraform.tfvars
vim terraform.tfvars

# Initialize and apply
terraform init
terraform plan
terraform apply
```

Wait for terraform to complete (typically 10-15 minutes).

### 2. Verify Deployment

Run the deployment test script to verify all VMs are accessible and services are running:

```bash
python ../../test_deployment.py
```

This checks:
- ✅ SSH connectivity to all VMs
- ✅ Cloud-init/startup scripts completed
- ✅ PM2 services are running

If any tests fail, review the output and troubleshoot before proceeding.

### 3. Post-Installation Configuration

Once tests pass, run the post-installation script:

```bash
python ../../post_install.py --email your-email@example.com
```

This will:
1. Create DNS A records (via DNSMadeEasy API)
2. Wait 60 seconds for DNS propagation
3. Provision TLS certificates with Let's Encrypt
4. Rebuild webapp to use HTTPS
5. Display login credentials

---

## Step-by-Step Details

### Step 1: Deploy Infrastructure

Choose your cloud provider directory:
- `gcp/provision-vm-medium` - Google Cloud Platform
- `azure/provision-vm-medium` - Microsoft Azure
- `exoscale/provision-vm-medium` - Exoscale

Edit `terraform.tfvars` to customize:
- Domain name (e.g., `gcp.jambonz.io`)
- Machine types
- Instance counts
- Region/zone

Apply the configuration:

```bash
cd <provider>/provision-vm-medium
terraform apply
```

### Step 2: Verify Deployment

The `test_deployment.py` script automatically:
1. Gathers terraform outputs
2. Detects cloud provider
3. Tests SSH connectivity
4. Verifies startup scripts completed
5. Checks PM2 services are running

```bash
# From terraform directory
python ../../test_deployment.py

# Or specify directory
python test_deployment.py --terraform-dir gcp/provision-vm-medium

# Verbose output
python ../../test_deployment.py --verbose
```

**What it tests:**

**Web/Monitoring Server:**
- SSH connectivity
- Startup script status
- PM2 services: `webapp`, `api`, `homer-app`, `homer-webapp`

**SBC Servers:**
- SSH connectivity
- Startup script status
- PM2 services: `sbc-inbound`, `sbc-outbound`, `sbc-call-router`

**If tests fail:**
- Wait 5-10 minutes (startup scripts may still be running)
- Check SSH key is correct in `testing/config.yaml`
- Verify firewall rules allow SSH (port 22)

### Step 3: Post-Installation Configuration

The `post_install.py` script automatically:
1. Reads terraform outputs
2. Creates 6 DNS A records
3. Provisions TLS certificates
4. Rebuilds webapp for HTTPS

```bash
# From terraform directory
python ../../post_install.py --email admin@example.com

# Skip DNS (if already created)
python ../../post_install.py --email admin@example.com --skip-dns

# Use Let's Encrypt staging (for testing)
python ../../post_install.py --email admin@example.com --staging

# Specify terraform directory
python post_install.py --terraform-dir gcp/provision-vm-medium --email admin@example.com
```

**DNS Records Created:**

For portal URL `gcp.jambonz.io`, creates:
- `gcp.jambonz.io` → Web/Monitoring IP
- `api.gcp.jambonz.io` → Web/Monitoring IP
- `grafana.gcp.jambonz.io` → Web/Monitoring IP
- `homer.gcp.jambonz.io` → Web/Monitoring IP
- `public-apps.gcp.jambonz.io` → Web/Monitoring IP
- `sip.gcp.jambonz.io` → SBC IP

**TLS Certificates:**

Uses certbot with Let's Encrypt to provision certificates for all domains.
Automatically configures nginx with HTTPS and enables HTTP→HTTPS redirect.

**Webapp Rebuild:**

Updates webapp `.env` file to use HTTPS URLs and rebuilds the application.

---

## Command Reference

### test_deployment.py

```bash
# Basic usage (from terraform directory)
python ../../test_deployment.py

# Specify terraform directory
python test_deployment.py --terraform-dir gcp/provision-vm-medium

# Use custom config file
python ../../test_deployment.py --config /path/to/config.yaml

# Verbose output
python ../../test_deployment.py --verbose
```

### post_install.py

```bash
# Full post-installation (recommended)
python ../../post_install.py --email admin@example.com

# Skip DNS creation
python ../../post_install.py --email admin@example.com --skip-dns

# Skip TLS provisioning
python ../../post_install.py --email admin@example.com --skip-tls

# Skip webapp rebuild
python ../../post_install.py --email admin@example.com --skip-webapp

# Use Let's Encrypt staging (for testing)
python ../../post_install.py --email admin@example.com --staging

# Custom config file
python ../../post_install.py --email admin@example.com --config /path/to/config.yaml
```

---

## Configuration Files

### testing/config.yaml

Required configuration for SSH and DNS:

```yaml
ssh:
  user: jambonz
  private_key: /path/to/your/ssh/key
  accept_new_hosts: true

dns:
  provider: dnsmadeeasy
  api_key: your-api-key-here
  secret: your-secret-here
```

### terraform.tfvars

Deployment-specific configuration in each provider directory:

```hcl
project_id = "your-gcp-project"
region     = "us-central1"
zone       = "us-central1-c"

url_portal = "gcp.jambonz.io"

sbc_count = 1

machine_type_web       = "e2-standard-2"
machine_type_sbc       = "e2-standard-2"
machine_type_fs        = "e2-standard-2"
machine_type_recording = "e2-standard-2"

ssh_public_key = "ssh-rsa AAAAB3..."
```

---

## Accessing Your Deployment

After successful post-installation:

### Jambonz Portal
- **URL**: `https://your-domain.jambonz.io`
- **Username**: `admin`
- **Password**: Instance ID (shown in post_install.py output)
- ⚠️ You will be required to change password on first login

### Grafana
- **URL**: `https://grafana.your-domain.jambonz.io`
- **Username**: `admin`
- **Password**: `admin`
- ⚠️ Change password on first login

### Homer
- **URL**: `https://homer.your-domain.jambonz.io`
- Default credentials configured during deployment

### API
- **URL**: `https://api.your-domain.jambonz.io/api/v1`
- Use API token from Jambonz Portal

---

## Troubleshooting

### test_deployment.py Fails

**SSH connectivity failed:**
- Verify SSH key in `testing/config.yaml` matches terraform public key
- Check firewall rules allow SSH from your IP
- Wait a few minutes for VMs to fully boot

**Startup script not complete:**
- Wait 5-10 minutes for cloud-init to finish
- SSH to VM and check status manually:
  - GCP: `sudo systemctl status google-startup-scripts.service`
  - Azure/Exoscale: `sudo cloud-init status`

**PM2 services not running:**
- SSH to VM and check: `pm2 list`
- View logs: `pm2 logs`
- Check startup script logs:
  - GCP: `sudo journalctl -u google-startup-scripts -n 100`
  - Azure/Exoscale: `sudo cat /var/log/cloud-init-output.log`

### post_install.py Fails

**DNS creation failed:**
- Verify credentials in `testing/config.yaml`
- Check DNS provider API is accessible
- Manually test DNS API with `testing/query_dme.sh`

**TLS certificate provisioning failed:**
- Ensure DNS records have propagated (wait 5-10 minutes)
- Test DNS resolution: `dig your-domain.jambonz.io +short`
- Check firewall allows HTTP/HTTPS (ports 80, 443)
- Review certbot output for specific error
- Try staging mode first: `--staging`

**Webapp rebuild failed:**
- SSH to web server: `ssh jambonz@<web-ip>`
- Check webapp directory: `ls -la /home/jambonz/apps/webapp`
- Review build logs: `pm2 logs webapp`
- Manually rebuild: `cd /home/jambonz/apps/webapp && npm run build`

### Certificate Rate Limiting

Let's Encrypt has rate limits. If you hit them:
1. Use `--staging` flag for testing
2. Wait 1 week for rate limit reset
3. Or use existing certificates with `--skip-tls`

### Portal Login Issues

**Wrong password:**
- Get correct password: `cd <terraform-dir> && terraform output -raw portal_password`
- Password is the numeric instance ID, not instance name

**Can't access portal:**
- Verify DNS resolution: `dig your-domain.jambonz.io +short`
- Check HTTPS is working: `curl -I https://your-domain.jambonz.io`
- Clear browser cookies/cache
- Try incognito/private window

---

## Manual Operations

### Manually Create DNS Records

```bash
cd testing
python test_dns.py create \
  --url-portal gcp.jambonz.io \
  --web-ip 1.2.3.4 \
  --sbc-ip 5.6.7.8 \
  --config config.yaml
```

### Manually Provision TLS Certificates

```bash
cd testing
python test_certbot.py run \
  --host 1.2.3.4 \
  --email admin@example.com \
  --config config.yaml
```

### Manually Rebuild Webapp

```bash
cd testing
python test_webapp_rebuild.py run \
  --host 1.2.3.4 \
  --config config.yaml
```

---

## Cleanup

### Destroy Deployment

```bash
cd <provider>/provision-vm-medium
terraform destroy
```

### Delete DNS Records

```bash
cd testing
python test_dns.py delete \
  --subdomain gcp \
  --config config.yaml \
  --yes
```

---

## Next Steps

After deployment is complete:

1. **Login to Portal** and change admin password
2. **Configure SIP Trunks** (Carriers)
3. **Create Accounts** and **Applications**
4. **Set up Phone Numbers**
5. **Test Making/Receiving Calls**

Refer to Jambonz documentation: https://www.jambonz.org/docs/

---

## Support

- **Jambonz Documentation**: https://www.jambonz.org/docs/
- **Jambonz Slack**: https://joinslack.jambonz.org/
- **GitHub Issues**: https://github.com/jambonz/jambonz-selfhosting
