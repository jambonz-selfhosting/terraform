# jambonz Mini (Single VM) on AWS

All-in-one jambonz deployment on a single EC2 instance with local MySQL, Redis, and monitoring.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         AWS VPC                              │
│                      (10.0.0.0/16)                           │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐    │
│   │                  Public Subnet                      │    │
│   │                                                     │    │
│   │   ┌──────────────────────────────────────────┐      │    │
│   │   │         Mini Server (EC2 + EIP)          │      │    │
│   │   │                                          │      │    │
│   │   │  • drachtio (SIP)     • freeswitch       │      │    │
│   │   │  • rtpengine (RTP)    • MySQL (local)    │      │    │
│   │   │  • Redis (local)      • nginx            │      │    │
│   │   │  • jambonz apps       • Grafana          │      │    │
│   │   │  • Homer              • Jaeger           │      │    │
│   │   │  • InfluxDB           • Telegraf         │      │    │
│   │   └──────────────────────────────────────────┘      │    │
│   │                                                     │    │
│   └─────────────────────────────────────────────────────┘    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Components

| Component | Description |
|-----------|-------------|
| drachtio | SIP application server |
| rtpengine | RTP media relay |
| freeswitch | Media processing / IVR |
| MySQL | Local database (pre-seeded) |
| Redis | Local cache |
| nginx | Reverse proxy for portal/API |
| Grafana | Metrics dashboard |
| Homer | SIP capture/analysis |
| Jaeger | Distributed tracing |

## Prerequisites

1. AWS CLI configured (`aws configure`)
2. Terraform >= 1.5 installed
3. An SSH key pair
4. A domain name for the portal

## Deployment

```bash
# 1. Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Initialize Terraform
terraform init

# 3. Review the plan
terraform plan

# 4. Deploy
terraform apply
```

## Post-Deployment

1. Create DNS A records for your domain pointing to the public IP:
   - `jambonz.example.com` → public IP
   - `api.jambonz.example.com` → public IP
   - `grafana.jambonz.example.com` → public IP
   - `homer.jambonz.example.com` → public IP
   - `sip.jambonz.example.com` → public IP

2. Access the portal at `http://jambonz.example.com`
   - Username: `admin`
   - Password: the EC2 instance ID (shown in `terraform output -raw portal_password`)

## Outputs

| Output | Description |
|--------|-------------|
| `portal_url` | URL for the jambonz portal |
| `api_url` | URL for the jambonz API |
| `grafana_url` | URL for Grafana |
| `homer_url` | URL for Homer |
| `public_ip` | Elastic IP address |
| `ssh_connection` | SSH command to connect |
| `portal_password` | Initial admin password (sensitive) |
| `dns_records_required` | DNS records to create |

## SSH Access

```bash
ssh jambonz@<public_ip>
```

## Troubleshooting

Check cloud-init logs:
```bash
sudo cat /var/log/cloud-init-output.log
```

Check service status:
```bash
sudo systemctl status drachtio
sudo systemctl status rtpengine
sudo systemctl status freeswitch
sudo -u jambonz pm2 status
```

## Cleanup

```bash
terraform destroy
```

Note: The Elastic IP is released on destroy. If you need to preserve it, import it into a separate Terraform state before destroying.
