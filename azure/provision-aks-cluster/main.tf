resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network for AKS
resource "azurerm_virtual_network" "main" {
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]
}

# Subnets for different node pools
resource "azurerm_subnet" "system" {
  name                 = "system-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.system_subnet_prefix]
}

resource "azurerm_subnet" "sip" {
  name                 = "sip-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.sip_subnet_prefix]
}

resource "azurerm_subnet" "rtp" {
  name                 = "rtp-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.rtp_subnet_prefix]
}

# Network Security Group for System nodes
resource "azurerm_network_security_group" "system" {
  name                = "system-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # HTTP - Port 80 for LoadBalancer services (e.g., Traefik, ingress controllers)
  # tfsec:ignore:azure-network-no-public-ingress - Required for LoadBalancer services
  security_rule {
    name                       = "AllowHttpInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # HTTPS - Port 443 for LoadBalancer services (e.g., Traefik, ingress controllers)
  # tfsec:ignore:azure-network-no-public-ingress - Required for LoadBalancer services
  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow outbound internet access
  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# Network Security Group for SIP nodes
# Note: VoIP requires public internet access - SIP traffic originates from carriers,
# SIP trunks, and endpoints worldwide with unpredictable source IPs. Restricting
# source addresses would break VoIP functionality.
resource "azurerm_network_security_group" "sip" {
  name                = "sip-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # SIP UDP - Port 5060 is the standard SIP port
  # tfsec:ignore:azure-network-no-public-ingress - Required for VoIP, traffic comes from anywhere
  security_rule {
    name                       = "AllowSipUdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # SIP TCP - Port 5060
  # tfsec:ignore:azure-network-no-public-ingress - Required for VoIP, traffic comes from anywhere
  security_rule {
    name                       = "AllowSipTcp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # SIP TLS - Port 5061 for secure SIP
  # tfsec:ignore:azure-network-no-public-ingress - Required for VoIP, traffic comes from anywhere
  security_rule {
    name                       = "AllowSipTls"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5061"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Websocket Secure - Port 8443 for WebRTC signaling
  # tfsec:ignore:azure-network-no-public-ingress - Required for VoIP, traffic comes from anywhere
  security_rule {
    name                       = "AllowWebsocketSecure"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Security Group for RTP nodes
# Note: VoIP requires public internet access - RTP (media) traffic originates from
# anywhere on the internet with unpredictable source IPs. Restricting source addresses
# would break VoIP functionality.
resource "azurerm_network_security_group" "rtp" {
  name                = "rtp-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # RTP UDP - Ports 40000-60000 for real-time media (audio/video)
  # tfsec:ignore:azure-network-no-public-ingress - Required for VoIP, media comes from anywhere
  security_rule {
    name                       = "AllowRtpUdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "40000-60000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "system" {
  subnet_id                 = azurerm_subnet.system.id
  network_security_group_id = azurerm_network_security_group.system.id
}

resource "azurerm_subnet_network_security_group_association" "sip" {
  subnet_id                 = azurerm_subnet.sip.id
  network_security_group_id = azurerm_network_security_group.sip.id
}

resource "azurerm_subnet_network_security_group_association" "rtp" {
  subnet_id                 = azurerm_subnet.rtp.id
  network_security_group_id = azurerm_network_security_group.rtp.id
}

# =============================================================================
# Public IP Prefix for SIP Node Pool
# Provides a known IP range for carrier whitelisting.
# RTP nodes use ephemeral public IPs (no prefix needed for whitelisting).
# =============================================================================

resource "azurerm_public_ip_prefix" "sip" {
  name                = "${var.cluster_name}-sip-ip-prefix"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  prefix_length       = var.sip_public_ip_prefix_length
  sku                 = "Standard"
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.dns_prefix

  # AKS enables the OIDC issuer on new clusters and will not let it be turned
  # off again. Leaving this unset makes the provider default it to false, so
  # every apply after the first one tries to disable it and Azure rejects the
  # whole update:
  #
  #   Error: updating Kubernetes Cluster ... unexpected status 400
  #     "code": "OIDCIssuerFeatureCannotBeDisabled",
  #     "message": "OIDC issuer feature cannot be disabled."
  #
  # That made this module effectively single-shot: a second apply failed no
  # matter what you were changing -- scaling a pool, adding a pool, a version
  # bump -- because the cluster resource itself could never converge.
  oidc_issuer_enabled = true

  # Default/System node pool
  default_node_pool {
    name           = "system"
    node_count     = var.system_node_count
    vm_size        = var.system_vm_size
    vnet_subnet_id = azurerm_subnet.system.id
  }

  # Network configuration
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  # Enable RBAC for secure access control
  role_based_access_control_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

# SIP Node Pool - For SIP signaling
resource "azurerm_kubernetes_cluster_node_pool" "sip" {
  name                     = "sip"
  kubernetes_cluster_id    = azurerm_kubernetes_cluster.main.id
  vm_size                  = var.sip_vm_size
  node_count               = var.sip_node_count
  enable_auto_scaling      = true
  min_count                = var.sip_min_count
  max_count                = var.sip_max_count
  enable_node_public_ip    = true
  node_public_ip_prefix_id = azurerm_public_ip_prefix.sip.id
  vnet_subnet_id           = azurerm_subnet.sip.id

  node_labels = {
    "voip-environment" = "sip"
  }

  node_taints = [
    "sip=true:NoSchedule"
  ]
}

# RTP Node Pool - For RTP media processing
resource "azurerm_kubernetes_cluster_node_pool" "rtp" {
  name                  = "rtp"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.rtp_vm_size
  node_count            = var.rtp_node_count
  enable_auto_scaling   = true
  min_count             = var.rtp_min_count
  max_count             = var.rtp_max_count
  enable_node_public_ip = true
  vnet_subnet_id        = azurerm_subnet.rtp.id

  node_labels = {
    "voip-environment" = "rtp"
  }

  node_taints = [
    "rtp=true:NoSchedule"
  ]
}

# =============================================================================
# Per-node-pool NSGs, and their association with the VoIP VMSSs
# =============================================================================
#
# Why this exists at all: AKS attaches its own NSG to every node pool's VMSS
# NICs, and Azure requires traffic to be permitted by BOTH the NIC NSG and the
# subnet NSG. The subnet rules earlier in this file are therefore necessary but
# not sufficient -- until the VoIP pools carry an NSG that allows SIP and RTP,
# the AKS NSG's default DenyAllInBound drops them and the cluster cannot receive
# a call. Nothing looks wrong when this is missing: all pods Running, drachtio
# listening on 5060, and an explicit allow visible on the subnet NSG, while
# `nc <node ip> 5060` from outside gets no answer and every call test times out.
#
# A distinct NSG per pool is deliberate: SIP ports are opened only on SIP nodes
# and the media range only on RTP nodes, so the system pool keeps AKS's
# restrictive default. A single NSG covering every pool would be simpler but
# would open the VoIP ports on the system nodes too.

resource "azurerm_network_security_group" "sip_nodes" {
  name                = "sip-nodes-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_kubernetes_cluster.main.node_resource_group

  depends_on = [azurerm_kubernetes_cluster.main]

  # tfsec:ignore:azure-network-no-public-ingress - Required for VoIP, traffic comes from anywhere
  security_rule {
    name                       = "AllowSipUdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # tfsec:ignore:azure-network-no-public-ingress - Required for VoIP, traffic comes from anywhere
  security_rule {
    name                       = "AllowSipTcp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5060", "5061", "8443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "rtp_nodes" {
  name                = "rtp-nodes-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_kubernetes_cluster.main.node_resource_group

  depends_on = [azurerm_kubernetes_cluster.main]

  # The range must match what rtpengine allocates from (port-min/port-max,
  # 40000-60000) or media is dropped even when signalling succeeds.
  # tfsec:ignore:azure-network-no-public-ingress - Required for VoIP, traffic comes from anywhere
  security_rule {
    name                       = "AllowRtpUdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "40000-60000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# The association itself. This was previously a manual step in the README
# ("IMPORTANT!! Associate NSGs with Node Pools"), easy to miss and easy to get
# wrong -- skipping it produces the silent no-signalling failure described above.
#
# It is a local-exec because there is no provider-managed way to set the NSG on
# an AKS-managed VMSS NIC: the AKS node pool resource does not expose it. The
# same caveat as the manual procedure applies -- this reaches into the
# AKS-managed resource group, and AKS may reset the NIC's NSG reference during
# some reconcile or upgrade operations. If SIP stops arriving after a cluster
# upgrade, re-run terraform apply (or taint this resource) before looking
# anywhere else.
#
# Requires the az CLI, authenticated -- which provisioning this module needs
# anyway.

resource "null_resource" "associate_voip_nsgs" {
  triggers = {
    sip_nsg  = azurerm_network_security_group.sip_nodes.id
    rtp_nsg  = azurerm_network_security_group.rtp_nodes.id
    sip_pool = azurerm_kubernetes_cluster_node_pool.sip.id
    rtp_pool = azurerm_kubernetes_cluster_node_pool.rtp.id

    # Needed by the destroy-time provisioner below, which may only read `self`.
    node_rg = azurerm_kubernetes_cluster.main.node_resource_group
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      NODE_RG = azurerm_kubernetes_cluster.main.node_resource_group
      SIP_NSG = azurerm_network_security_group.sip_nodes.id
      RTP_NSG = azurerm_network_security_group.rtp_nodes.id
    }

    command = <<-EOT
      set -euo pipefail
      for pool in sip rtp; do
        if [ "$pool" = sip ]; then NSG="$SIP_NSG"; else NSG="$RTP_NSG"; fi

        VMSS=$(az vmss list -g "$NODE_RG" --query "[?starts_with(name, 'aks-$pool-')].name" -o tsv)
        if [ -z "$VMSS" ]; then
          echo "no VMSS matching aks-$pool-* in $NODE_RG" >&2
          exit 1
        fi

        echo "associating $pool-nodes-nsg with $VMSS"
        az vmss update -g "$NODE_RG" -n "$VMSS" --set virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].networkSecurityGroup.id="$NSG" -o none
        az vmss update-instances -g "$NODE_RG" -n "$VMSS" --instance-ids '*' -o none
      done
      echo "VoIP NSGs associated; allow a few minutes to take effect"
    EOT
  }

  # Undo the association on the way out. Azure refuses to delete an NSG that a
  # scale set still references:
  #
  #   Error: deleting Network Security Group ... 400
  #     NetworkSecurityGroupInUseByVirtualMachineScaleSet: Cannot delete network
  #     security group .../sip-nodes-nsg since it is in use by virtual machine
  #     scale set .../AKS-SIP-...-VMSS
  #
  # so without this a plain `terraform destroy` fails partway: the node pools go,
  # then both NSG deletions error out, and the run has to be repeated (which then
  # succeeds, because by that point the scale sets are gone). Destroying this
  # resource first -- terraform does, since the NSGs and pools are its
  # dependencies -- clears the reference while the scale sets still exist.
  #
  # Deliberately forgiving: at destroy time the scale sets may already be gone,
  # or the cluster may never have finished creating. Nothing here should be able
  # to block a teardown.
  provisioner "local-exec" {
    when        = destroy
    on_failure  = continue
    interpreter = ["/bin/bash", "-c"]

    environment = {
      NODE_RG = self.triggers.node_rg
    }

    command = <<-EOT
      set +e
      for pool in sip rtp; do
        VMSS=$(az vmss list -g "$NODE_RG" --query "[?starts_with(name, 'aks-$pool-')].name" -o tsv 2>/dev/null)
        if [ -z "$VMSS" ]; then
          echo "no aks-$pool-* scale set in $NODE_RG; nothing to disassociate"
          continue
        fi
        echo "disassociating NSG from $VMSS"
        az vmss update -g "$NODE_RG" -n "$VMSS" --remove virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].networkSecurityGroup -o none
      done
      exit 0
    EOT
  }
}

# Note: NSG association with VMSS must be done manually after cluster creation
# See README.md for post-deployment steps
