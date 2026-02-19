# Exoscale SKS Cluster for jambonz VoIP

This Terraform configuration deploys an Exoscale SKS (Scalable Kubernetes Service) cluster optimized for jambonz VoIP workloads.

## Architecture

### Node Pools

```
┌─────────────────────────────────────────────────────────────┐
│                    Exoscale SKS Cluster                     │
│                   (service_level: pro)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐       │
│  │   System    │   │     SIP     │   │     RTP     │       │
│  │  Nodepool   │   │  Nodepool   │   │  Nodepool   │       │
│  ├─────────────┤   ├─────────────┤   ├─────────────┤       │
│  │ 2 nodes     │   │ 1+ nodes    │   │ 1+ nodes    │       │
│  │ No taints   │   │ Taint: sip  │   │ Taint: rtp  │       │
│  │ HTTP/HTTPS  │   │ SIP ports   │   │ RTP ports   │       │
│  └─────────────┘   └─────────────┘   └─────────────┘       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

| Node Pool | Purpose | Taint | Label | Key Ports |
|-----------|---------|-------|-------|-----------|
| **system** | General workloads, K8s system | None | `pool=system` | 80, 443, 30000-32767 |
| **sip** | SIP signaling (drachtio-server) | `sip=true:NoSchedule` | `voip-environment=sip` | 5060, 5061, 8443 |
| **rtp** | RTP media (rtpengine, freeswitch) | `rtp=true:NoSchedule` | `voip-environment=rtp` | 40000-60000 |

### Security Groups

Each node pool has dedicated security groups to control traffic:

- **internal**: All cluster-internal communication
- **ssh**: SSH access (configurable CIDR)
- **system**: HTTP/HTTPS and NodePorts
- **sip**: SIP signaling ports (5060 UDP/TCP, 5061 TLS, 8443 WSS)
- **rtp**: RTP media ports (40000-60000 UDP)

## Prerequisites

- Exoscale account ([exoscale.com](https://www.exoscale.com))
- API credentials (API key with full permissions)
- Terraform >= 1.5
- `kubectl` installed

## Usage

### 1. Set Environment Variables

```bash
export EXOSCALE_API_KEY="your-api-key"
export EXOSCALE_API_SECRET="your-api-secret"
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
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

### 5. Verify the Cluster

```bash
kubectl get nodes -L voip-environment
kubectl describe nodes | grep -A5 Taints
```

### 6. Install Traefik Ingress Controller

Traefik is used as the ingress controller for jambonz HTTP services (webapp, API, grafana, homer).

Because the cluster has multiple node pools, the Exoscale Cloud Controller Manager (CCM) requires an annotation to specify which instance pool should receive LoadBalancer traffic. Without it you'll get an error about multiple Instance Pools being detected.

```bash
# Get the system nodepool's instance pool ID
terraform output system_nodepool_instance_pool_id

# Add traefik helm repo
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Install traefik (replace <INSTANCE_POOL_ID> with the output above)
kubectl create namespace jambonz
helm install traefik traefik/traefik --namespace jambonz \
  --set "service.annotations.service\.beta\.kubernetes\.io/exoscale-loadbalancer-service-instancepool-id=<INSTANCE_POOL_ID>"

# Verify the LoadBalancer gets an external IP
kubectl -n jambonz get svc traefik
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `name_prefix` | Prefix for all resource names | `jambonz` |
| `zone` | Exoscale zone | `ch-gva-2` |
| `cluster_name` | Cluster name | `voip-sks-cluster` |
| `service_level` | `starter` (free) or `pro` (HA) | `pro` |
| `cni` | CNI plugin (`calico`, `cilium`, `""`) | `calico` |
| `system_instance_type` | Instance type for system nodes | `standard.large` |
| `system_node_count` | Number of system nodes | `2` |
| `sip_instance_type` | Instance type for SIP nodes | `standard.large` |
| `sip_node_count` | Number of SIP nodes | `1` |
| `rtp_instance_type` | Instance type for RTP nodes | `standard.large` |
| `rtp_node_count` | Number of RTP nodes | `1` |
| `allowed_ssh_cidr` | CIDR for SSH access | `0.0.0.0/0` |

To scale node pools, update the `*_node_count` variables and run `terraform apply`.

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_endpoint` | Kubernetes API endpoint |
| `kubeconfig_path` | Path to generated kubeconfig |
| `kubectl_command` | Command to set KUBECONFIG |
| `system_nodepool_instance_pool_id` | Instance pool ID for Traefik annotation |
| `usage_instructions` | Detailed usage instructions |

## Deploying jambonz

After the cluster is provisioned, deploy jambonz using the [jambonz Helm chart](https://github.com/jambonz-selfhosting/helm-chart). Refer to the Helm chart README for detailed installation instructions.

## Cleanup

> **Important**: If you deployed jambonz via the Helm chart, the Kubernetes `LoadBalancer` services (e.g., traefik) will have created Exoscale Network Load Balancers (NLBs) outside of Terraform's control. You must delete these NLBs **before** running `terraform destroy`, otherwise the node pool deletion will fail with a "managed Instance Pool is locked by NLB" error.

```bash
# List NLBs in your zone
exo compute load-balancer list --zone ch-gva-2

# Delete each NLB
exo compute load-balancer delete <NLB_ID> --zone ch-gva-2
```

```bash
terraform destroy
```

## Notes

### Differences from GKE/AKS/EKS

| Feature | GKE | AKS | EKS | Exoscale SKS |
|---------|-----|-----|-----|--------------|
| Multi-zone | Regional cluster | Availability zones | Multi-AZ | Single zone |
| Autoscaling | Node autoscaler | Node autoscaler | Node autoscaler | Karpenter (Pro only) |
| Public IPs | Cloud NAT | Per-pool setting | Elastic IPs | All nodes by default |
| Security | Network tags + firewall | NSGs + manual VMSS | Security groups | Security groups |

### Limitations

- **Single Zone**: SKS clusters are single-zone only (no regional HA)
- **Manual Scaling**: No built-in autoscaler; use Karpenter on Pro tier
- **No Subnet Separation**: Cannot place node pools in separate subnets

### Advantages

- **Simpler Public IP Model**: All nodes automatically get public IPs
- **European Data Sovereignty**: All data centers in Europe
- **Direct Security Groups**: No manual NSG/VMSS association needed
