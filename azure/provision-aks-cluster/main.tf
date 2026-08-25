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
# VoIP rules on the AKS-managed node NSG
# =============================================================================
#
# This is what actually opens SIP and RTP to the internet, and it is not
# optional. AKS attaches its OWN network security group (aks-agentpool-<n>-nsg,
# in the node resource group) to every node pool's VMSS NICs, and Azure requires
# traffic to be permitted by BOTH the NIC NSG and the subnet NSG. The
# subnet-level rules earlier in this file are therefore necessary but not
# sufficient: with only those, SIP and RTP to a node's public IP are dropped by
# the NIC NSG's default DenyAllInBound and the cluster cannot receive a call at
# all -- signalling never arrives, so every call test simply times out.
#
# This replaces two NSGs ("sip-nodes-nsg" and "rtp-nodes-nsg") that were created
# here and never associated with anything. The comment on them said they "will
# be associated with specific node pool VMSSs", which cannot be done for an
# AKS-managed VMSS: AKS owns the NIC's NSG reference and resets it. Adding rules
# to the NSG AKS already attached is the supported way to do this.
#
# The NSG's name is generated by AKS, so it is discovered after the node pools
# exist rather than referenced directly.

data "azurerm_resources" "aks_node_nsg" {
  type                = "Microsoft.Network/networkSecurityGroups"
  resource_group_name = azurerm_kubernetes_cluster.main.node_resource_group

  depends_on = [
    azurerm_kubernetes_cluster_node_pool.sip,
    azurerm_kubernetes_cluster_node_pool.rtp,
  ]
}

locals {
  # AKS names it aks-agentpool-<digits>-nsg. Match on the prefix rather than
  # taking resources[0], so an unrelated NSG in the node resource group cannot
  # silently become the target.
  aks_node_nsg_name = one([
    for r in data.azurerm_resources.aks_node_nsg.resources :
    r.name if startswith(r.name, "aks-agentpool-")
  ])
}

# SIP signalling. tfsec:ignore:azure-network-no-public-ingress - carriers and
# endpoints dial in from anywhere; this is the point of an SBC.
resource "azurerm_network_security_rule" "node_sip_udp" {
  name                        = "AllowSipUdp"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "5060"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_kubernetes_cluster.main.node_resource_group
  network_security_group_name = local.aks_node_nsg_name
}

# tfsec:ignore:azure-network-no-public-ingress
resource "azurerm_network_security_rule" "node_sip_tcp" {
  name                        = "AllowSipTcp"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["5060", "5061", "8443"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_kubernetes_cluster.main.node_resource_group
  network_security_group_name = local.aks_node_nsg_name
}

# RTP media. The range must match what rtpengine is configured to allocate from
# (port-min/port-max, 40000-60000), or media is dropped even when signalling
# succeeds.
# tfsec:ignore:azure-network-no-public-ingress
resource "azurerm_network_security_rule" "node_rtp_udp" {
  name                        = "AllowRtpUdp"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "40000-60000"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_kubernetes_cluster.main.node_resource_group
  network_security_group_name = local.aks_node_nsg_name
}

# Note: NSG association with VMSS must be done manually after cluster creation
# See README.md for post-deployment steps
