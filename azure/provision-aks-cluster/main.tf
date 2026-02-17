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

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.dns_prefix

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
  name                  = "sip"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.sip_vm_size
  node_count            = var.sip_node_count
  enable_auto_scaling   = true
  min_count             = var.sip_min_count
  max_count             = var.sip_max_count
  enable_node_public_ip = true # Critical for VoIP - allows pods to bind to public IPs
  vnet_subnet_id        = azurerm_subnet.sip.id

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

# Per-node-pool NSGs for better security isolation
# These NSGs will be associated with specific node pool VMSSs
# VoIP requires public internet access - see comment on subnet NSGs above

# NSG for SIP nodes only - created in AKS managed resource group
resource "azurerm_network_security_group" "sip_nodes" {
  name                = "sip-nodes-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_kubernetes_cluster.main.node_resource_group

  depends_on = [azurerm_kubernetes_cluster.main]

  # SIP UDP 5060
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

  # SIP TCP 5060
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

  # SIP TLS TCP 5061
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

  # Websocket Secure TCP 8443
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

# NSG for RTP nodes only - created in AKS managed resource group
resource "azurerm_network_security_group" "rtp_nodes" {
  name                = "rtp-nodes-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_kubernetes_cluster.main.node_resource_group

  depends_on = [azurerm_kubernetes_cluster.main]

  # RTP UDP 40000-60000
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

# Note: NSG association with VMSS must be done manually after cluster creation
# See README.md for post-deployment steps
