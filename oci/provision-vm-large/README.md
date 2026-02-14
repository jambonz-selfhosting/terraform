# jambonz large - Oracle Cloud Infrastructure (OCI) Terraform Deployment

This Terraform configuration deploys a scaled multi-VM jambonz cluster on Oracle Cloud Infrastructure with managed MySQL and Redis services.

## Architecture

| Component | Default Count | Description |
|-----------|---------------|-------------|
| Web/Monitoring | 1 | Portal, API, Grafana, Homer, Jaeger |
| SBC | 4 | drachtio SIP server, rtpengine RTP proxy |
| Feature Server | 4 | FreeSWITCH, jambonz apps |
| Recording | 2 | Recording server (optional) |
| MySQL | 1 | OCI MySQL HeatWave (managed, larger shape) |
| Redis | 3 nodes | OCI Cache with Redis (managed, clustered) |

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

## Default Configuration

The large deployment includes higher default instance counts and larger managed service configurations:

| Component | Count | OCPUs | Memory | Disk |
|-----------|-------|-------|--------|------|
| SBC | 4 | 4 | 8GB | 200GB |
| Feature Server | 4 | 4 | 8GB | 200GB |
| Web/Monitoring | 1 | 4 | 8GB | 200GB |
| Recording | 2 | 4 | 8GB | 200GB |

| Managed Service | Configuration |
|-----------------|---------------|
| MySQL | MySQL.VM.Standard.E4.2.32GB, 100GB storage |
| Redis | 3 nodes, 16GB each |

## Scaling

Adjust instance counts in `terraform.tfvars`:

```hcl
sbc_count            = 6   # Scale SBCs
feature_server_count = 6   # Scale Feature Servers
recording_count      = 4   # Scale Recording servers
redis_node_count     = 5   # Scale Redis (max 5)
```

## Related

- [Main OCI README](../README.md) - Authentication and general setup
- [jambonz Documentation](https://docs.jambonz.org/)
