# Kubernetes Cluster Provisioning for jambonz on AKS

Terraform configuration for provisioning a jambonz Kubernetes cluster on Azure (AKS) with remote state management via HCP Terraform.

Due to the nature of SIP and RTP signaling, where media streams are negotiated using public IP addresses carried in the SIP messaging, running VoIP traffic in a Kubernetes cluster has always presented challenges.  The tried-and-true method for doing so is to create separate node pools for SIP and RTP traffic and allow host networking in these pools along with sip and rtp daemonsets that can bind to the public address.  That is the approach we take here in creating the cluster. 

## Prerequisites

1. **Azure CLI** - Installed and authenticated
   ```bash
   az login
   ```

2. **Terraform CLI** - Version 1.5 or higher
   ```bash
   terraform version
   ```

3. **HCP Terraform Account** - Sign up at https://app.terraform.io if you haven't already

## Setup

### 1. Configure HCP Terraform

Edit [versions.tf](versions.tf) and update the `cloud` block with your HCP Terraform details:
- Replace `jambonz` with your HCP Terraform organization name
- Replace `jambonz-test` with your desired workspace name

**Note**: The `cloud` block doesn't support variables, so these values must be hardcoded. For different environments, you can maintain separate versions.tf files or use backend configuration files.

### 2. Customize Variables (Optional)

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to customize:
- Resource group name and location
- Cluster name and DNS prefix
- Network configuration (VNet, subnets)
- Node pool sizing (VM sizes, node counts, autoscaling limits)

**Note**: `terraform.tfvars` is gitignored and won't be committed to version control, making it safe for environment-specific values.

### 3. Authenticate with HCP Terraform

```bash
terraform login
```

This will open a browser to generate an API token.

### 4. Initialize Terraform

```bash
terraform init
```

### 5. Review and Apply

```bash
terraform plan
terraform apply
```

### 6. Get Kubeconfig

After the cluster is created, configure kubectl to access it:

```bash
az aks get-credentials --resource-group voip-k8s-rg --name voip-k8s-cluster
```

**Note**: If you customized the resource group or cluster name in your `terraform.tfvars`, use those values instead.

Verify connectivity:

```bash
kubectl get nodes
```

### 7. Associate NSGs with Node Pools (Required)

The per-node-pool NSGs must be manually associated with the VMSSs. See the [Post-Deployment NSG Association](#post-deployment-associate-nsgs-with-node-pools) section below for detailed instructions.

## Current Configuration

This creates an AKS cluster with custom networking for VoIP workloads:

### Network Architecture
- **VNet**: voip-k8s-vnet (10.0.0.0/16)
- **System Subnet**: 10.0.1.0/24 - For system node pool
- **SIP Subnet**: 10.0.2.0/24 - For SIP node pool
- **RTP Subnet**: 10.0.3.0/24 - For RTP node pool

### Network Security Groups (Firewall Rules)
- **System NSG**: Default outbound internet access
- **SIP NSG**: Allows inbound traffic on:
  - UDP 5060 (SIP)
  - TCP 5060 (SIP)
  - TCP 5061 (SIP TLS)
  - TCP 8443 (WebSocket Secure)
- **RTP NSG**: Allows inbound traffic on:
  - UDP 40000-60000 (RTP media)

### Cluster Resources
- **Resource Group**: voip-k8s-rg in eastus
- **Cluster**: voip-k8s-cluster
- **Network Plugin**: Azure CNI
- **Default Node Pool (system)**: 2 nodes (Standard_D2s_v3) - for regular workloads
- **SIP Node Pool**: 2-10 nodes (Standard_F4s_v2) with auto-scaling
  - Public IP per node enabled
  - Taint: `sip=true:NoSchedule`
  - Label: `voip-environment=sip`
  - Subnet: SIP subnet with SIP NSG
- **RTP Node Pool**: 2-10 nodes (Standard_F4s_v2) with auto-scaling
  - Public IP per node enabled
  - Taint: `rtp=true:NoSchedule`
  - Label: `voip-environment=rtp`
  - Subnet: RTP subnet with RTP NSG
- **Identity**: System-assigned managed identity

## Getting Kubeconfig

After cluster creation:

```bash
# Using Azure CLI
az aks get-credentials --resource-group voip-k8s-rg --name voip-k8s-cluster

# Or from Terraform output
terraform output -raw kubeconfig > ~/.kube/config-voip
export KUBECONFIG=~/.kube/config-voip
```

## Using VoIP Node Pools with Host Networking

The VoIP node pools are configured with:
- **Public IPs per node** - Each node gets a public IP that pods can bind to
- **Taints** - Prevents non-VoIP pods from scheduling on these nodes
- **Labels** - Allows targeting specific VoIP pools


## Network Security

The configuration uses **per-node-pool NSGs** for security isolation, ensuring VoIP ports are only open on nodes that need them.

### NSG Architecture

This configuration uses a **three-layer NSG approach** for defense-in-depth:

1. **Subnet-level NSGs** (created by Terraform in voip-k8s-rg):
   - `system-nsg` - Associated with system-subnet
   - `sip-nsg` - Associated with sip-subnet
   - `rtp-nsg` - Associated with rtp-subnet
   - Provides network-level isolation between node pools

2. **Per-node-pool NSGs** (created by Terraform in MC_ resource group):
   - `sip-nodes-nsg` - Associated with SIP VMSS NICs only
   - `rtp-nodes-nsg` - Associated with RTP VMSS NICs only
   - **Key benefit**: System nodes do NOT have VoIP ports open at the firewall level

3. **Default AKS NSG** (created by AKS):
   - `aks-agentpool-*-nsg` - Default NSG, replaced by our custom NSGs for SIP/RTP pools
   - Remains on system nodes with default restrictive rules

### Security Benefits

This approach provides **proper security isolation**:

- **SIP nodes**: Only have SIP ports (5060, 5061, 8443) open
- **RTP nodes**: Only have RTP ports (40000-60000) open
- **System nodes**: Use default AKS NSG with minimal inbound access
- Each node pool has firewall rules specific to its function

### Firewall Rules by Node Pool

**SIP Nodes** (sip-nodes-nsg):
- UDP 5060 (SIP)
- TCP 5060 (SIP)
- TCP 5061 (SIP TLS)
- TCP 8443 (WebSocket Secure)

**RTP Nodes** (rtp-nodes-nsg):
- UDP 40000-60000 (RTP media)

**System Nodes** (default AKS NSG):
- No custom inbound rules (default deny for internet traffic)

This is the Azure equivalent of:
- **AWS**: Per-instance Security Groups
- **GCP**: Per-instance Network Tags with Firewall Rules

### Viewing NSG Rules in Azure Portal

1. Navigate to **Network Security Groups** in Azure Portal
2. Look in the **MC_voip-k8s-rg_voip-k8s-cluster_eastus** resource group (the AKS-managed resource group)
3. Find the NSGs named `sip-nodes-nsg` and `rtp-nodes-nsg`
4. Click **Inbound security rules** to see the VoIP firewall rules

### Post-Deployment: Associate NSGs with Node Pools

After running `terraform apply`, you need to manually associate the per-node-pool NSGs with the VMSSs. Run these commands locally (requires Azure CLI):

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

These commands:
1. Get the managed resource group name dynamically from Terraform output
2. Find the SIP and RTP VMSSs in the managed resource group
3. Update each VMSS to use its specific NSG
4. Apply the changes to all existing instances
5. Future scale-up events will automatically use the correct NSG

After running these commands you will need to wait 5-10 minutes for the new NSGs to take affect on the sip and rtp nodes.

## Verifying the Setup

After applying, verify the node pools:

```bash
# List all nodes with VoIP environment labels
kubectl get nodes -L voip-environment

# Check taints on SIP and RTP nodes
kubectl describe nodes | grep -A 5 Taints

# Verify public IPs are assigned to SIP and RTP nodes
kubectl get nodes -o wide

# Show only SIP nodes
kubectl get nodes -l voip-environment=sip

# Show only RTP nodes
kubectl get nodes -l voip-environment=rtp
```

## Cleanup

To destroy the cluster and all resources, you **must first remove the manual NSG associations** before running `terraform destroy`.

### Step 1: Remove NSG Associations from VMSSs

Since we manually associated the per-node-pool NSGs with the VMSSs, we must remove them before Terraform can destroy the resources:

```bash
# Get the managed resource group name from Terraform
RESOURCE_GROUP=$(terraform output -raw node_resource_group)

# Find the VMSS names
SIP_VMSS=$(az vmss list -g $RESOURCE_GROUP --query "[?contains(name, 'sip')].name" -o tsv)
RTP_VMSS=$(az vmss list -g $RESOURCE_GROUP --query "[?contains(name, 'rtp')].name" -o tsv)

# Verify the variables are set
echo "Resource Group: $RESOURCE_GROUP"
echo "SIP VMSS: $SIP_VMSS"
echo "RTP VMSS: $RTP_VMSS"

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

### Step 2: Run Terraform Destroy

After removing the NSG associations, you can destroy the infrastructure:

```bash
terraform destroy
```

**Important**: If you skip Step 1 and run `terraform destroy` directly, you will get errors like:
```
Error: NetworkSecurityGroupInUseByVirtualMachineScaleSet: Cannot delete network security group...
since it is in use by virtual machine scale set...
```

If this happens, simply run the Step 1 commands and then run `terraform destroy` again.
