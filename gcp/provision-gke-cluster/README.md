# GKE Cluster for VoIP Workloads (Jambonz)

This Terraform configuration provisions a Google Kubernetes Engine (GKE) cluster optimized for VoIP workloads, specifically designed for [jambonz](https://jambonz.org).

## Overview

This configuration creates:
- A GKE regional cluster with three node pools:
  - **System pool**: For regular Kubernetes workloads
  - **SIP pool**: Dedicated nodes for SIP signaling with appropriate firewall rules
  - **RTP pool**: Dedicated nodes for RTP media processing with appropriate firewall rules
- VPC network with separate subnets
- Firewall rules using network tags for per-node-pool security isolation
- Node labels and taints for workload targeting

## Prerequisites

1. **Google Cloud Platform Account**: Active GCP account with billing enabled
2. **GCP Project**: A GCP project where resources will be created
3. **gcloud CLI**: Installed and configured ([Install Guide](https://cloud.google.com/sdk/docs/install))
4. **Terraform CLI**: Version >= 1.5 ([Install Guide](https://developer.hashicorp.com/terraform/install))
5. **HCP Terraform Account**: For remote state management ([Sign up](https://app.terraform.io/signup))

## Setup Steps

### 1. Authenticate with Google Cloud

```bash
# Login to GCP
gcloud auth login

# Set your project (replace with your project ID)
gcloud config set project YOUR_PROJECT_ID

# Generate application default credentials for Terraform
gcloud auth application-default login
```

### 2. Enable Required GCP APIs

```bash
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
```

### 3. Configure HCP Terraform

In HCP Terraform workspace settings, add the following environment variables:
- `GOOGLE_CREDENTIALS` (sensitive): Your service account JSON key, OR
- Use `gcloud auth application-default login` locally for development

To create a service account for HCP Terraform:
```bash
# Create service account
gcloud iam service-accounts create terraform-gke \
  --display-name="Terraform GKE Service Account"

# Grant necessary roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-gke@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-gke@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.networkAdmin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-gke@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Create and download key
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account=terraform-gke@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Copy the contents of terraform-key.json to HCP Terraform GOOGLE_CREDENTIALS variable
cat terraform-key.json
```

### 4. Create terraform.tfvars

Copy the example file and customize:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
```hcl
project_id   = "your-gcp-project-id"
region       = "us-east1"
cluster_name = "voip-gke-cluster"

# Customize other values as needed
system_node_count = 2
sip_node_count    = 1
rtp_node_count    = 1
```

### 5. Initialize Terraform

```bash
terraform init
```

### 6. Deploy the Cluster

```bash
# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### 7. Configure kubectl

After deployment, get cluster credentials:
```bash
# Use the command from terraform output
terraform output kubeconfig_command

# Or manually:
gcloud container clusters get-credentials voip-gke-cluster --region us-east1 --project YOUR_PROJECT_ID

# Verify connectivity
kubectl get nodes
```

## Key Features

### Node Pools

1. **System Pool**
   - Purpose: Regular Kubernetes system workloads (including LoadBalancer services like Traefik)
   - Network tag: `system-nodes`
   - Firewall rules: TCP 80 (HTTP), TCP 443 (HTTPS) for LoadBalancer services
   - No VoIP ports exposed

2. **SIP Pool**
   - Purpose: SIP signaling workloads
   - Label: `voip-environment=sip`
   - Taint: `sip=true:NoSchedule`
   - Network tag: `sip-nodes`
   - Firewall rules: UDP/TCP 5060, TCP 5061, TCP 8443

3. **RTP Pool**
   - Purpose: RTP media processing workloads
   - Label: `voip-environment=rtp`
   - Taint: `rtp=true:NoSchedule`
   - Network tag: `rtp-nodes`
   - Firewall rules: UDP 40000-60000

### Network Architecture

- **VPC Network**: Custom VPC with manual subnet creation
- **Subnets**: Separate subnets for system, SIP, and RTP node pools
- **Firewall Rules**: Network tag-based rules ensure only appropriate nodes have VoIP ports open
- **Public IPs**: GKE nodes have public IPs by default for VoIP requirements

### VoIP Configuration

For pods that need to bind to the node's public IP (VoIP workloads), configure your pod spec with:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sip-pod
spec:
  hostNetwork: true  # Use host networking
  nodeSelector:
    voip-environment: sip
  tolerations:
  - key: "sip"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  containers:
  - name: sip-container
    image: your-sip-image
    ports:
    - containerPort: 5060
      protocol: UDP
    - containerPort: 5060
      protocol: TCP
```

## Security Isolation

The network tag-based firewall approach ensures:
- System nodes: HTTP/HTTPS (80, 443) for LoadBalancer services, no VoIP ports exposed
- SIP nodes: Only SIP ports (5060, 5061, 8443) exposed
- RTP nodes: Only RTP ports (40000-60000) exposed

This is achieved through:
1. Network tags assigned to node pools (`system-nodes`, `sip-nodes`, `rtp-nodes`)
2. Firewall rules targeting specific network tags
3. Each node pool has firewall rules specific to its function

## Verification

After deployment, verify the configuration:

```bash
# Check node labels and taints
kubectl get nodes --show-labels
kubectl describe node <sip-node-name>

# Get node public IPs
kubectl get nodes -o wide

# Check firewall rules
gcloud compute firewall-rules list --filter="network=voip-network"

# Verify network tags on instances
gcloud compute instances list --format="table(name,tags.items)"
```

To test SIP port accessibility:
```bash
# Deploy a test listener on SIP node
kubectl run sip-test-listener --image=alpine --overrides='
{
  "spec": {
    "hostNetwork": true,
    "nodeSelector": {"voip-environment": "sip"},
    "tolerations": [{"key": "sip", "operator": "Equal", "value": "true", "effect": "NoSchedule"}],
    "containers": [{
      "name": "sip-test",
      "image": "alpine",
      "command": ["nc", "-l", "-p", "5060"]
    }]
  }
}'

# Get the node's public IP
SIP_NODE_IP=$(kubectl get nodes -l voip-environment=sip -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

# Test connectivity from outside the cluster
nc -zv $SIP_NODE_IP 5060
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Troubleshooting

### Issue: Insufficient quota
If you encounter quota errors, you can:
1. Request quota increase in GCP Console
2. Reduce node counts in `terraform.tfvars`
3. Use smaller machine types (e.g., `e2-medium`)

### Issue: API not enabled
Ensure required APIs are enabled:
```bash
gcloud services enable container.googleapis.com compute.googleapis.com
```

### Issue: Firewall rules not working
Verify network tags are properly assigned:
```bash
gcloud compute instances list --format="table(name,tags.items)"
```

## Additional Resources

- [Jambonz Documentation](https://jambonz.org/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [GCP Firewall Rules](https://cloud.google.com/vpc/docs/firewalls)
- [Network Tags](https://cloud.google.com/vpc/docs/add-remove-network-tags)
