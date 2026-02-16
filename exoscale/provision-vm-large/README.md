# Jambonz Large Deployment on Exoscale

Large multi-VM deployment with fully separated SIP, RTP, Web, and Monitoring servers, plus instance pools for feature servers and recording.

## Architecture

| Server | Type | Default Count | Public IP | Purpose |
|--------|------|:---:|:---:|---------|
| **Monitoring** | Compute Instance | 1 | Elastic IP | Grafana, Homer, Jaeger, InfluxDB, Cassandra |
| **Web** | Compute Instance | 1 | Elastic IP | API, webapp, nginx (proxies to monitoring) |
| **SIP** | Compute Instance | 1 | Elastic IP | drachtio, sbc-sip-sidecar, call-router, inbound/outbound |
| **RTP** | Compute Instance | 1 | Elastic IP | rtpengine, sbc-rtpengine-sidecar |
| **Feature Server** | Instance Pool | 1 | Private only | FreeSWITCH, feature-server |
| **Recording** | Instance Pool | 1 | Private only | upload-recordings (behind NLB) |
| **MySQL** | DBaaS | 1 | - | Managed database |

## Prerequisites

1. [Exoscale CLI](https://community.exoscale.com/documentation/tools/exoscale-command-line-interface/) configured
2. [Terraform](https://www.terraform.io/downloads) >= 1.0
3. **Register VM Templates**: Before running Terraform, you must register the jambonz VM templates into your Exoscale account. This is a one-time step per version per zone. See the [Exoscale README](../README.md) for full details.

   ```bash
   cd exoscale/
   ./prepare-images.sh
   # Select: 3) large, then choose your target zone
   ```

   This registers six templates: `jambonz-sip`, `jambonz-rtp`, `jambonz-fs`, `jambonz-web`, `jambonz-monitoring`, and `jambonz-recording`.

## Quick Start

```bash
# 1. Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your template IDs, domain, and SSH key

# 2. Initialize and deploy
terraform init
terraform plan
terraform apply

# 3. Configure DNS records (see output)
terraform output dns_records_required

# 4. Get SSH access info
terraform output ssh_config_snippet
```

## Scaling

All server counts default to 1. Scale up by editing `terraform.tfvars`:

```hcl
sip_count            = 2   # Add SIP servers for more SIP capacity
rtp_count            = 2   # Add RTP servers for more media capacity
feature_server_count = 4   # Scale feature servers via instance pool
recording_server_count = 2 # Scale recording servers via instance pool
```

Then run `terraform apply`.

## Key Differences from Medium

- **SBC split**: Separate SIP and RTP servers (medium combines them)
- **Web/Monitoring split**: Separate Web and Monitoring servers
- **Independent scaling**: SIP, RTP, Feature, and Recording scale independently
- **PCAP support**: HEP/Homer integration for SIP and RTP packet capture

## SSH Access

- **Web, Monitoring, SIP, RTP**: Direct SSH via Elastic IP
- **Feature Server, Recording**: Use SIP server as jump host:
  ```bash
  ssh -J jambonz@<sip-ip> jambonz@<feature-server-private-ip>
  ```

## DNS Records

Point these A records to the Web server Elastic IP:
- `jambonz.example.com`
- `api.jambonz.example.com`
- `grafana.jambonz.example.com`
- `homer.jambonz.example.com`
- `public-apps.jambonz.example.com`

Point this A record to the first SIP server Elastic IP:
- `sip.jambonz.example.com`
