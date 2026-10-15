# Terraform configuration for jambonz mini deployment on Azure
# Equivalent to the Exoscale provision-vm-mini deployment

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # 4.55 adds azurerm_log_analytics_workspace_table_custom_log (pm2 log table)
      version = "~> 4.55"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# ------------------------------------------------------------------------------
# COMMUNITY GALLERY IMAGE
# Images are published to the jambonz Azure Community Gallery
# Community Gallery image IDs use format: /communityGalleries/{gallery}/images/{image}/versions/{version}
# ------------------------------------------------------------------------------

locals {
  # arm64 images live in separate gallery definitions (jambonz-<variant>-arm64)
  # because an Azure image definition declares one architecture.
  image_arch_suffix = var.architecture == "arm64" ? "-arm64" : ""
  image_id          = "/communityGalleries/${var.community_gallery_name}/images/jambonz-mini${local.image_arch_suffix}/versions/${var.jambonz_version}"
}

# ------------------------------------------------------------------------------
# SECRETS
#
# The JWT/encryption secret and the MySQL password are generated on the VM at
# first boot (see cloud-init.yaml). Nothing outside the VM uses them, so they
# never appear in custom_data or in terraform state.
#
# Secrets you supply (apiban, Krisp) go in a Key Vault, created only when at
# least one is set, and the VM reads them at boot with its managed identity.
# ------------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

locals {
  supplied_secret_values = {
    "apiban-key"           = var.apiban_key
    "apiban-client-secret" = var.apiban_client_secret
    "krisp-license-key"    = var.krisp_license_key
  }
  # Whether each secret is set is not itself secret.
  supplied_secret_names = toset([for k, v in local.supplied_secret_values : k if nonsensitive(v != "")])
  use_key_vault         = length(local.supplied_secret_names) > 0
}

resource "azurerm_user_assigned_identity" "jambonz" {
  name                = "${var.name_prefix}-identity"
  resource_group_name = azurerm_resource_group.jambonz.name
  location            = azurerm_resource_group.jambonz.location

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_key_vault" "jambonz" {
  count                      = local.use_key_vault ? 1 : 0
  name                       = "${var.name_prefix}-kv"
  location                   = azurerm_resource_group.jambonz.location
  resource_group_name        = azurerm_resource_group.jambonz.name
  tenant_id                  = var.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  sku_name                   = "standard"

  access_policy {
    tenant_id          = var.tenant_id
    object_id          = data.azurerm_client_config.current.object_id
    secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
  }

  # Read named secrets only.
  access_policy {
    tenant_id          = var.tenant_id
    object_id          = azurerm_user_assigned_identity.jambonz.principal_id
    secret_permissions = ["Get"]
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_key_vault_secret" "supplied" {
  for_each     = local.supplied_secret_names
  name         = each.key
  value        = local.supplied_secret_values[each.key]
  key_vault_id = azurerm_key_vault.jambonz[0].id
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

  # Grafana (3000)

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

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jambonz.id]
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    url_portal         = var.url_portal
    instance_name      = "${var.name_prefix}-jambonz-mini"
    key_vault_name     = local.use_key_vault ? azurerm_key_vault.jambonz[0].name : ""
    identity_client_id = azurerm_user_assigned_identity.jambonz.client_id
    apiban_key_set     = var.apiban_key != ""
    apiban_client_id   = var.apiban_client_id
    apiban_client_set  = var.apiban_client_secret != ""
    krisp_key_set      = var.krisp_license_key != ""
  }))

  depends_on = [azurerm_key_vault_secret.supplied]

  tags = {
    environment = var.environment
    service     = "jambonz"
    deployment  = "mini"
  }
}
