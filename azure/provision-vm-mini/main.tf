# Terraform configuration for jambonz mini deployment on Azure
# Equivalent to the Exoscale provision-vm-mini deployment

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------

# Look up the jambonz image by name or use ID directly
data "azurerm_image" "jambonz" {
  count               = var.image_id == "" ? 1 : 0
  name                = var.image_name
  resource_group_name = var.image_resource_group
}

locals {
  image_id = var.image_id != "" ? var.image_id : data.azurerm_image.jambonz[0].id
}

# ------------------------------------------------------------------------------
# RANDOM SECRETS
# ------------------------------------------------------------------------------

# Generate JWT secret
# No special characters to avoid sed escaping issues in cloud-init
resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

# Generate database password
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

# ------------------------------------------------------------------------------
# RESOURCE GROUP
# ------------------------------------------------------------------------------

resource "azurerm_resource_group" "jambonz" {
  name     = "${var.name_prefix}-rg"
  location = var.location

  tags = {
    environment = var.environment
    service     = "jambonz"
    deployment  = "mini"
  }
}

# ------------------------------------------------------------------------------
# VIRTUAL NETWORK
# ------------------------------------------------------------------------------

resource "azurerm_virtual_network" "jambonz" {
  name                = "${var.name_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_subnet" "jambonz" {
  name                 = "${var.name_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.jambonz.name
  virtual_network_name = azurerm_virtual_network.jambonz.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ------------------------------------------------------------------------------
# PUBLIC IP
# ------------------------------------------------------------------------------

resource "azurerm_public_ip" "jambonz" {
  name                = "${var.name_prefix}-pip"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# ------------------------------------------------------------------------------
# NETWORK SECURITY GROUP
# ------------------------------------------------------------------------------

resource "azurerm_network_security_group" "jambonz" {
  name                = "${var.name_prefix}-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  # SSH (22)
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  # HTTP (80)
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.allowed_http_cidr
    destination_address_prefix = "*"
  }

  # HTTPS (443)
  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.allowed_http_cidr
    destination_address_prefix = "*"
  }

  # SIP over UDP (5060)
  security_rule {
    name                       = "SIP-UDP"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = var.allowed_sip_cidr
    destination_address_prefix = "*"
  }

  # SIP over TCP (5060)
  security_rule {
    name                       = "SIP-TCP"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = var.allowed_sip_cidr
    destination_address_prefix = "*"
  }

  # SIP over TLS (5061)
  security_rule {
    name                       = "SIP-TLS"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5061"
    source_address_prefix      = var.allowed_sip_cidr
    destination_address_prefix = "*"
  }

  # SIP over WSS (8443)
  security_rule {
    name                       = "SIP-WSS"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix      = var.allowed_sip_cidr
    destination_address_prefix = "*"
  }

  # RTP (40000-60000)
  security_rule {
    name                       = "RTP"
    priority                   = 1008
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "40000-60000"
    source_address_prefix      = var.allowed_rtp_cidr
    destination_address_prefix = "*"
  }

  # Homer (9080)
  security_rule {
    name                       = "Homer"
    priority                   = 1009
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9080"
    source_address_prefix      = var.allowed_http_cidr
    destination_address_prefix = "*"
  }

  # Grafana (3000)
  security_rule {
    name                       = "Grafana"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = var.allowed_http_cidr
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# ------------------------------------------------------------------------------
# NETWORK INTERFACE
# ------------------------------------------------------------------------------

resource "azurerm_network_interface" "jambonz" {
  name                = "${var.name_prefix}-nic"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jambonz.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jambonz.id
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_network_interface_security_group_association" "jambonz" {
  network_interface_id      = azurerm_network_interface.jambonz.id
  network_security_group_id = azurerm_network_security_group.jambonz.id
}

# ------------------------------------------------------------------------------
# VIRTUAL MACHINE
# ------------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "jambonz" {
  name                = "${var.name_prefix}-jambonz-mini"
  resource_group_name = azurerm_resource_group.jambonz.name
  location            = azurerm_resource_group.jambonz.location
  size                = var.vm_size
  admin_username      = "jambonz"

  network_interface_ids = [
    azurerm_network_interface.jambonz.id,
  ]

  admin_ssh_key {
    username   = "jambonz"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.disk_size
  }

  source_image_id = local.image_id

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    url_portal           = var.url_portal
    jwt_secret           = random_password.jwt_secret.result
    db_password          = random_password.db_password.result
    instance_name        = "${var.name_prefix}-jambonz-mini"
    apiban_key           = var.apiban_key
    apiban_client_id     = var.apiban_client_id
    apiban_client_secret = var.apiban_client_secret
  }))

  tags = {
    environment = var.environment
    service     = "jambonz"
    deployment  = "mini"
  }
}
