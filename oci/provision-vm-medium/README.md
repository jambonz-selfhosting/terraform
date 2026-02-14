# jambonz medium - Oracle Cloud Infrastructure (OCI) Terraform Deployment

This Terraform configuration deploys a multi-VM jambonz cluster on Oracle Cloud Infrastructure with managed MySQL and Redis services.

## Architecture

| Component | Description |
|-----------|-------------|
| Web/Monitoring | Portal, API, Grafana, Homer, Jaeger, Redis |
| SBC | drachtio SIP server, rtpengine RTP proxy |
| Feature Server | FreeSWITCH, jambonz apps |
| Recording | Recording server (optional, on private subnet) |
| MySQL | OCI MySQL HeatWave (managed) |

Default: 1 SBC + 1 Feature Server + 1 Web/Monitoring (+ optional Recording)

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
   Allow any-user to manage mysql-family in tenancy where request.user.id = '<your-user-ocid>'
   Allow any-user to manage redis-family in tenancy where request.user.id = '<your-user-ocid>'
   ```

## Quick Start

1. **Clone and configure**:
   ```bash
   cd oci/provision-vm-medium
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values:
   - OCI credentials (tenancy_ocid, user_ocid, fingerprint, private_key_path)
   - Compartment ID
   - Region
   - Image PAR URLs for each role (SBC, Feature Server, Web/Monitoring, Recording)
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

6. **Create DNS records**: After deployment, create A records pointing to the Web/Monitoring server IP:
   - `jambonz.example.com` → `<web_monitoring_ip>`
   - `api.jambonz.example.com` → `<web_monitoring_ip>`
   - `grafana.jambonz.example.com` → `<web_monitoring_ip>`
   - `homer.jambonz.example.com` → `<web_monitoring_ip>`
   - `jaeger.jambonz.example.com` → `<web_monitoring_ip>`
   - `sip.jambonz.example.com` → `<sbc_ip>` (each SBC IP)

## Configuration

### jambonz Images

jambonz images are distributed via **Pre-Authenticated Request (PAR) URLs** from OCI Object Storage. You must provide PAR URLs for each image type:

| Variable | Description |
|----------|-------------|
| `sbc_image_par_url` | PAR URL for SBC image |
| `feature_server_image_par_url` | PAR URL for Feature Server image |
| `web_monitoring_image_par_url` | PAR URL for Web/Monitoring image |
| `recording_image_par_url` | PAR URL for Recording image (optional) |

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
| `sbc_image_par_url` | PAR URL for SBC image |
| `feature_server_image_par_url` | PAR URL for Feature Server image |
| `web_monitoring_image_par_url` | PAR URL for Web/Monitoring image |

### Instance Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `sbc_count` | `1` | Number of SBC instances |
| `sbc_ocpus` | `4` | OCPUs per SBC |
| `sbc_memory_in_gbs` | `8` | Memory per SBC |
| `sbc_disk_size` | `200` | Disk size per SBC |
| `feature_server_count` | `1` | Number of Feature Servers |
| `feature_server_ocpus` | `4` | OCPUs per Feature Server |
| `feature_server_memory_in_gbs` | `8` | Memory per Feature Server |
| `feature_server_disk_size` | `200` | Disk size per Feature Server |
| `web_monitoring_ocpus` | `4` | OCPUs for Web/Monitoring |
| `web_monitoring_memory_in_gbs` | `8` | Memory for Web/Monitoring |
| `web_monitoring_disk_size` | `200` | Disk size for Web/Monitoring |
| `deploy_recording_cluster` | `true` | Deploy recording servers |
| `recording_count` | `1` | Number of Recording servers |

### Database Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `mysql_shape` | `MySQL.VM.Standard.E4.1.8GB` | MySQL HeatWave shape |
| `mysql_storage_size` | `50` | Storage in GB |
| `mysql_username` | `jambonz` | Database username |
| `mysql_password` | `""` | Password (auto-generated if empty) |

### Supported Regions

jambonz can be deployed to any OCI region. See [OCI Regions](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm) for the full list.

## Outputs

After deployment, Terraform will output:

- **portal_url**: URL for the jambonz web portal
- **grafana_url**: URL for Grafana monitoring
- **homer_url**: URL for Homer SIP capture
- **jaeger_url**: URL for Jaeger tracing
- **web_monitoring_ip**: Web/Monitoring server IP
- **sbc_ips**: List of SBC public IPs
- **feature_server_ips**: List of Feature Server IPs
- **mysql_endpoint**: MySQL connection endpoint
- **redis_endpoint**: Redis endpoint (web/monitoring server private IP)

View outputs anytime:
```bash
terraform output
terraform output -json sbc_ips
```

## Destroying the Deployment

To remove all resources:

```bash
terraform destroy
```

**Note**: This will destroy all VMs, managed services, and imported images.

## Troubleshooting

### Authentication Errors

If you see `401-NotAuthenticated`:

1. **Verify API key is uploaded** in OCI Console under your user's API Keys
2. **Verify IAM policy exists**:
   ```bash
   oci iam policy list --compartment-id <tenancy-ocid> --all
   ```
3. **Test authentication**:
   ```bash
   oci os ns get  # Should return your namespace
   ```

### Check logs on any server
```bash
ssh jambonz@<server_ip>
sudo cat /var/log/jambonz-setup.log
sudo cat /var/log/cloud-init-output.log
```

## Related

- [jambonz Documentation](https://docs.jambonz.org/)
- [OCI Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [OCI MySQL HeatWave](https://docs.oracle.com/en-us/iaas/mysql-database/index.html)
