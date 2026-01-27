# jambonz mini - Exoscale Terraform Deployment

This Terraform configuration deploys a single-instance jambonz server on Exoscale
## Prerequisites

1. **Exoscale Account**: Sign up at [exoscale.com](https://www.exoscale.com/)

2. **API Credentials**: Create an API key in the Exoscale console:
   - Go to IAM > API Keys
   - Create a new key with Compute permissions

3. **Terraform**: Install Terraform v1.0 or later:
   ```bash
   brew install terraform  # macOS
   ```

## Quick Start

1. **Clone and configure**:
   ```bash
   cd exoscale/provision-vm-mini
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values:
   - Exoscale API credentials
   - Template name
   - URL portal domain
   - SSH key

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

   Note: Exoscale instance IPs are stable across reboots, unlike AWS.

## Configuration

### Required Variables

| Variable | Description |
|----------|-------------|
| `exoscale_api_key` | Exoscale API key |
| `exoscale_api_secret` | Exoscale API secret |
| `template_name` | Name of the jambonz template in Exoscale |
| `url_portal` | DNS name for the jambonz portal |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `zone` | `ch-gva-2` | Exoscale zone |
| `instance_type` | `standard.medium` | Instance size |
| `disk_size` | `50` | Disk size in GB |
| `allowed_ssh_cidr` | `0.0.0.0/0` | CIDR for SSH access |
| `allowed_http_cidr` | `0.0.0.0/0` | CIDR for HTTP access |
| `allowed_sip_cidr` | `0.0.0.0/0` | CIDR for SIP access |
| `allowed_rtp_cidr` | `0.0.0.0/0` | CIDR for RTP access |
| `apiban_key` | `""` | APIBan API key for VoIP fraud protection |

### APIBan Configuration (Optional)

[APIBan](https://www.apiban.org/) is a free service that provides a community-maintained blocklist of known VoIP fraud and spam IP addresses. When configured, jambonz will automatically block SIP traffic from these malicious sources.

To enable APIBan protection:

1. Get a free API key at https://apiban.org/getkey.html
2. Add the key to your `terraform.tfvars`:
   ```hcl
   apiban_key = "your-api-key-here"
   ```

If no key is provided, APIBan protection is simply skipped during deployment.

### Using Environment Variables

Instead of storing credentials in `terraform.tfvars`:

```bash
export TF_VAR_exoscale_api_key="EXO..."
export TF_VAR_exoscale_api_secret="..."
terraform apply
```

## Outputs

After deployment, Terraform will output:

- **portal_url**: URL for the jambonz web portal
- **grafana_url**: URL for Grafana monitoring
- **homer_url**: URL for Homer SIP capture
- **server_ip**: Instance public IP address for DNS records (stable across reboots)
- **admin_user**: Portal username (admin)
- **admin_password**: Initial password (instance ID)
- **ssh_connection**: SSH command to connect

View outputs anytime:
```bash
terraform output
terraform output -raw server_ip
```

## Instance Types

Recommended instance types for jambonz:

| Type | vCPUs | RAM | Use Case |
|------|-------|-----|----------|
| `standard.large` | 4 | 8GB | Production |
| `standard.extra-large` | 4 | 16GB | Heavy production |
| `cpu.extra-large` | 8 | 16GB | High call volume |

## Post-install steps

TDB.  Follow the standard steps to configure HTTPS.

## Destroying the Deployment

To remove all resources:

```bash
terraform destroy
```

**Note**: This will destroy the instance and release its IP address. If you need to preserve your data, back up the instance first.

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

## Related

- [jambonz Documentation](https://docs.jambonz.org/)
- [Exoscale Terraform Provider](https://registry.terraform.io/providers/exoscale/exoscale/latest/docs)
- [Exoscale Zones](https://www.exoscale.com/datacenters/)
