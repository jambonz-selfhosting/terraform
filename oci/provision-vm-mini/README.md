# jambonz mini - Oracle Cloud Infrastructure (OCI) Terraform Deployment

This Terraform configuration deploys a single-instance jambonz server on Oracle Cloud Infrastructure.

## Prerequisites

1. **OCI Account**: Sign up at [oracle.com/cloud](https://www.oracle.com/cloud/)

2. **OCI CLI**: Install and configure:
   ```bash
   brew install oci-cli  # macOS
   oci setup config      # Creates ~/.oci/config and API key
   ```

3. **Terraform**: Install Terraform v1.0 or later:
   ```bash
   brew install terraform  # macOS
   ```

4. **API Key**: Generate an API signing key pair and upload the public key to OCI Console:
   - During `oci setup config`, a key pair is automatically generated
   - The public key is uploaded to your user profile
   - Note the fingerprint shown after upload

5. **IAM Policy**: Your user needs permissions to create resources. Create a policy in the **root compartment**:

   **Option A - Via OCI CLI** (recommended):
   ```bash
   oci iam policy create \
     --compartment-id <your-tenancy-ocid> \
     --name "jambonz-admin-policy" \
     --description "Full admin access for jambonz deployment" \
     --statements '["Allow any-user to manage all-resources in tenancy where request.user.id = '\''<your-user-ocid>'\''"]'
   ```

   **Option B - Via OCI Console**:
   1. Go to **Identity & Security** → **Policies**
   2. Click **Create Policy** in the root compartment
   3. Name: `jambonz-admin-policy`
   4. Add statement:
      ```
      Allow any-user to manage all-resources in tenancy where request.user.id = '<your-user-ocid>'
      ```

   **Option C - Minimal permissions** (more restrictive):
   ```
   Allow any-user to read all-resources in tenancy where request.user.id = '<your-user-ocid>'
   Allow any-user to manage virtual-network-family in tenancy where request.user.id = '<your-user-ocid>'
   Allow any-user to manage instance-family in tenancy where request.user.id = '<your-user-ocid>'
   Allow any-user to manage volume-family in tenancy where request.user.id = '<your-user-ocid>'
   Allow any-user to manage object-family in tenancy where request.user.id = '<your-user-ocid>'
   ```

## Quick Start

1. **Clone and configure**:
   ```bash
   cd oci/provision-vm-mini
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values:
   - OCI credentials (tenancy_ocid, user_ocid, fingerprint, private_key_path)
   - Compartment ID (can be the tenancy OCID for root compartment)
   - Region
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
   - `jaeger.jambonz.example.com` → `<server_ip>`
   - `sip.jambonz.example.com` → `<server_ip>`

   Note: OCI Reserved Public IPs are stable across reboots.

## Configuration

### jambonz Images

jambonz images are distributed via **Pre-Authenticated Request (PAR) URLs** from OCI Object Storage. The default PAR URL points to the official jambonz mini image and is imported into your tenancy during deployment.

| Variable | Default | Description |
|----------|---------|-------------|
| `image_par_url` | (official jambonz image) | PAR URL for the jambonz mini image |

To use a custom image, set `image_par_url` in your `terraform.tfvars`:
```hcl
image_par_url = "https://objectstorage.us-ashburn-1.oraclecloud.com/p/xxxxx/n/namespace/b/bucket/o/custom-image.oci"
```

### Required Variables

| Variable | Description |
|----------|-------------|
| `tenancy_ocid` | OCI tenancy OCID |
| `user_ocid` | OCI user OCID |
| `fingerprint` | API key fingerprint |
| `private_key_path` | Path to API private key file |
| `compartment_id` | Compartment OCID for resources |
| `ssh_public_key` | SSH public key for VM access |
| `url_portal` | DNS name for the jambonz portal |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `us-ashburn-1` | OCI region |
| `shape` | `VM.Standard.E4.Flex` | Compute shape |
| `ocpus` | `4` | Number of OCPUs |
| `memory_in_gbs` | `8` | Memory in GB |
| `disk_size` | `200` | Boot volume size in GB |
| `allowed_ssh_cidr` | `0.0.0.0/0` | CIDR for SSH access |
| `allowed_http_cidr` | `0.0.0.0/0` | CIDR for HTTP access |
| `allowed_sip_cidr` | `0.0.0.0/0` | CIDR for SIP access |
| `allowed_rtp_cidr` | `0.0.0.0/0` | CIDR for RTP access |
| `apiban_key` | `""` | APIBan API key for single-key mode |
| `apiban_client_id` | `""` | APIBan client ID for multi-key mode |
| `apiban_client_secret` | `""` | APIBan client secret for multi-key mode |

### Supported Regions

jambonz can be deployed to any OCI region. Common regions include:

| Americas | Europe | Asia Pacific |
|----------|--------|--------------|
| us-ashburn-1 | eu-frankfurt-1 | ap-tokyo-1 |
| us-phoenix-1 | eu-amsterdam-1 | ap-sydney-1 |
| us-sanjose-1 | uk-london-1 | ap-singapore-1 |
| ca-toronto-1 | eu-zurich-1 | ap-melbourne-1 |
| sa-saopaulo-1 | eu-madrid-1 | ap-osaka-1 |

See [OCI Regions](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm) for the full list.

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

## Outputs

After deployment, Terraform will output:

- **portal_url**: URL for the jambonz web portal
- **grafana_url**: URL for Grafana monitoring
- **homer_url**: URL for Homer SIP capture
- **jaeger_url**: URL for Jaeger tracing
- **public_ip**: Public IP address for DNS records (stable across reboots)
- **private_ip**: Private IP address
- **instance_id**: OCI instance OCID
- **admin_user**: Portal username (admin)
- **admin_password**: Initial password (sensitive)
- **ssh_connection**: SSH command to connect

View outputs anytime:
```bash
terraform output
terraform output -raw public_ip
terraform output -raw admin_password
```

## Compute Shapes

OCI uses flexible shapes where you specify OCPUs and memory separately. Recommended configurations:

| OCPUs | Memory | Use Case |
|-------|--------|----------|
| 2 | 8GB | Development/Testing |
| 4 | 8GB | Production (default) |
| 4 | 16GB | Heavy production |
| 8 | 32GB | High-volume deployments |

Supported flexible shapes:
- `VM.Standard.E4.Flex` (AMD, default)
- `VM.Standard.E5.Flex` (AMD, newer)
- `VM.Standard3.Flex` (Intel)
- `VM.Optimized3.Flex` (Intel, high-frequency)

## Post-install Steps

TBD. Follow the standard steps to configure HTTPS.

## Destroying the Deployment

To remove all resources:

```bash
terraform destroy
```

**Note**: This will destroy the VM, VCN, imported image, and all associated resources. If you need to preserve your data, back up the VM first.

## Troubleshooting

### Authentication Errors

If you see `401-NotAuthenticated`:

1. **Verify API key is uploaded**:
   - Go to **Identity & Security** → **Domains** → **Default** → **Users** → (your user) → **API Keys**
   - Confirm the fingerprint matches your `~/.oci/config`

2. **Verify IAM policy exists**:
   ```bash
   oci iam policy list --compartment-id <tenancy-ocid> --all
   ```

3. **Test authentication**:
   ```bash
   oci os ns get  # Should return your namespace
   ```

### Check cloud-init logs
```bash
ssh opc@<server_ip>
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

### OCI-specific issues

Check instance console connection:
```bash
oci compute instance-console-connection create --instance-id <instance-ocid>
```

Or view serial console output in the OCI Console under Compute → Instances → (your instance) → Console connection.

## Related

- [jambonz Documentation](https://docs.jambonz.org/)
- [OCI Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [OCI Regions](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm)
- [OCI Compute Shapes](https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm)
