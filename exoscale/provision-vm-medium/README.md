# Jambonz Medium Cluster on Exoscale

This Terraform configuration deploys a production-ready Jambonz medium cluster on Exoscale with managed MySQL and Valkey (Redis-compatible) database services.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [SSH Access](#ssh-access)
- [DNS Configuration](#dns-configuration)
- [Post-Deployment](#post-deployment)
- [Scaling](#scaling)
- [Minimal Cost Configuration](#minimal-cost-configuration)
- [Troubleshooting](#troubleshooting)

## Architecture Overview

The medium cluster consists of:

### Compute Resources
- **1 Web/Monitoring Server** (public IP)
  - API server (port 3002)
  - Web portal (port 3001)
  - Grafana (port 3010)
  - Homer SIP capture (port 9080)
  - Jaeger tracing (ports 16686, 14268-14269)
  - InfluxDB (ports 8086, 8088)

- **1-10 SBC Servers** (each with public IP)
  - Drachtio SIP server (ports 5060/5061/8443)
  - RTPEngine media processing (UDP ports 40000-60000)
  - Acts as jump/bastion server for private instances

- **1-10 Feature Servers** (private IPs only, in Instance Pool)
  - FreeSWITCH for call handling
  - Scalable with health checks
  - Access via SBC jump server

- **0-10 Recording Servers** (optional, private IPs only, in Instance Pool)
  - Recording upload processing
  - Internal load balancer (TCP port 80)
  - Access via SBC jump server

### Managed Services
- **Exoscale DBaaS MySQL** - Fully managed database (hobbyist to premium plans)
- **Exoscale DBaaS Valkey** - Redis-compatible cache (hobbyist to premium plans)

### Key Differences from Mini Cluster
- **Mini**: Single VM with embedded MySQL/Redis, all components on one instance
- **Medium**: Distributed architecture with managed databases, separate VMs for each role, scalable feature/recording servers

## Prerequisites

### 1. Custom Exoscale Templates

You must create four custom Exoscale templates via Packer before deploying:

- `jambonz-web-monitoring` - Web, API, Grafana, Homer, Jaeger, InfluxDB components
- `jambonz-sbc` - Drachtio SIP server and RTPEngine media processing
- `jambonz-feature-server` - FreeSWITCH and feature server application
- `jambonz-recording` - Recording upload service

> **Note**: These templates should be pre-built with all necessary Jambonz components installed. The cloud-init scripts will configure them to use the managed databases.

### 2. Exoscale Account and API Credentials

- Active Exoscale account
- API Key and Secret with permissions for:
  - Compute instances
  - Instance pools
  - Network load balancers
  - DBaaS (MySQL and Valkey)
  - Private networks and security groups

Set environment variables:
```bash
export EXOSCALE_API_KEY="your-api-key"
export EXOSCALE_API_SECRET="your-api-secret"
```

### 3. SSH Key Configuration

You need to configure SSH key access for your instances. Choose one of two methods:

#### Method 1: Provide Your SSH Public Key (Recommended)

This method creates a new SSH key in Exoscale using your public key:

```hcl
# In terraform.tfvars
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... your-email@example.com"
```

To get your SSH public key:

```bash
# Display your existing public key
cat ~/.ssh/id_rsa.pub

# Or generate a new key pair if you don't have one
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
cat ~/.ssh/id_rsa.pub
```

Copy the entire output (starting with `ssh-rsa` and ending with your email) and paste it into the `ssh_public_key` variable in `terraform.tfvars`.

#### Method 2: Use an Existing Exoscale SSH Key

If you've already uploaded an SSH key to Exoscale, you can reference it by name:

```hcl
# In terraform.tfvars
# Comment out or remove ssh_public_key
# ssh_public_key = ""

# Use existing key name instead
ssh_key_name = "my-exoscale-key"
```

To list your existing Exoscale SSH keys:

```bash
# Using Exoscale CLI
exo compute ssh-key list

# Using Exoscale Console
# Navigate to: Compute > SSH Keys
# https://portal.exoscale.com/compute/keypairs
```

To create a new key in Exoscale (if needed):

```bash
# Upload your public key to Exoscale
exo compute ssh-key register my-key-name ~/.ssh/id_rsa.pub

# Or via the web console:
# Compute > SSH Keys > Add SSH Key
```

**Important Notes:**
- If you provide both `ssh_public_key` and `ssh_key_name`, the `ssh_public_key` will take precedence
- The SSH key must be in your Exoscale account in the same zone (ch-gva-2) as your deployment
- You'll use this key to SSH into all instances: `ssh jambonz@<instance-ip>`

**Understanding SSH Keys in Exoscale:**
- When you create an SSH key in Exoscale (e.g., "daveh-ssh-key"), you upload your **public key** only
- The **private key** never leaves your local machine and cannot be downloaded from Exoscale
- To SSH into instances, you must use the private key that corresponds to the public key you uploaded
- If you created "daveh-ssh-key" in Exoscale, you need to have the matching private key (usually `~/.ssh/id_rsa`) on your local machine
- Example: If you uploaded `~/.ssh/id_rsa.pub` to Exoscale as "daveh-ssh-key", you'll use `~/.ssh/id_rsa` (the private key) to connect

**To find which local key matches your Exoscale key:**
```bash
# List your local public keys
ls -la ~/.ssh/*.pub

# Display your public key
cat ~/.ssh/id_rsa.pub

# Compare with Exoscale (copy the fingerprint)
exo compute ssh-key show daveh-ssh-key

# Generate fingerprint of your local key to compare
ssh-keygen -l -f ~/.ssh/id_rsa.pub
```

**If you've lost the private key:**
You'll need to create a new SSH key pair and upload the new public key to Exoscale:
```bash
# Generate a new key pair
ssh-keygen -t rsa -b 4096 -C "your-email@example.com" -f ~/.ssh/exoscale_key

# Upload the new public key to Exoscale
exo compute ssh-key register daveh-ssh-key-new ~/.ssh/exoscale_key.pub

# Update terraform.tfvars to use the new key
ssh_key_name = "daveh-ssh-key-new"

# When connecting, specify the private key
ssh -i ~/.ssh/exoscale_key jambonz@<instance-ip>
```

### 4. Domain Name and DNS Access

- A domain name for the portal (e.g., `jambonz.example.com`)
- Ability to create DNS A records for subdomains

### 5. Terraform

- Terraform >= 1.0
- Exoscale provider >= 0.54

## Quick Start

```bash
# 1. Clone or navigate to this directory
cd exoscale/provision-vm-medium

# 2. Set up Exoscale API credentials
export EXOSCALE_API_KEY="your-api-key"
export EXOSCALE_API_SECRET="your-api-secret"

# 3. Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# 4. Edit terraform.tfvars with your settings
nano terraform.tfvars

# Required changes:
# - Add your SSH public key OR Exoscale key name
# - Update url_portal with your domain
# - Verify template names match your Exoscale templates

# 5. Get your SSH public key (if using Method 1)
cat ~/.ssh/id_rsa.pub
# Copy the output and paste into ssh_public_key in terraform.tfvars

# 6. Initialize Terraform
terraform init

# 7. Review the plan
terraform plan

# 8. Deploy the cluster
terraform apply

# 9. Configure DNS (see output for required records)
terraform output dns_records_required

# 10. Access the portal
terraform output portal_url
```

## Configuration

### Minimal Cost Configuration (1 SBC, 1 Feature Server)

For testing and development, use this configuration in `terraform.tfvars`:

```hcl
name_prefix = "jambonz-test"
zone        = "ch-gva-2"
url_portal  = "jambonz.example.com"

# Custom templates
template_web_monitoring = "jambonz-web-monitoring"
template_sbc            = "jambonz-sbc"
template_feature_server = "jambonz-feature-server"
template_recording      = "jambonz-recording"

# SSH key
ssh_public_key = "ssh-rsa AAAAB3... your-email@example.com"

# Minimal instance counts
sbc_count                = 1
feature_server_count     = 1
deploy_recording_cluster = false

# Hobbyist database plans (~€77/month for both)
mysql_plan  = "hobbyist-2"
valkey_plan = "hobbyist-2"

# Standard medium instances (2 vCPU, 4GB RAM)
instance_type_web     = "standard.medium"
instance_type_sbc     = "standard.medium"
instance_type_feature = "standard.medium"
```

**Estimated Cost**: ~€100-150/month

### Production Configuration (High Availability)

For production with redundancy:

```hcl
name_prefix = "jambonz-prod"

# Multiple instances
sbc_count                = 2
feature_server_count     = 4
recording_server_count   = 2
deploy_recording_cluster = true

# Business tier databases (99.99% SLA)
mysql_plan  = "business-8"
valkey_plan = "business-4"

# Larger instance types (4 vCPU, 8GB RAM)
instance_type_web     = "standard.large"
instance_type_sbc     = "standard.large"
instance_type_feature = "standard.large"
```

**Estimated Cost**: ~€500-800/month

### APIBan Configuration (Optional)

[APIBan](https://www.apiban.org/) is a free service that provides a community-maintained blocklist of known VoIP fraud and spam IP addresses. When configured, jambonz will automatically block SIP traffic from these malicious sources.

To enable APIBan protection:

1. Get a free API key at https://apiban.org/getkey.html
2. Add the key to your `terraform.tfvars`:
   ```hcl
   apiban_key = "your-api-key-here"
   ```

If no key is provided, APIBan protection is simply skipped during deployment.

## Deployment

### Step 1: Initialize

```bash
terraform init
```

### Step 2: Validate Configuration

```bash
terraform validate
terraform fmt
```

### Step 3: Plan

```bash
terraform plan -out=tfplan
```

Review the plan carefully. You should see:
- Private network and security groups
- MySQL and Valkey databases
- Web/monitoring server with elastic IP
- SBC servers with elastic IPs
- Feature server instance pool
- (Optional) Recording server instance pool and load balancer

### Step 4: Apply

```bash
terraform apply tfplan
```

Deployment takes approximately 10-15 minutes:
- 2-3 minutes: Database provisioning
- 5-10 minutes: Compute instances and cloud-init configuration
- 2-3 minutes: Instance pool health checks

### Step 5: Save Outputs

```bash
terraform output > deployment-info.txt
terraform output -json > deployment-info.json
```

## SSH Access

### Overview

- **Web/Monitoring server**: Direct SSH via public IP
- **SBC servers**: Direct SSH via public IPs
- **Feature servers**: SSH via SBC jump server (private IPs only)
- **Recording servers**: SSH via SBC jump server (private IPs only)

### Direct SSH Access

#### Web/Monitoring Server

```bash
# Get the IP from Terraform output
terraform output web_monitoring_public_ip

# SSH directly
ssh jambonz@<web-monitoring-public-ip>
```

#### SBC Servers

```bash
# Get all SBC IPs
terraform output sbc_public_ips

# SSH to specific SBC
ssh jambonz@<sbc-public-ip>
```

### SSH via Jump Server (Feature and Recording Servers)

Feature and Recording servers have private IPs only and must be accessed through an SBC server acting as a jump/bastion host.

#### Method 1: One-liner with -J flag

```bash
# SSH to a feature server
ssh -J jambonz@<sbc-ip> jambonz@<feature-server-private-ip>

# SSH to a recording server
ssh -J jambonz@<sbc-ip> jambonz@<recording-server-private-ip>
```

#### Method 2: SSH Config File

Add this to `~/.ssh/config`:

```bash
# Get the SSH config snippet
terraform output ssh_config_snippet > ~/.ssh/config.jambonz

# Append to your SSH config
cat ~/.ssh/config.jambonz >> ~/.ssh/config
```

Example SSH config:

```
# Web/Monitoring Server
Host jambonz-web
  HostName 185.19.28.123
  User jambonz

# SBC Server 1 (Jump Host)
Host jambonz-sbc-1
  HostName 185.19.28.124
  User jambonz

# Feature Servers (via SBC jump)
Host jambonz-fs-*
  User jambonz
  ProxyJump jambonz-sbc-1

# Recording Servers (via SBC jump)
Host jambonz-rec-*
  User jambonz
  ProxyJump jambonz-sbc-1
```

Then use:

```bash
# Direct SSH to web server
ssh jambonz-web

# Direct SSH to SBC
ssh jambonz-sbc-1

# SSH to feature server via jump (replace with actual private IP)
ssh jambonz-fs-172.20.10.45

# SSH to recording server via jump
ssh jambonz-rec-172.20.10.67
```

### Finding Private IPs

#### Using Exoscale CLI

```bash
# List all instances in the cluster
exo compute instance list --zone ch-gva-2 | grep jambonz

# Get instance pool details
terraform output exoscale_cli_commands
```

#### Using Terraform

```bash
# Feature server pool ID
terraform output feature_server_pool_id

# Get pool instances
exo compute instance-pool show <pool-id> --zone ch-gva-2
```

#### From SBC Server

```bash
# SSH to SBC
ssh jambonz@<sbc-ip>

# List instances on private network
# (requires Exoscale CLI configured on SBC)
exo compute instance list --zone ch-gva-2
```

## DNS Configuration

After deployment, create these DNS A records:

```bash
# Get the required records
terraform output dns_records_required
```

Example records:

```
jambonz.example.com              → 185.19.28.123  (Web/Monitoring)
api.jambonz.example.com          → 185.19.28.123  (Web/Monitoring)
grafana.jambonz.example.com      → 185.19.28.123  (Web/Monitoring)
homer.jambonz.example.com        → 185.19.28.123  (Web/Monitoring)
public-apps.jambonz.example.com  → 185.19.28.123  (Web/Monitoring)
sip.jambonz.example.com          → 185.19.28.124  (Primary SBC)
sip-2.jambonz.example.com        → 185.19.28.125  (Secondary SBC, if multiple)
```

### DNS Propagation

Wait for DNS propagation (5-60 minutes) before accessing services:

```bash
# Check DNS propagation
dig jambonz.example.com
nslookup api.jambonz.example.com
```

## Post-Deployment

### 1. Verify Infrastructure

```bash
# Check all instances are running
exo compute instance list --zone ch-gva-2

# Verify databases are accessible
terraform output mysql_host
terraform output valkey_host
```

### 2. Test SSH Access

```bash
# Web/Monitoring
terraform output ssh_web_monitoring | bash

# SBC
terraform output ssh_sbc

# Feature Server via jump (get private IP from instance pool)
ssh -J jambonz@<sbc-ip> jambonz@<feature-server-private-ip>
```

### 3. Test Database Connectivity

From web/monitoring or feature server:

```bash
# MySQL
mysql -h <mysql-host> -u admin -p
# Password from: terraform output mysql_password

# Valkey
redis-cli -h <valkey-host> -p <valkey-port> PING
```

### 4. Access Portal

```bash
# Get portal URL and credentials
terraform output portal_url
terraform output initial_portal_username
terraform output initial_portal_password

# Open in browser
open $(terraform output -raw portal_url)
```

**Default Credentials**:
- Username: `admin`
- Password: Web/monitoring instance ID (from output)

**IMPORTANT**: Change the password on first login!

### 5. Test Services

```bash
# API health check
curl http://api.jambonz.example.com/health

# Grafana
open http://grafana.jambonz.example.com

# Homer
open http://homer.jambonz.example.com
```

## Scaling

### Scaling Feature Servers

Edit `terraform.tfvars`:

```hcl
feature_server_count = 4  # Scale from 1 to 4
```

Apply changes:

```bash
terraform apply
```

### Scaling Recording Servers

Edit `terraform.tfvars`:

```hcl
deploy_recording_cluster = true  # Enable if disabled
recording_server_count   = 2     # Scale to 2 instances
```

Apply:

```bash
terraform apply
```

### Graceful Scale-Down

Feature servers support graceful scale-down to prevent call drops:

1. **Set drain signal in Valkey**:
   ```bash
   redis-cli -h <valkey-host> -p <valkey-port> SET "drain:<instance-id>" 1
   ```

2. **Feature server will**:
   - Stop accepting new calls (SIGUSR1 signal)
   - Wait up to 900 seconds (configurable) for active calls
   - Self-terminate via Exoscale API

3. **Cron job checks every 30 seconds** for drain signal

## Minimal Cost Configuration

For testing with minimal cost (~€100-150/month):

### Configuration

```hcl
sbc_count                = 1
feature_server_count     = 1
deploy_recording_cluster = false
mysql_plan               = "hobbyist-2"
valkey_plan              = "hobbyist-2"
instance_type_web        = "standard.medium"
instance_type_sbc        = "standard.medium"
instance_type_feature    = "standard.medium"
```

### Cost Breakdown

- **MySQL DBaaS** (hobbyist-2): ~€42/month
- **Valkey DBaaS** (hobbyist-2): ~€35/month
- **Web/Monitoring** (standard.medium): ~€25/month
- **SBC** (standard.medium): ~€25/month
- **Feature Server** (standard.medium): ~€25/month
- **Elastic IPs** (2): ~€5/month
- **Network**: ~€5/month

**Total**: ~€162/month

### Scaling Up Later

You can start minimal and scale up:

```bash
# Edit terraform.tfvars
nano terraform.tfvars

# Change to production settings
sbc_count = 2
feature_server_count = 4
mysql_plan = "business-8"

# Apply changes
terraform apply
```

## Troubleshooting

### Instance Not Starting

Check cloud-init logs on the instance:

```bash
ssh jambonz@<instance-ip>
sudo tail -f /var/log/cloud-init-output.log
```

### Database Connection Issues

1. **Check IP filtering**:
   ```bash
   # Databases only allow connections from VPC CIDR
   # Verify instance is on the private network
   ```

2. **Test connectivity**:
   ```bash
   telnet <mysql-host> 3306
   redis-cli -h <valkey-host> -p <valkey-port> PING
   ```

### Feature Server Not in Pool

Check instance pool status:

```bash
exo compute instance-pool show <pool-id> --zone ch-gva-2
```

Check health:

```bash
# From feature server
curl localhost:3000/health
```

### Cannot SSH to Feature Server

1. **Verify SBC jump server is accessible**:
   ```bash
   ssh jambonz@<sbc-ip>
   ```

2. **Verify feature server is on private network**:
   ```bash
   # From SBC
   ping <feature-server-private-ip>
   ```

3. **Check security groups**:
   ```bash
   # SSH (port 22) should be allowed from VPC CIDR
   ```

### Scaling Issues

If scaling fails:

1. **Check instance pool limits**:
   - Feature servers: 1-10
   - Recording servers: 1-10

2. **Verify template exists**:
   ```bash
   exo compute template list --zone ch-gva-2
   ```

3. **Check quota**:
   ```bash
   exoscale iam quota
   ```

## Backup and Disaster Recovery

### Database Backups

Both MySQL and Valkey have built-in backup retention (varies by plan):

- **Hobbyist**: 1 day
- **Startup**: 2 days
- **Business/Premium**: 7-14 days

Backups are automatic and managed by Exoscale.

### Manual Backup

```bash
# MySQL dump
mysqldump -h <mysql-host> -u admin -p jambones > backup-$(date +%F).sql

# Restore
mysql -h <mysql-host> -u admin -p jambones < backup-YYYY-MM-DD.sql
```

### Disaster Recovery

To recover from complete failure:

1. Ensure custom templates exist
2. Run `terraform apply` to recreate infrastructure
3. Restore database from backup (if needed)
4. Reconfigure DNS records

## Additional Resources

- [Exoscale Documentation](https://community.exoscale.com/documentation/)
- [Exoscale DBaaS MySQL](https://www.exoscale.com/dbaas/mysql/)
- [Exoscale DBaaS Valkey](https://www.exoscale.com/dbaas/valkey/)
- [Jambonz Documentation](https://www.jambonz.org/docs/)

## Support

For issues specific to this Terraform configuration, please open an issue in the repository.

For Jambonz support, visit: https://jambonz.org

For Exoscale support, visit: https://www.exoscale.com/support/
