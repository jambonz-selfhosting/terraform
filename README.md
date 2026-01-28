# jambonz Self-Hosting Terraform

Terraform configurations for deploying jambonz on various cloud providers.

## Cloud Providers

| Provider | Kubernetes | VM (Mini) | VM (Medium) |
|----------|------------|-----------|-------------|
| **AWS** | [EKS](aws/provision-eks-cluster/) | - | - |
| **Azure** | [AKS](azure/provision-aks-cluster/) | [VM Mini](azure/provision-vm-mini/) | [VM Medium](azure/provision-vm-medium/) |
| **GCP** | [GKE](gcp/provision-gke-cluster/) | - | [VM Medium](gcp/provision-vm-medium/) |
| **Exoscale** | [SKS](exoscale/provision-sks-cluster/) | [VM Mini](exoscale/provision-vm-mini/) | [VM Medium](exoscale/provision-vm-medium/) |

## Deployment Types

### Kubernetes Clusters

Production-ready deployments using managed Kubernetes services with dedicated node pools for VoIP workloads:

- **System nodes** - General workloads (private subnets)
- **SIP nodes** - SIP signaling with public IPs (drachtio-server)
- **RTP nodes** - Media processing with public IPs (rtpengine, freeswitch)

After provisioning the cluster, deploy jambonz using the Helm chart.

### VM Deployments

Single-VM or multi-VM deployments for smaller installations:

- **Mini** - All-in-one single VM deployment
- **Medium** - Multi-VM deployment with dedicated servers for SBC, feature server, and web/monitoring

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