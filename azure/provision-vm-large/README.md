# jambonz Large Cluster - Azure Terraform Deployment

This Terraform configuration deploys a high-capacity jambonz cluster on Azure with fully separated SIP and RTP components for independent scaling.

## Architecture

The deployment creates:

- **Web Server** (1 VM): API server, webapp, public-apps
- **Monitoring Server** (1 VM): Grafana, Homer, Jaeger, InfluxDB, Cassandra
- **SIP Servers** (VMs): drachtio SIP signaling with static public IPs
- **RTP Servers** (VMs): rtpengine media processing with static public IPs
- **Feature Servers** (VMSS): FreeSWITCH-based media servers for call handling
- **Recording Servers** (VMSS, optional): Dedicated recording upload cluster
- **Azure MySQL Flexible Server**: Managed MySQL 8.0 database
- **Azure Redis Cache**: Managed Redis for session state
- **Azure Key Vault**: Secure storage for secrets

## Medium vs Large Architecture

| Component | Medium | Large |
|-----------|--------|-------|
| Web + Monitoring | Combined VM | Separate VMs |
| SIP + RTP | Combined SBC VMs | Separate SIP/RTP VMs |
| Feature Server max | 4 instances | 8 instances |

### Why Separate SIP and RTP?

1. **Independent Scaling**: SIP signaling and RTP media have different resource profiles
   - SIP: CPU-bound (call setup/teardown)
   - RTP: Network/memory-bound (media streaming)
2. **Resource Optimization**: Smaller VMs per role instead of larger combined VMs
3. **Fault Isolation**: SIP issues don't affect RTP and vice versa
4. **Cost Efficiency**: Scale each component based on actual load

## Prerequisites

1. **Azure Account**: Sign up at [azure.microsoft.com](https://azure.microsoft.com/)

2. **Azure CLI**: Install and authenticate:
   ```bash
   brew install azure-cli  # macOS
   az login
   ```

3. **Terraform**: Install Terraform v1.0 or later:
   ```bash
   brew install terraform  # macOS
   ```

## Quick Start

1. **Clone and configure**:
   ```bash
   cd azure/provision-vm-large
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values:
   - Azure subscription and tenant IDs
   - jambonz version (defaults to latest)
   - URL portal domain
   - SSH public key
   - VM sizes and counts

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Preview changes**:
   ```bash
   terraform plan
   ```

5. **Deploy**:
   ```bash
   terraform apply
   ```

6. **Create DNS records**: After deployment, create A records:
   ```
   jambonz.example.com             -> <web_public_ip>
   api.jambonz.example.com         -> <web_public_ip>
   public-apps.jambonz.example.com -> <web_public_ip>
   grafana.jambonz.example.com     -> <monitoring_public_ip>
   homer.jambonz.example.com       -> <monitoring_public_ip>
   jaeger.jambonz.example.com      -> <monitoring_public_ip>
   sip.jambonz.example.com         -> <sip_public_ip[0]>
   ```

## Configuration

### jambonz Images

jambonz images are published to an **Azure Community Gallery** and are automatically pulled during deployment. No image building or manual setup is required.

The large deployment uses 6 separate images (Web, Monitoring, SIP, RTP, Feature Server, Recording) for independent scaling.

| Variable | Default | Description |
|----------|---------|-------------|
| `jambonz_version` | `10.0.4` | jambonz version to deploy |
| `community_gallery_name` | `jambonz-8962e4f5-da0f-41ee-b094-8680ad38d302` | Azure Community Gallery name |

To use a different version, set `jambonz_version` in your `terraform.tfvars`:
```hcl
jambonz_version = "10.0.5"
```

### Required Variables

| Variable | Description |
|----------|-------------|
| `subscription_id` | Azure subscription ID |
| `tenant_id` | Azure tenant ID |
| `ssh_public_key` | SSH public key for VM access |
| `url_portal` | DNS name for the jambonz portal |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `jambonz_version` | `10.0.4` | jambonz version to deploy |
| `location` | `eastus` | Azure region (see supported regions below) |
| `name_prefix` | `jambonz` | Prefix for resource names |
| `sip_count` | `2` | Number of SIP servers |
| `rtp_count` | `2` | Number of RTP servers |
| `web_vm_size` | `Standard_F2s_v2` | VM size for Web server |
| `monitoring_vm_size` | `Standard_F4s_v2` | VM size for Monitoring server |
| `sip_vm_size` | `Standard_F2s_v2` | VM size for SIP servers |
| `rtp_vm_size` | `Standard_F2s_v2` | VM size for RTP servers |
| `feature_server_vm_size` | `Standard_F4s_v2` | VM size for Feature Servers |
| `feature_server_desired_capacity` | `2` | Initial Feature Server count |
| `feature_server_max_capacity` | `8` | Maximum Feature Server count |
| `deploy_recording_cluster` | `true` | Deploy recording server cluster |
| `enable_pcaps` | `true` | Enable SIP PCAP capture |
| `apiban_key` | `""` | APIBan API key for single-key mode |
| `apiban_client_id` | `""` | APIBan client ID for multi-key mode |
| `apiban_client_secret` | `""` | APIBan client secret for multi-key mode |

### Supported Regions

jambonz images are available in the following Azure regions:

| Region | Americas | Europe | Asia Pacific |
|--------|----------|--------|--------------|
| | eastus | northeurope | australiaeast |
| | eastus2 | westeurope | southeastasia |
| | westus2 | uksouth | japaneast |
| | westus3 | francecentral | koreacentral |
| | centralus | germanywestcentral | centralindia |
| | northcentralus | swedencentral | |
| | southcentralus | | |
| | canadacentral | | |
| | brazilsouth | | |

**Need a different region?** Contact [support@jambonz.org](mailto:support@jambonz.org) to request additional regions.

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

Each SIP instance will automatically provision its own unique API key at boot time.

**Note:** If both are provided, client credentials take precedence.

### Using Environment Variables

```bash
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
terraform apply
```

## Scaling

### Scaling SIP/RTP Servers

SIP and RTP are individual VMs (not VMSS). To add more:

1. Update `terraform.tfvars`:
   ```hcl
   sip_count = 3  # Increase from 2 to 3
   rtp_count = 3  # Increase from 2 to 3
   ```
2. Run `terraform apply`

### Scaling Feature Servers

Feature Servers use VMSS with manual scaling:

```bash
# Scale Feature Servers to 4 instances
az vmss scale --name jambonz-fs-vmss --resource-group jambonz-rg --new-capacity 4
```

### Graceful Termination

All VMSS instances have a 15-minute termination notification enabled. When Azure scales in:

1. The VM receives a `Terminate` event via Azure Scheduled Events
2. A cron job polls for this event every 30 seconds
3. When detected, it signals jambonz apps to stop accepting new calls
4. Existing calls have up to 15 minutes to complete
5. After timeout (or early approval), the VM terminates

## Outputs

After deployment, view outputs:
```bash
terraform output
terraform output -raw web_public_ip
terraform output -raw monitoring_public_ip
terraform output -json sip_public_ips
terraform output -json rtp_public_ips
terraform output -json dns_records_required
```

Key outputs:
- **portal_url**: URL for the jambonz web portal
- **grafana_url**: URL for Grafana monitoring
- **web_public_ip**: IP for portal/API DNS records
- **monitoring_public_ip**: IP for monitoring DNS records
- **sip_public_ips**: IPs for SIP servers
- **rtp_public_ips**: IPs for RTP servers
- **portal_password**: Initial admin password (Web VM ID)

## VM Sizes

Recommended VM sizes:

| Role | Development | Production | High Volume |
|------|-------------|------------|-------------|
| Web | Standard_B2s | Standard_F2s_v2 | Standard_F4s_v2 |
| Monitoring | Standard_B2s | Standard_F4s_v2 | Standard_D4s_v3 |
| SIP | Standard_B2s | Standard_F2s_v2 | Standard_F4s_v2 |
| RTP | Standard_B2s | Standard_F2s_v2 | Standard_F4s_v2 |
| Feature Server | Standard_B2s | Standard_F4s_v2 | Standard_F8s_v2 |
| Recording | Standard_B2s | Standard_D2s_v3 | Standard_D4s_v3 |

## SSH Access

```bash
# Web server
ssh jambonz@<web_public_ip>

# Monitoring server
ssh jambonz@<monitoring_public_ip>

# SIP server
ssh jambonz@<sip_public_ip>

# RTP server
ssh jambonz@<rtp_public_ip>

# Feature Server (via jump host)
ssh -J jambonz@<sip_public_ip> jambonz@<fs_private_ip>
```

## Destroying the Deployment

To remove all resources:

```bash
terraform destroy
```

**Warning**: This will destroy all resources including the database. Back up data first.

## Troubleshooting

### Check cloud-init logs
```bash
ssh jambonz@<ip>
sudo cat /var/log/jambonz-setup.log
sudo cat /var/log/cloud-init-output.log
```

### Check service status
```bash
# On SIP server
sudo systemctl status drachtio
pm2 list

# On RTP server
sudo systemctl status rtpengine
pm2 list

# On Feature Server
sudo systemctl status freeswitch
pm2 list
```

### Verify SIP-RTP connectivity

On a SIP server, verify the rtpengine connection string:
```bash
grep RTPENGINES /home/jambonz/apps/ecosystem.config.js

# Test connectivity to RTP servers
nc -zvu <rtp_private_ip> 22222
```

### Check VMSS instance status
```bash
az vmss list-instances --name jambonz-fs-vmss --resource-group jambonz-rg -o table
```

### View MySQL connection
```bash
# From any jambonz VM
mysql -h <mysql_fqdn> -u jambonz -p jambones
```

## Related

- [jambonz Documentation](https://docs.jambonz.org/)
- [Azure Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure VM Sizes](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes)
- [Azure MySQL Flexible Server](https://docs.microsoft.com/en-us/azure/mysql/flexible-server/)
