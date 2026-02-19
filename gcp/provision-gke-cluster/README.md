# GCP GKE Cluster for jambonz VoIP

This Terraform configuration deploys a GCP GKE (Google Kubernetes Engine) regional cluster optimized for jambonz VoIP workloads.

## Architecture

### Node Pools

| Node Pool | Purpose | Network Tag | Taint | Label | Key Ports |
|-----------|---------|-------------|-------|-------|-----------|
| **system** | General workloads, K8s system components | `system-nodes` | None | - | 80, 443 |
| **sip** | SIP signaling (drachtio-server) | `sip-nodes` | `sip=true:NoSchedule` | `voip-environment=sip` | 5060, 5061, 8443 |
| **rtp** | RTP media (rtpengine, freeswitch) | `rtp-nodes` | `rtp=true:NoSchedule` | `voip-environment=rtp` | 40000-60000 |

### Network Architecture

- **VPC Network**: Custom VPC with manual subnet creation
- **Subnets**: Separate subnets for system, SIP, and RTP node pools
- **Public IPs**: GKE nodes have public IPs by default for VoIP requirements

### Firewall Rules

Network tag-based firewall rules ensure only appropriate nodes have VoIP ports open:

- **System nodes** (`system-nodes`): TCP 80, 443 for LoadBalancer services
- **SIP nodes** (`sip-nodes`): UDP/TCP 5060, TCP 5061, TCP 8443
- **RTP nodes** (`rtp-nodes`): UDP 40000-60000

## Prerequisites

- GCP account with billing enabled
- GCP project with required APIs enabled:
  ```bash
  gcloud services enable container.googleapis.com compute.googleapis.com
  ```
- gcloud CLI installed and configured
- Terraform >= 1.5
- `kubectl` installed

## Usage

### 1. Authenticate with Google Cloud

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

### 3. Initialize and Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Configure kubectl

```bash
gcloud container clusters get-credentials <cluster-name> --region <region> --project <project-id>
kubectl get nodes
```

### 5. Verify the Cluster

```bash
kubectl get nodes --show-labels
kubectl describe nodes | grep -A5 Taints
kubectl get nodes -o wide

# Check firewall rules
gcloud compute firewall-rules list --filter="network=voip-network"

# Verify network tags on instances
gcloud compute instances list --format="table(name,tags.items)"
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | (required) |
| `region` | GCP region | `us-east1` |
| `cluster_name` | GKE cluster name | `voip-gke-cluster` |
| `network_name` | VPC network name | `voip-network` |
| `system_subnet_cidr` | System subnet CIDR | `10.0.1.0/24` |
| `sip_subnet_cidr` | SIP subnet CIDR | `10.0.2.0/24` |
| `rtp_subnet_cidr` | RTP subnet CIDR | `10.0.3.0/24` |
| `pods_cidr` | Secondary CIDR for pods | `10.1.0.0/16` |
| `services_cidr` | Secondary CIDR for services | `10.2.0.0/16` |
| `system_machine_type` | Machine type for system nodes | `e2-standard-2` |
| `sip_machine_type` | Machine type for SIP nodes | `e2-standard-2` |
| `sip_node_count` | Number of SIP nodes | `1` |
| `rtp_machine_type` | Machine type for RTP nodes | `e2-standard-2` |
| `rtp_node_count` | Number of RTP nodes | `1` |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | GKE cluster name |
| `cluster_region` | GKE cluster region |
| `project_id` | GCP project ID |
| `network_name` | VPC network name |
| `kubeconfig_command` | Command to configure kubectl |

## Deploying jambonz

After the cluster is provisioned, deploy jambonz using the [jambonz Helm chart](https://github.com/jambonz-selfhosting/helm-chart). Refer to the Helm chart README for detailed installation instructions.

## Cleanup

```bash
terraform destroy
```

## Troubleshooting

### Insufficient quota
Request a quota increase in the GCP Console, reduce node counts, or use smaller machine types (e.g., `e2-medium`).

### API not enabled
```bash
gcloud services enable container.googleapis.com compute.googleapis.com
```

### Firewall rules not working
Verify network tags are properly assigned:
```bash
gcloud compute instances list --format="table(name,tags.items)"
```
