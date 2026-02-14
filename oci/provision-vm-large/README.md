# jambonz large - Oracle Cloud Infrastructure (OCI) Terraform Deployment

This Terraform configuration deploys a fully separated multi-VM jambonz cluster on Oracle Cloud Infrastructure with managed MySQL.

## Architecture

The large deployment separates SIP and RTP into dedicated servers (unlike medium which combines them into a single SBC), and separates web and monitoring into dedicated servers.

| Component | Default Count | Description |
|-----------|---------------|-------------|
| Monitoring | 1 | Redis, Grafana, Homer, Jaeger, InfluxDB |
| Web | 1 | Portal, API, webapp |
| SIP | 2 | drachtio SIP signaling |
| RTP | 2 | rtpengine media proxy |
| Feature Server | 4 | FreeSWITCH, jambonz apps |
| Recording | 2 | Recording server (optional) |
| MySQL | 1 | OCI MySQL HeatWave (managed) |

Redis runs on the monitoring server (not a managed service).

### Dependency Chain

Instances come up in this order:
1. **Monitoring** - Must be first (provides Redis to all other servers)
2. **Web** and **RTP** - Depend on monitoring
3. **SIP** - Depends on monitoring and RTP (needs RTP private IPs)
4. **Feature Server** and **Recording** - Depend on monitoring

## Prerequisites

See the [main OCI README](../README.md) for:
- OCI account setup
- OCI CLI installation and configuration
- API key generation
- IAM policy requirements

## Quick Start

1. **Clone and configure**:
   ```bash
   cd oci/provision-vm-large
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values (see terraform.tfvars.example for all options)

3. **Deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Create DNS records**: After deployment, create A records pointing to the Web server IP:
   - `jambonz.example.com` → `<web_public_ip>`
   - `api.jambonz.example.com` → `<web_public_ip>`
   - `grafana.jambonz.example.com` → `<web_public_ip>`
   - `homer.jambonz.example.com` → `<web_public_ip>`
   - `public-apps.jambonz.example.com` → `<web_public_ip>`
   - `sip.jambonz.example.com` → `<sip_public_ip>`

## Configuration

### jambonz Images

The large deployment uses separate images for each role. Default PAR URLs point to official jambonz images.

| Variable | Description |
|----------|-------------|
| `sip_image_par_url` | PAR URL for SIP image (drachtio only) |
| `rtp_image_par_url` | PAR URL for RTP image (rtpengine only) |
| `web_image_par_url` | PAR URL for Web image (portal, API) |
| `monitoring_image_par_url` | PAR URL for Monitoring image (Grafana, Homer, etc.) |
| `feature_server_image_par_url` | PAR URL for Feature Server image |
| `recording_image_par_url` | PAR URL for Recording image (optional) |

### Instance Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `sip_count` | `2` | Number of SIP instances |
| `sip_ocpus` | `4` | OCPUs per SIP server |
| `sip_memory_in_gbs` | `8` | Memory per SIP server |
| `sip_disk_size` | `100` | Disk size per SIP server |
| `rtp_count` | `2` | Number of RTP instances |
| `rtp_ocpus` | `4` | OCPUs per RTP server |
| `rtp_memory_in_gbs` | `8` | Memory per RTP server |
| `rtp_disk_size` | `100` | Disk size per RTP server |
| `web_ocpus` | `4` | OCPUs for Web server |
| `web_memory_in_gbs` | `8` | Memory for Web server |
| `web_disk_size` | `100` | Disk size for Web server |
| `monitoring_ocpus` | `4` | OCPUs for Monitoring server |
| `monitoring_memory_in_gbs` | `16` | Memory for Monitoring server |
| `monitoring_disk_size` | `200` | Disk size for Monitoring server |
| `feature_server_count` | `4` | Number of Feature Servers |
| `feature_server_ocpus` | `8` | OCPUs per Feature Server |
| `feature_server_memory_in_gbs` | `16` | Memory per Feature Server |
| `feature_server_disk_size` | `100` | Disk size per Feature Server |
| `deploy_recording_cluster` | `true` | Deploy recording servers |
| `recording_count` | `2` | Number of Recording servers |

### Database Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `mysql_shape` | `VM.Standard.E2.2` | MySQL HeatWave shape |
| `mysql_storage_size` | `100` | Storage in GB |
| `mysql_username` | `jambonz` | Database username |
| `mysql_password` | `""` | Password (auto-generated if empty) |

## Scaling

Adjust instance counts in `terraform.tfvars`:

```hcl
sip_count            = 4   # Scale SIP servers
rtp_count            = 4   # Scale RTP servers
feature_server_count = 8   # Scale Feature Servers
recording_count      = 4   # Scale Recording servers
```

## Outputs

After deployment, Terraform will output:

- **web_public_ip**: Web server IP (for DNS A records)
- **monitoring_public_ip**: Monitoring server IP
- **sip_public_ips**: Reserved public IPs for SIP instances
- **rtp_public_ips**: Reserved public IPs for RTP instances
- **feature_server_public_ips**: Feature Server IPs
- **recording_private_ips**: Recording server private IPs
- **mysql_endpoint**: MySQL connection endpoint
- **redis_endpoint**: Redis endpoint (monitoring server private IP)
- **dns_records_required**: Map of DNS records to create
- **ssh_connection_***: SSH commands for each server type

View outputs anytime:
```bash
terraform output
terraform output -json sip_public_ips
terraform output dns_records_required
```

## Network Architecture

- **Public subnet**: Web, monitoring, SIP, RTP, and feature server instances
- **Private subnet**: MySQL HeatWave, recording servers (outbound via NAT gateway)
- SIP and RTP servers get **reserved public IPs** that persist across instance recreation
- Each server type has its own **Network Security Group** (NSG) with role-specific rules

## Troubleshooting

### Check logs on any server
```bash
ssh jambonz@<server_ip>
sudo cat /var/log/cloud-init-output.log
```

### Check service status
```bash
# SIP server
sudo systemctl status drachtio
pm2 list

# RTP server
sudo systemctl status rtpengine
pm2 list

# Web server
pm2 list  # webapp, api-server, public-apps

# Monitoring server
sudo systemctl status grafana-server cassandra influxdb
```

## Destroying the Deployment

```bash
terraform destroy
```

**Note**: This will destroy all VMs, managed services, and imported images.

## Related

- [Main OCI README](../README.md) - Authentication and general setup
- [jambonz Documentation](https://docs.jambonz.org/)
