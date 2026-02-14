# jambonz Self-Hosting Terraform

Terraform configurations for deploying jambonz on various cloud providers.

## Cloud Providers

| Provider | VM (Mini) | VM (Medium) | VM (Large) |
|----------|-----------|-------------|------------|
| **Azure** | [VM Mini](azure/provision-vm-mini/) | [VM Medium](azure/provision-vm-medium/) | [VM Large](azure/provision-vm-large/) |
| **GCP** | - | [VM Medium](gcp/provision-vm-medium/) | [VM Large](gcp/provision-vm-large/) |
| **OCI** | [VM Mini](oci/provision-vm-mini/) | [VM Medium](oci/provision-vm-medium/) | [VM Large](oci/provision-vm-large/) |
| **Exoscale** | [VM Mini](exoscale/provision-vm-mini/) | [VM Medium](exoscale/provision-vm-medium/) | - |

## Deployment Types

- **Mini** - All-in-one single VM deployment
- **Medium** - Multi-VM with combined SBC (SIP+RTP) and web/monitoring servers
- **Large** - Multi-VM with fully separated SIP, RTP, web, and monitoring servers

## Quick Start

1. Choose your cloud provider and deployment type
2. Navigate to the appropriate directory
3. Copy `terraform.tfvars.example` to `terraform.tfvars` and configure
4. Run:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

See the README in each subdirectory for provider-specific instructions.

## Additional Resources

- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Detailed deployment instructions
- [jambonz Documentation](https://docs.jambonz.org)