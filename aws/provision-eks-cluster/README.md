# AWS EKS Cluster for jambonz VoIP

This Terraform configuration deploys an AWS EKS (Elastic Kubernetes Service) cluster optimized for jambonz VoIP workloads.

## Architecture

The cluster uses three specialized node pools:

| Node Pool | Purpose | Subnets | Public IP | Taint |
|-----------|---------|---------|-----------|-------|
| **system** | General workloads, K8s system components | Private | No (NAT) | None |
| **sip** | SIP signaling (drachtio-server) | Public | Yes | `sip=true:NoSchedule` |
| **rtp** | RTP media (rtpengine, freeswitch) | Public | Yes | `rtp=true:NoSchedule` |

### Network Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS VPC (10.0.0.0/16)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐ │
│  │  Private Subnets    │  │  SIP Public Subnets │  │  RTP Public Subnets │ │
│  │  (System nodes)     │  │  (Public IPs)       │  │  (Public IPs)       │ │
│  │  10.0.1.0/24 (AZ-a) │  │  10.0.10.0/24 (AZ-a)│  │  10.0.20.0/24 (AZ-a)│ │
│  │  10.0.2.0/24 (AZ-b) │  │  10.0.11.0/24 (AZ-b)│  │  10.0.21.0/24 (AZ-b)│ │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘ │
│           │                         │                         │             │
│           ▼                         ▼                         ▼             │
│  ┌─────────────────────┐  ┌─────────────────────────────────────────────┐  │
│  │   NAT Gateway       │  │              Internet Gateway               │  │
│  │   (egress only)     │  │       (public subnet internet access)       │  │
│  └─────────────────────┘  └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Security Groups

| Security Group | Ports | Purpose |
|----------------|-------|---------|
| **internal** | All (VPC CIDR) | Cluster-internal communication |
| **system** | 80, 443, 30000-32767 | HTTP/HTTPS, NodePorts |
| **sip** | 5060 UDP/TCP, 5061, 8443 | SIP signaling, WebRTC |
| **rtp** | 40000-60000 UDP, 2222-2223 UDP | RTP media, rtpengine ng protocol |

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- `kubectl` installed

## Usage

1. **Copy and configure variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your settings
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review the plan:**
   ```bash
   terraform plan
   ```

4. **Apply the configuration:**
   ```bash
   terraform apply
   ```

5. **Configure kubectl:**
   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster-name>
   ```

6. **Verify the cluster:**
   ```bash
   kubectl get nodes --show-labels
   kubectl describe nodes | grep -A3 Taints
   ```

## VoIP Pod Configuration

### SIP Pods (drachtio-server)

```yaml
spec:
  nodeSelector:
    voip-environment: sip
  tolerations:
    - key: sip
      value: "true"
      effect: NoSchedule
  hostNetwork: true
```

### RTP Pods (rtpengine, freeswitch)

```yaml
spec:
  nodeSelector:
    voip-environment: rtp
  tolerations:
    - key: rtp
      value: "true"
      effect: NoSchedule
  hostNetwork: true
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region | `us-east-1` |
| `name_prefix` | Prefix for resource names | `jambonz` |
| `cluster_name` | EKS cluster name | `voip-eks-cluster` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `system_instance_type` | Instance type for system nodes | `t3.medium` |
| `system_node_count` | Number of system nodes | `2` |
| `sip_instance_type` | Instance type for SIP nodes | `t3.medium` |
| `sip_node_count` | Number of SIP nodes | `1` |
| `rtp_instance_type` | Instance type for RTP nodes | `t3.medium` |
| `rtp_node_count` | Number of RTP nodes | `1` |
| `allowed_ssh_cidr` | CIDR for SSH access | `0.0.0.0/0` |
| `allowed_http_cidr` | CIDR for HTTP/HTTPS access | `0.0.0.0/0` |

## Outputs

After deployment, Terraform outputs:

- `cluster_name` - EKS cluster name
- `cluster_endpoint` - Kubernetes API endpoint
- `configure_kubectl` - Command to configure kubectl
- `vpc_id` - VPC identifier
- Various subnet and security group IDs

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Notes

- SIP and RTP nodes are placed in public subnets with `map_public_ip_on_launch = true` to ensure VoIP traffic can reach them directly from carriers and endpoints worldwide.
- System nodes are in private subnets and use NAT Gateway for outbound internet access.
- VoIP pods should use `hostNetwork: true` to bind directly to the node's public IP.
