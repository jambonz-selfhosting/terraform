# jambonz Medium VM Deployment on AWS

Multi-VM deployment with managed Aurora MySQL and ElastiCache Redis. SBC and Feature Server run as Auto Scaling Groups for high availability.

## Architecture

```
                           ┌──────────────────────────────────────────┐
                           │              AWS VPC                     │
                           │                                         │
  Internet ────────────────┤  Public Subnets (2 AZs)                 │
                           │  ┌─────────────┐  ┌─────────────┐      │
                           │  │ SBC ASG     │  │ FS ASG      │      │
                           │  │ (1-4 inst)  │  │ (1-4 inst)  │      │
                           │  │ + EIPs      │  │             │      │
                           │  └─────────────┘  └─────────────┘      │
                           │  ┌─────────────┐  ┌─────────────┐      │
                           │  │ Web/Monitor │  │ Recording   │      │
                           │  │ EC2 + EIP   │  │ ASG + ALB   │      │
                           │  │             │  │ (optional)  │      │
                           │  └─────────────┘  └─────────────┘      │
                           │                                         │
                           │  Private Subnets (2 AZs)               │
                           │  ┌─────────────┐  ┌─────────────┐      │
                           │  │ Aurora      │  │ ElastiCache │      │
                           │  │ Serverless  │  │ Redis 7.1   │      │
                           │  │ v2 MySQL    │  │             │      │
                           │  └─────────────┘  └─────────────┘      │
                           └──────────────────────────────────────────┘
```

## Components

| Component | Type | Purpose |
|-----------|------|---------|
| SBC | ASG + Launch Template | SIP signaling, RTP media, call routing |
| Feature Server | ASG + Launch Template | FreeSWITCH, jambonz application logic |
| Web/Monitoring | Single EC2 + EIP | Portal, API, Grafana, Homer, Jaeger |
| Recording | ASG + ALB (optional) | Call recording servers |
| Aurora MySQL | Serverless v2 | Database (private subnets) |
| ElastiCache Redis | Replication Group | Cache and pub/sub (private subnets) |

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.5
3. SSH key pair
4. DNS domain for the jambonz portal

## Deployment

```bash
# 1. Copy and customize the tfvars file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Initialize and apply
terraform init
terraform plan
terraform apply
```

## Post-Deployment

### DNS Records

Create DNS A records pointing to the IPs shown in the Terraform output:

| Record | Points To |
|--------|-----------|
| `jambonz.example.com` | Web/Monitoring EIP |
| `api.jambonz.example.com` | Web/Monitoring EIP |
| `grafana.jambonz.example.com` | Web/Monitoring EIP |
| `homer.jambonz.example.com` | Web/Monitoring EIP |
| `public-apps.jambonz.example.com` | Web/Monitoring EIP |
| `sip.jambonz.example.com` | SBC EIP(s) |

### Portal Access

- URL: `http://jambonz.example.com`
- Username: `admin`
- Password: the Web/Monitoring EC2 instance ID (run `terraform output portal_password`)
- You will be forced to change the password on first login

### Grafana Access

- URL: `http://grafana.jambonz.example.com`
- Username: `admin`
- Password: `admin`

## Outputs

```bash
# Show all outputs
terraform output

# Show sensitive values
terraform output portal_password
terraform output aurora_endpoint
terraform output redis_endpoint
```

## Scaling

SBC and Feature Server instances auto-scale based on the configured min/max/desired values. To manually adjust:

```bash
# Update desired capacity in terraform.tfvars, then:
terraform apply
```

## Troubleshooting

- SSH to Web/Monitoring: `terraform output ssh_connection_web_monitoring`
- Check PM2 apps: `pm2 list`
- View app logs: `pm2 logs <app-name>`
- Check drachtio: `systemctl status drachtio`
- Check freeswitch: `systemctl status freeswitch`
- Check rtpengine: `systemctl status rtpengine`
- Aurora endpoint: `terraform output aurora_endpoint`
- Redis endpoint: `terraform output redis_endpoint`
