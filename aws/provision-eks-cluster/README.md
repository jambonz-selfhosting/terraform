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

### Elastic IPs for VoIP Nodes

This configuration creates dedicated Elastic IPs for the SIP and RTP nodes:

| EIP | Tag | Purpose |
|-----|-----|---------|
| `${cluster_name}-sip-eip` | `role: ${cluster_name}-sip-node` | Static IP for SIP signaling |
| `${cluster_name}-rtp-eip` | `role: ${cluster_name}-rtp-node` | Static IP for RTP media |

These EIPs are automatically associated with the SIP and RTP nodes when the jambonz helm chart is deployed. The `ec2-eip-allocator` init container in the SBC pods matches EIPs to nodes using the `role` tag.

**Benefits of static EIPs:**
- Consistent IP addresses for SIP trunks and carrier configurations
- Survives node replacements and cluster upgrades
- Required for many SIP providers that need IP whitelisting

### IAM Policies

The EKS node role includes an inline policy (`eip_allocator`) that allows the `ec2-eip-allocator` to assign Elastic IPs:

| Permission | Purpose |
|------------|---------|
| `ec2:DescribeAddresses` | List available EIPs |
| `ec2:AssociateAddress` | Assign EIP to node |
| `ec2:DisassociateAddress` | Release EIP from node |
| `ec2:DescribeInstances` | Get node instance info |
| `ec2:DescribeNetworkInterfaces` | Get network interface info |

This allows the EIP allocator to work using the node's IAM role (via IMDSv2) without requiring a separate AWS credentials secret.

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

## Deploying jambonz

After the EKS cluster is ready, deploy jambonz using the helm chart:

1. **Install the helm chart:**
   ```bash
   helm install jambonz <path-to-helm-chart> \
     -f <path-to-helm-chart>/values-aws.yaml \
     --namespace jambonz \
     --create-namespace
   ```

2. **Monitor the deployment:**
   ```bash
   kubectl get pods -n jambonz -w
   ```

3. **Verify EIP association:**

   After the SBC pods start, the ec2-eip-allocator init container will assign the Elastic IPs to the nodes. Verify with:
   ```bash
   aws ec2 describe-addresses --region <region> \
     --filters "Name=tag-key,Values=role" \
     --query 'Addresses[*].{Name:Tags[?Key==`Name`].Value|[0],PublicIp:PublicIp,InstanceId:InstanceId}' \
     --output table
   ```

4. **Access the jambonz portal:**

   Get the ingress URL or configure DNS to point to your load balancer.

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
- `sip_eip_public_ip` - Elastic IP address for SIP node
- `rtp_eip_public_ip` - Elastic IP address for RTP node
- `sip_eip_allocation_id` - SIP EIP allocation ID
- `rtp_eip_allocation_id` - RTP EIP allocation ID
- Various subnet and security group IDs

## Cleanup

Before destroying the cluster, you must clean up resources in the correct order.

**1. Uninstall jambonz helm chart:**
```bash
helm uninstall jambonz -n jambonz
```

**2. Delete the namespace:**
```bash
kubectl delete namespace jambonz
```

**3. Delete any remaining Kubernetes LoadBalancer services:**
```bash
# Delete all LoadBalancer services (this removes the ELBs they created)
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer

# If using ingresses with ALB controller
kubectl delete ingress --all-namespaces

# Wait for AWS to clean up the load balancers and ENIs
sleep 60
```

**4. Destroy the infrastructure:**
```bash
terraform destroy
```

**If `terraform destroy` hangs:**

This usually means orphaned load balancers or network interfaces still exist. To find them:

```bash
# List classic ELBs
aws elb describe-load-balancers --region <region> --query 'LoadBalancerDescriptions[*].[LoadBalancerName,VPCId]' --output table

# List ALBs/NLBs
aws elbv2 describe-load-balancers --region <region> --query 'LoadBalancers[*].[LoadBalancerName,VpcId]' --output table

# Delete orphaned ELBs (the name often contains 'k8s' or a hash)
aws elb delete-load-balancer --load-balancer-name <elb-name> --region <region>
```

After cleaning up the load balancers, wait a minute for ENIs to be released, then retry `terraform destroy`.

**If the VPC deletion hangs:**

Kubernetes-created security groups (for load balancers) may still exist:

```bash
# List security groups in the VPC
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>" --region <region> --query 'SecurityGroups[*].[GroupId,GroupName]' --output table

# Delete any k8s/ELB security groups (not the "default" one)
aws ec2 delete-security-group --group-id <sg-id> --region <region>
```

## Notes

- SIP and RTP nodes are placed in public subnets with `map_public_ip_on_launch = true` to ensure VoIP traffic can reach them directly from carriers and endpoints worldwide.
- System nodes are in private subnets and use NAT Gateway for outbound internet access.
- VoIP pods should use `hostNetwork: true` to bind directly to the node's public IP.
