# jambonz Medium Cluster - Azure Terraform Deployment

This Terraform configuration deploys a production-ready jambonz cluster on Azure, equivalent to the AWS CloudFormation medium deployment.

## Architecture

The deployment creates:

- **Web/Monitoring Server** (1 VM): API server, webapp, Grafana, Homer, Jaeger, InfluxDB
- **SBC Servers** (VMSS): Session Border Controllers with drachtio, rtpengine
- **Feature Servers** (VMSS): FreeSWITCH-based media servers for call handling
- **Recording Servers** (VMSS, optional): Dedicated recording upload cluster
- **Azure MySQL Flexible Server**: Managed MySQL 8.0 database
- **Azure Redis Cache**: Managed Redis for session state
- **Azure Key Vault**: Secure storage for secrets

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
   cd azure/provision-cluster-medium
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values:
   - Azure subscription and tenant IDs
   - jambonz version (defaults to latest)
   - URL portal domain
   - SSH public key
   - VM sizes and scale set capacities

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
   jambonz.example.com         -> <web_monitoring_public_ip>
   api.jambonz.example.com     -> <web_monitoring_public_ip>
   grafana.jambonz.example.com -> <web_monitoring_public_ip>
   homer.jambonz.example.com   -> <web_monitoring_public_ip>
   sip.jambonz.example.com     -> <sbc_public_ip>
   ```

## Configuration

### jambonz Images

jambonz images are published to an **Azure Community Gallery** and are automatically pulled during deployment. No image building or manual setup is required.

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
| `sbc_vm_size` | `Standard_F4s_v2` | VM size for SBC |
| `feature_server_vm_size` | `Standard_F4s_v2` | VM size for Feature Server |
| `web_monitoring_vm_size` | `Standard_F4s_v2` | VM size for Web/Monitoring |
| `sbc_desired_capacity` | `1` | Initial SBC instance count |
| `feature_server_desired_capacity` | `1` | Initial Feature Server count |
| `deploy_recording_cluster` | `true` | Deploy recording server cluster |
| `enable_pcaps` | `true` | Enable SIP PCAP capture |
| `apiban_key` | `""` | APIBan API key for single-key mode |
| `apiban_client_id` | `""` | APIBan client ID for multi-key mode |
| `apiban_client_secret` | `""` | APIBan client secret for multi-key mode |

### Supported Regions

jambonz images are available in the following Azure regions:

| Region | Americas | Europe | Asia Pacific | Africa |
|--------|----------|--------|--------------|--------|
| | eastus | northeurope | australiaeast | southafricanorth |
| | eastus2 | westeurope | southeastasia | |
| | westus2 | uksouth | japaneast | |
| | westus3 | francecentral | koreacentral | |
| | centralus | germanywestcentral | centralindia | |
| | northcentralus | swedencentral | | |
| | southcentralus | | | |
| | canadacentral | | | |
| | brazilsouth | | | |

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

Each instance will automatically provision its own unique API key at boot time.

**Note:** If both are provided, client credentials take precedence.

### Using Environment Variables

```bash
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
terraform apply
```

## Scale Set Auto-Scaling

The SBC and Feature Server VMSS support manual scaling:

```bash
# Scale SBC to 2 instances
az vmss scale --name jambonz-sbc-vmss --resource-group jambonz-rg --new-capacity 2

# Scale Feature Servers to 3 instances
az vmss scale --name jambonz-fs-vmss --resource-group jambonz-rg --new-capacity 3
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
terraform output -raw web_monitoring_public_ip
terraform output -raw sbc_public_ip
terraform output -json dns_records_required
```

Key outputs:
- **portal_url**: URL for the jambonz web portal
- **grafana_url**: URL for Grafana monitoring
- **web_monitoring_public_ip**: IP for web DNS records
- **sbc_public_ip**: IP for SIP DNS records
- **portal_password**: Initial admin password (VM ID)

## VM Sizes

Recommended VM sizes:

| Role | Development | Production | High Volume |
|------|-------------|------------|-------------|
| SBC | Standard_B2s | Standard_F4s_v2 | Standard_F8s_v2 |
| Feature Server | Standard_B2s | Standard_F4s_v2 | Standard_F8s_v2 |
| Web/Monitoring | Standard_B2s | Standard_F4s_v2 | Standard_D4s_v3 |
| Recording | Standard_B2s | Standard_D2s_v3 | Standard_D4s_v3 |

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
sudo systemctl status drachtio
sudo systemctl status rtpengine
sudo systemctl status freeswitch
sudo systemctl status nginx
pm2 list
```

### Check VMSS instance status
```bash
az vmss list-instances --name jambonz-sbc-vmss --resource-group jambonz-rg -o table
```

### View MySQL connection
```bash
# From any jambonz VM
mysql -h <mysql_fqdn> -u admin -p jambones
```

## Differences from AWS CloudFormation

| Feature | AWS | Azure |
|---------|-----|-------|
| Database | Aurora Serverless v2 | MySQL Flexible Server |
| Cache | ElastiCache Redis | Azure Redis Cache |
| Secrets | Secrets Manager | Key Vault |
| Auto Scaling | ASG + Lifecycle Hooks | VMSS + Termination Notification |
| Lifecycle timeout | Up to 48 hours | 15 minutes max |
| SNS notifications | Push to app | Poll from VM |

## Related

- [jambonz Documentation](https://docs.jambonz.org/)
- [Azure Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure VM Sizes](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes)
- [Azure MySQL Flexible Server](https://docs.microsoft.com/en-us/azure/mysql/flexible-server/)
