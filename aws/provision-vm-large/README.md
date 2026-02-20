# jambonz AWS Large VM Deployment

Fully separated architecture with dedicated SIP, RTP, Feature Server, Web, and Monitoring instances, backed by Aurora Serverless v2 MySQL and ElastiCache Redis.

## Architecture

```
Internet
    │
    ├─── SIP Servers (count-based, EIPs) ──── Drachtio + SBC apps
    │        │
    ├─── RTP Servers (count-based, EIPs) ──── RTPEngine + sidecar
    │
    ├─── Web Server (EC2 + EIP) ──────────── API, webapp, public-apps, upload_recordings
    │
    ├─── Monitoring Server (EC2 + EIP) ───── Grafana, Homer, Jaeger, InfluxDB
    │
    ├─── Feature Server ASG ──────────────── FreeSWITCH + feature-server app
    │
    └─── Recording ASG + ALB (optional) ──── upload_recordings
         │
    VPC Private Subnets
    ├─── Aurora Serverless v2 MySQL
    └─── ElastiCache Redis 7.1
```

## Components

| Component | Type | Purpose |
|-----------|------|---------|
| SIP Servers | EC2 (count-based) | SIP signaling via drachtio, SBC inbound/outbound/call-router |
| RTP Servers | EC2 (count-based) | RTP media via rtpengine |
| Feature Server | ASG + Launch Template | FreeSWITCH, jambonz feature-server app |
| Web Server | EC2 | API server, webapp, public-apps |
| Monitoring Server | EC2 | Grafana, Homer, Jaeger, InfluxDB, Cassandra |
| Aurora MySQL | Serverless v2 | Database (0.5–8 ACU) |
| ElastiCache Redis | Single node | Cache and session store |
| Recording | ASG + ALB (optional) | Dedicated recording cluster |

## Key Differences from Medium

- SIP and RTP servers are **separate** (not combined SBC)
- SIP and RTP use **count-based instances** with stable EIPs (not ASGs)
- Web and Monitoring are **separate** EC2 instances
- SIP servers receive RTP server private IPs for direct `JAMBONES_RTPENGINES` connection
- Higher Aurora capacity (8 ACU max vs 4)
- Higher max DB connections (500 vs 300)

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.5
3. SSH key pair
4. DNS domain for the portal

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform apply
```

## DNS Records

After deployment, create these DNS A records:

| Record | Points To |
|--------|-----------|
| `jambonz.example.com` | Web Server EIP |
| `api.jambonz.example.com` | Web Server EIP |
| `public-apps.jambonz.example.com` | Web Server EIP |
| `grafana.jambonz.example.com` | Monitoring Server EIP |
| `homer.jambonz.example.com` | Monitoring Server EIP |
| `sip.jambonz.example.com` | First SIP Server EIP |

Run `terraform output dns_records_required` to see the exact IP mappings.

## Scaling

**SIP/RTP Servers**: Change `sip_count` or `rtp_count` in tfvars and re-apply. Note: adding RTP servers requires re-applying to update SIP server configs with new RTP IPs.

**Feature Servers**: Adjust `feature_server_min_size`, `feature_server_max_size`, and `feature_server_desired_capacity`. Uses SNS lifecycle hooks for graceful scale-in.

**Database**: Adjust `aurora_min_capacity` and `aurora_max_capacity` for automatic scaling.

## Access

```bash
# SSH to servers
terraform output ssh_connection_web
terraform output ssh_connection_monitoring
terraform output ssh_connection_sip
terraform output ssh_connection_rtp

# Portal credentials
terraform output portal_username
terraform output -raw portal_password
```
