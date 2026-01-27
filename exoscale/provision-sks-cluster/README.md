# Exoscale SKS Cluster for jambonz VoIP

This Terraform configuration deploys an Exoscale SKS (Scalable Kubernetes Service) cluster optimized for jambonz VoIP workloads.

## Architecture

The cluster follows the same three-nodepool architecture as the GKE and AKS deployments:

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

### Node Pools

| Pool | Purpose | Taint | Label | Ports |
|------|---------|-------|-------|-------|
| system | General workloads, K8s system | None | `pool=system` | 80, 443, 30000-32767 |
| sip | SIP signaling (drachtio-server) | `sip=true:NoSchedule` | `voip-environment=sip` | 5060, 5061, 8443 |
| rtp | RTP media (rtpengine, freeswitch) | `rtp=true:NoSchedule` | `voip-environment=rtp` | 40000-60000 |

### Security Groups

Each nodepool has dedicated security groups to control traffic:

- **internal**: All cluster-internal communication
- **ssh**: SSH access (configurable CIDR)
- **system**: HTTP/HTTPS and NodePorts
- **sip**: SIP signaling ports (5060 UDP/TCP, 5061 TLS, 8443 WSS)
- **rtp**: RTP media ports (40000-60000 UDP)

## Prerequisites

1. **Exoscale Account**: Sign up at [exoscale.com](https://www.exoscale.com)
2. **API Credentials**: Create an API key with full permissions
3. **Terraform**: Version 1.5 or later

## Quick Start

1. **Set Environment Variables**

   ```bash
   export EXOSCALE_API_KEY="your-api-key"
   export EXOSCALE_API_SECRET="your-api-secret"
   ```

2. **Configure Variables**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your settings
   ```

3. **Deploy**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Configure kubectl**

   ```bash
   export KUBECONFIG=$(pwd)/kubeconfig
   kubectl get nodes
   ```

## Installing Traefik (Ingress Controller)

Traefik is used as the ingress controller for jambonz HTTP services (webapp, API, grafana, homer).

**Important**: Because the cluster has multiple node pools (system, sip, rtp), the Exoscale Cloud Controller Manager (CCM) requires an annotation to specify which instance pool should receive LoadBalancer traffic.

### Get the Instance Pool ID

After running `terraform apply`, get the system nodepool's instance pool ID:

```bash
terraform output system_nodepool_instance_pool_id
```

### Install Traefik with the Annotation

```bash
# Create the jambonz namespace
kubectl create namespace jambonz

# Add traefik helm repo
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Install traefik with the instance pool annotation
# Replace <INSTANCE_POOL_ID> with the output from the terraform command above
helm install traefik traefik/traefik --namespace jambonz \
  --set "service.annotations.service\.beta\.kubernetes\.io/exoscale-loadbalancer-service-instancepool-id=<INSTANCE_POOL_ID>"
```

### Verify LoadBalancer

```bash
kubectl -n jambonz get svc traefik
```

You should see an `EXTERNAL-IP` assigned (this may take a minute). This IP is your Exoscale Network Load Balancer address.

### Why This Annotation is Required

The Exoscale CCM creates Network Load Balancers (NLBs) for Kubernetes `LoadBalancer` services. When a cluster has multiple node pools, the CCM needs to know which pool's instances should be the NLB targets. Without this annotation, you'll see the error:

```
Error syncing load balancer: multiple Instance Pools detected across cluster Nodes,
an Instance Pool ID must be specified in Service manifest annotations
```

## Configuration Variables

### Required

No required variables - all have sensible defaults.

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `name_prefix` | `jambonz` | Prefix for all resource names |
| `zone` | `ch-gva-2` | Exoscale zone |
| `cluster_name` | `voip-sks-cluster` | Cluster name |
| `service_level` | `pro` | `starter` (free) or `pro` (HA) |
| `cni` | `calico` | CNI plugin (`calico`, `cilium`, `""`) |
| `system_instance_type` | `standard.medium` | Instance type for system nodes |
| `system_node_count` | `2` | Number of system nodes |
| `sip_instance_type` | `standard.medium` | Instance type for SIP nodes |
| `sip_node_count` | `1` | Number of SIP nodes |
| `rtp_instance_type` | `standard.medium` | Instance type for RTP nodes |
| `rtp_node_count` | `1` | Number of RTP nodes |
| `allowed_ssh_cidr` | `0.0.0.0/0` | CIDR for SSH access |

## VoIP Pod Configuration

### SIP Pods

SIP workloads (e.g., drachtio-server) must be configured to run on SIP nodes:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: drachtio
spec:
  hostNetwork: true  # Required for VoIP - bind to node's public IP
  nodeSelector:
    voip-environment: sip
  tolerations:
  - key: "sip"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  containers:
  - name: drachtio
    image: drachtio/drachtio-server:latest
    ports:
    - containerPort: 5060
      protocol: UDP
    - containerPort: 5060
      protocol: TCP
```

### RTP Pods

RTP workloads (e.g., rtpengine, freeswitch) must be configured to run on RTP nodes:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rtpengine
spec:
  hostNetwork: true  # Required for VoIP - bind to node's public IP
  nodeSelector:
    voip-environment: rtp
  tolerations:
  - key: "rtp"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  containers:
  - name: rtpengine
    image: drachtio/rtpengine:latest
    ports:
    - containerPort: 22222
      protocol: UDP
```

## Outputs

After deployment, Terraform provides these outputs:

| Output | Description |
|--------|-------------|
| `cluster_endpoint` | Kubernetes API endpoint |
| `kubeconfig_path` | Path to generated kubeconfig |
| `kubectl_command` | Command to set KUBECONFIG |
| `usage_instructions` | Detailed usage instructions |

## Scaling

To scale node pools, update the `*_node_count` variables and apply:

```bash
# Edit terraform.tfvars
sip_node_count = 2
rtp_node_count = 3

# Apply changes
terraform apply
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Differences from GKE/AKS

| Feature | GKE | AKS | Exoscale SKS |
|---------|-----|-----|--------------|
| Multi-zone | Regional cluster | Availability zones | Single zone |
| Autoscaling | Node autoscaler | Node autoscaler | Karpenter (Pro only) |
| Public IPs | Cloud NAT | Per-pool setting | All nodes by default |
| Security | Network tags + firewall | NSGs + manual VMSS | Security groups |

### Limitations

- **Single Zone**: SKS clusters are single-zone only (no regional HA)
- **Manual Scaling**: No built-in autoscaler; use Karpenter on Pro tier
- **No Subnet Separation**: Cannot place node pools in separate subnets

### Advantages

- **Simpler Public IP Model**: All nodes automatically get public IPs
- **European Data Sovereignty**: All data centers in Europe
- **Direct Security Groups**: No manual NSG/VMSS association needed
