# jambonz Large Cluster - Azure Terraform Deployment

This Terraform configuration deploys a high-capacity jambonz cluster on Azure with fully separated SIP and RTP components for independent scaling.

## Architecture

The deployment creates:

- **Web Server** (1 VM): API server, webapp, public-apps
- **Monitoring Server** (1 VM): Grafana, Homer, Jaeger, InfluxDB, Cassandra
- **SIP Servers** (VMs): drachtio SIP signaling with static public IPs
- **RTP Servers** (VMs): rtpengine media processing with static public IPs
- **Feature Servers** (VMSS): drachtio + mediajam media servers for call handling
- **Recording Servers** (VMSS, optional): Dedicated recording upload cluster
- **Azure MySQL Flexible Server**: Managed MySQL 8.0 database
- **Azure Managed Redis**: Managed Redis for session state, reached through a private endpoint
- **Azure Key Vault**: Holds every secret; VMs read them at boot with their managed identity
- **Log Analytics workspace**: syslog, jambonz application logs and the MySQL audit log, kept for `log_retention_days`

## Availability zones and security

The defaults are built to pass a SOC 2 audit and to survive the loss of one availability zone.

- **Zone redundancy** (`zones`, default `["1","2","3"]`): SIP and RTP servers are placed round-robin across zones, the feature server and recording scale sets are balanced across them, every public IP and the recording load balancer are zone-redundant, and MySQL keeps a standby in a second zone with automatic failover. Redis keeps its replica in another zone. The web and monitoring servers are single VMs and are not redundant. Set `zones = []` in a region without availability zones.
- **SSH is closed unless you open it**: `allowed_ssh_cidr` has no default. Supply your admin IP as a `/32` or your VPN range.
- **Every port is listed per role**: each NSG allows only that role's ports and ends with a rule that denies all other traffic from inside the VNet. Azure otherwise allows all VNet traffic by default.
- **No secrets in `custom_data`**: the MySQL password, Redis key, encryption secret and optional apiban/Krisp keys are stored in Key Vault. Each VM reads the ones it needs at boot with its managed identity, which can read secrets by name and has no other Azure permissions. Setup scripts no longer run with `bash -x`, so secrets are not echoed into `/var/log/jambonz-setup.log`.
- **Database**: encrypted at rest (always on for Flexible Server), 30 days of backups, connection auditing to Log Analytics, and a `CanNotDelete` lock (`mysql_delete_lock`).
- **Redis**: public network access is disabled; the VNet reaches it through a private endpoint.
- **Logs**: the Azure Monitor Agent on every VM and scale set sends syslog (including SSH logins) and the jambonz application logs to Log Analytics, kept for `log_retention_days` (90, 180 or 365).

Managed disks are encrypted at rest by Azure, and Azure's instance metadata service already requires the `Metadata: true` header, so neither needs configuring.

Not yet done: MySQL still accepts unencrypted connections (`require_secure_transport = OFF`) until drachtio and upload-recordings are confirmed to work over TLS. That traffic stays on the private delegated subnet. Terraform state contains every secret, so keep it in an encrypted remote backend with restricted access.

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
| `jambonz_version` | `11.1.2` | jambonz version to deploy |
| `community_gallery_name` | `jambonz-8962e4f5-da0f-41ee-b094-8680ad38d302` | Azure Community Gallery name |

To use a different version, set `jambonz_version` in your `terraform.tfvars`:
```hcl
jambonz_version = "11.1.2"
```

### Required Variables

| Variable | Description |
|----------|-------------|
| `subscription_id` | Azure subscription ID |
| `tenant_id` | Azure tenant ID |
| `ssh_public_key` | SSH public key for VM access |
| `url_portal` | DNS name for the jambonz portal |
| `allowed_ssh_cidr` | Source range allowed to SSH: your admin IP as `/32`, or your VPN range |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `jambonz_version` | `11.1.2` | jambonz version to deploy |
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
| `zones` | `["1","2","3"]` | Availability zones to spread across; `[]` for none |
| `mysql_sku_name` | `GP_Standard_D2ds_v4` | MySQL SKU; Burstable SKUs need `mysql_high_availability = false` |
| `mysql_high_availability` | `true` | Zone-redundant MySQL standby with automatic failover |
| `mysql_delete_lock` | `true` | `CanNotDelete` lock on the MySQL server |
| `log_retention_days` | `90` | Log Analytics retention: 90, 180 or 365 |

### Supported Regions

jambonz images are available in the following Azure regions:

| Region | Americas | Europe | Asia Pacific | Africa | Middle East |
|--------|----------|--------|--------------|--------|-------------|
| | eastus | northeurope | australiaeast | southafricanorth | uaenorth |
| | eastus2 | westeurope | southeastasia | | |
| | westus2 | uksouth | japaneast | | |
| | westus3 | francecentral | koreacentral | | |
| | centralus | germanywestcentral | centralindia | | |
| | northcentralus | swedencentral | | | |
| | southcentralus | | | | |
| | canadacentral | | | | |
| | brazilsouth | | | | |

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
- **portal_password**: Initial admin password (hidden by default, see below)

### Accessing the Portal

The initial admin password is the Web VM's instance ID. Since it's marked as sensitive, retrieve it with:

```bash
terraform output portal_password
```

Login credentials:
- **Username**: admin
- **Password**: (output of command above)

You will be prompted to change the password on first login.

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

# Feature Server (each instance has a public IP; SSH from allowed_ssh_cidr only).
# A jump through another VM no longer works: NSGs deny SSH from inside the VNet.
az vmss list-instance-public-ips -g <name_prefix>-rg -n <name_prefix>-fs-vmss -o table
ssh jambonz@<fs_public_ip>
```

## Destroying the Deployment

To remove all resources:

```bash
terraform destroy
```

**Warning**: This will destroy all resources including the database. Back up data first.

`terraform destroy` removes the MySQL delete lock before the server, so it is not blocked. Deleting the resource group any other way (portal, `az group delete`) fails until you remove the lock.

If `terraform destroy` fails with `InUseSubnetCannotBeDeleted` on the MySQL subnet, wait a few minutes and run it again. Azure keeps the deleted server's link on its delegated subnet for a short time after the server is gone.

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
sudo systemctl status mediajam
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
