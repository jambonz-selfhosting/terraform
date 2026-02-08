# jambonz mini - Azure Terraform Deployment

This Terraform configuration deploys a single-instance jambonz server on Azure.

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
   cd azure/provision-vm-mini
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values:
   - Azure subscription and tenant IDs
   - jambonz version (defaults to latest)
   - URL portal domain
   - SSH public key

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

6. **Create DNS records**: After deployment, create A records pointing to the server IP (shown in terraform output):
   - `jambonz.example.com` → `<server_ip>`
   - `api.jambonz.example.com` → `<server_ip>`
   - `grafana.jambonz.example.com` → `<server_ip>`
   - `homer.jambonz.example.com` → `<server_ip>`
   - `sip.jambonz.example.com` → `<server_ip>`

   Note: Azure Static Public IPs are stable across reboots.

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
| `vm_size` | `Standard_D2s_v3` | VM size |
| `disk_size` | `100` | OS disk size in GB |
| `allowed_ssh_cidr` | `0.0.0.0/0` | CIDR for SSH access |
| `allowed_http_cidr` | `0.0.0.0/0` | CIDR for HTTP access |
| `allowed_sip_cidr` | `0.0.0.0/0` | CIDR for SIP access |
| `allowed_rtp_cidr` | `0.0.0.0/0` | CIDR for RTP access |
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

Each instance will automatically provision its own unique API key at boot time.

**Note:** If both are provided, client credentials take precedence.

### Using Environment Variables

Instead of storing credentials in `terraform.tfvars`:

```bash
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
terraform apply
```

Or authenticate via Azure CLI:
```bash
az login
terraform apply
```

## Outputs

After deployment, Terraform will output:

- **portal_url**: URL for the jambonz web portal
- **grafana_url**: URL for Grafana monitoring
- **homer_url**: URL for Homer SIP capture
- **server_ip**: Public IP address for DNS records (stable across reboots)
- **resource_group_name**: Azure resource group name
- **vm_name**: Azure VM name
- **admin_user**: Portal username (admin)
- **admin_password**: Initial password (VM instance ID)
- **ssh_connection**: SSH command to connect

View outputs anytime:
```bash
terraform output
terraform output -raw server_ip
```

## VM Sizes

Recommended VM sizes for jambonz:

| Size | vCPUs | RAM | Use Case |
|------|-------|-----|----------|
| `Standard_D2s_v3` | 2 | 8GB | Development/Testing |
| `Standard_D4s_v3` | 4 | 16GB | Production |
| `Standard_D8s_v3` | 8 | 32GB | Heavy production |
| `Standard_F4s_v2` | 4 | 8GB | CPU-optimized |

## Post-install Steps

TBD. Follow the standard steps to configure HTTPS.

## Destroying the Deployment

To remove all resources:

```bash
terraform destroy
```

**Note**: This will destroy the VM, resource group, and all associated resources. If you need to preserve your data, back up the VM first.

## Troubleshooting

### Check cloud-init logs
```bash
ssh jambonz@<server_ip>
sudo cat /var/log/jambonz-setup.log
sudo cat /var/log/cloud-init-output.log
```

### Check service status
```bash
sudo systemctl status drachtio
sudo systemctl status rtpengine
sudo systemctl status nginx
pm2 list
```

### Azure-specific issues

Check VM boot diagnostics in the Azure portal, or use:
```bash
az vm boot-diagnostics get-boot-log --name <vm-name> --resource-group <resource-group>
```

## Related

- [jambonz Documentation](https://docs.jambonz.org/)
- [Azure Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Regions](https://azure.microsoft.com/en-us/global-infrastructure/locations/)
