# Azure AKS Cluster for jambonz VoIP

This Terraform configuration deploys an Azure AKS (Azure Kubernetes Service) cluster optimized for jambonz VoIP workloads. Separate node pools for SIP and RTP traffic use host networking so that VoIP pods can bind directly to the node's public IP address.

## Architecture

### Node Pools

| Node Pool | Purpose | Subnet | Public IP | Taint | Label |
|-----------|---------|--------|-----------|-------|-------|
| **system** | General workloads, K8s system components | System (10.0.1.0/24) | No | None | - |
| **sip** | SIP signaling (drachtio-server) | SIP (10.0.2.0/24) | Yes (per node) | `sip=true:NoSchedule` | `voip-environment=sip` |
| **rtp** | RTP media (rtpengine, freeswitch) | RTP (10.0.3.0/24) | Yes (per node) | `rtp=true:NoSchedule` | `voip-environment=rtp` |

### Network Architecture

- **VNet**: 10.0.0.0/16
- **System Subnet**: 10.0.1.0/24
- **SIP Subnet**: 10.0.2.0/24
- **RTP Subnet**: 10.0.3.0/24
- **Network Plugin**: Azure CNI
- **Identity**: System-assigned managed identity

### Network Security Groups

The configuration uses a three-layer NSG approach for defense-in-depth:

1. **Subnet-level NSGs** (created by Terraform in the resource group):
   - `system-nsg` - Associated with system-subnet
   - `sip-nsg` - Associated with sip-subnet
   - `rtp-nsg` - Associated with rtp-subnet

2. **Per-node-pool NSGs** (created by Terraform in MC_ resource group):
   - `sip-nodes-nsg` - Associated with SIP VMSS NICs only
   - `rtp-nodes-nsg` - Associated with RTP VMSS NICs only

3. **Default AKS NSG** (created by AKS):
   - Remains on system nodes with default restrictive rules

**Firewall Rules by Node Pool:**

| Node Pool | Ports | Protocol |
|-----------|-------|----------|
| **SIP** | 5060 | UDP/TCP |
| **SIP** | 5061 | TCP |
| **SIP** | 8443 | TCP |
| **RTP** | 40000-60000 | UDP |
| **System** | Default AKS NSG (minimal inbound) | - |

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Terraform >= 1.5
- `kubectl` installed

## Usage

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

### 2. Initialize and Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl

```bash
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
kubectl get nodes
```

### 4. Verify the Cluster

```bash
kubectl get nodes -L voip-environment
kubectl describe nodes | grep -A5 Taints
kubectl get nodes -o wide
```

### 5. IMPORTANT!! Associate NSGs with Node Pools (Required)

The per-node-pool NSGs must be manually associated with the VMSSs after cluster creation.
DO THIS BEFORE RUNNING THE HELM CHART!

```bash
# Get the managed resource group name from Terraform
RESOURCE_GROUP=$(terraform output -raw node_resource_group)

# Set NSG resource IDs
SIP_NSG_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/networkSecurityGroups/sip-nodes-nsg"
RTP_NSG_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/networkSecurityGroups/rtp-nodes-nsg"

# Find and update SIP VMSS
SIP_VMSS=$(az vmss list -g $RESOURCE_GROUP --query "[?contains(name, 'sip')].name" -o tsv)
az vmss update -g $RESOURCE_GROUP -n $SIP_VMSS \
  --set virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].networkSecurityGroup.id=$SIP_NSG_ID

# Find and update RTP VMSS
RTP_VMSS=$(az vmss list -g $RESOURCE_GROUP --query "[?contains(name, 'rtp')].name" -o tsv)
az vmss update -g $RESOURCE_GROUP -n $RTP_VMSS \
  --set virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].networkSecurityGroup.id=$RTP_NSG_ID

# Update existing instances
az vmss update-instances -g $RESOURCE_GROUP -n $SIP_VMSS --instance-ids "*"
az vmss update-instances -g $RESOURCE_GROUP -n $RTP_VMSS --instance-ids "*"
```

Wait 5-10 minutes for the new NSGs to take effect on the SIP and RTP nodes.

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `resource_group_name` | Name of the Azure resource group | `voip-k8s-rg` |
| `location` | Azure region | `eastus` |
| `cluster_name` | AKS cluster name | `voip-k8s-cluster` |
| `dns_prefix` | DNS prefix for the cluster | `voip-k8s` |
| `vnet_address_space` | VNet address space | `10.0.0.0/16` |
| `system_subnet_prefix` | System subnet CIDR | `10.0.1.0/24` |
| `sip_subnet_prefix` | SIP subnet CIDR | `10.0.2.0/24` |
| `rtp_subnet_prefix` | RTP subnet CIDR | `10.0.3.0/24` |
| `service_cidr` | Kubernetes services CIDR | `172.16.0.0/16` |
| `dns_service_ip` | Kubernetes DNS service IP | `172.16.0.10` |
| `system_vm_size` | VM size for system nodes | `Standard_D2s_v3` |
| `system_node_count` | Number of system nodes | `2` |
| `sip_vm_size` | VM size for SIP nodes | `Standard_D2s_v3` |
| `sip_node_count` | Initial SIP node count | `1` |
| `sip_min_count` | Min SIP nodes (autoscaling) | `1` |
| `sip_max_count` | Max SIP nodes (autoscaling) | `10` |
| `rtp_vm_size` | VM size for RTP nodes | `Standard_D2s_v3` |
| `rtp_node_count` | Initial RTP node count | `1` |
| `rtp_min_count` | Min RTP nodes (autoscaling) | `1` |
| `rtp_max_count` | Max RTP nodes (autoscaling) | `10` |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | AKS cluster name |
| `resource_group_name` | Resource group name |
| `kubeconfig` | Kubeconfig for connecting to the cluster (sensitive) |
| `sip_pool_name` | Name of the SIP node pool |
| `rtp_pool_name` | Name of the RTP node pool |
| `vnet_name` | Virtual network name |
| `sip_subnet_id` | SIP subnet ID |
| `rtp_subnet_id` | RTP subnet ID |
| `node_resource_group` | AKS managed resource group name (MC_*) |

## Deploying jambonz

After the cluster is provisioned, deploy jambonz using the [jambonz Helm chart](https://github.com/jambonz-selfhosting/helm-chart). Refer to the Helm chart README for detailed installation instructions.

## Cleanup

To destroy the cluster, you **must first remove the manual NSG associations** before running `terraform destroy`.

### Step 1: Remove NSG Associations from VMSSs

```bash
# Get the managed resource group name from Terraform
RESOURCE_GROUP=$(terraform output -raw node_resource_group)

# Find the VMSS names
SIP_VMSS=$(az vmss list -g $RESOURCE_GROUP --query "[?contains(name, 'sip')].name" -o tsv)
RTP_VMSS=$(az vmss list -g $RESOURCE_GROUP --query "[?contains(name, 'rtp')].name" -o tsv)

# Remove NSG association from SIP VMSS
az vmss update -g $RESOURCE_GROUP -n $SIP_VMSS \
  --remove virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].networkSecurityGroup

# Remove NSG association from RTP VMSS
az vmss update -g $RESOURCE_GROUP -n $RTP_VMSS \
  --remove virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].networkSecurityGroup

# Update the instances to apply the changes
az vmss update-instances -g $RESOURCE_GROUP -n $SIP_VMSS --instance-ids "*"
az vmss update-instances -g $RESOURCE_GROUP -n $RTP_VMSS --instance-ids "*"
```

### Step 2: Destroy the Infrastructure

```bash
terraform destroy
```

If you skip Step 1, you will get errors like `NetworkSecurityGroupInUseByVirtualMachineScaleSet`. Run the Step 1 commands and retry `terraform destroy`.
