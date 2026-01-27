# Terraform configuration for jambonz medium cluster deployment on Azure
# Equivalent to the AWS CloudFormation jambonz.yaml deployment

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
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Get current client configuration for Key Vault access policies
data "azurerm_client_config" "current" {}

# ------------------------------------------------------------------------------
# RANDOM SECRETS
# ------------------------------------------------------------------------------

# Generate JWT/Encryption secret
resource "random_password" "encryption_secret" {
  length  = 32
  special = false
}

# Generate database password if not provided
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

locals {
  db_password = var.mysql_password != "" ? var.mysql_password : random_password.db_password.result
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
    deployment  = "medium-cluster"
  }
}

# ------------------------------------------------------------------------------
# USER-ASSIGNED MANAGED IDENTITY
# ------------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "jambonz" {
  name                = "${var.name_prefix}-identity"
  resource_group_name = azurerm_resource_group.jambonz.name
  location            = azurerm_resource_group.jambonz.location

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# Grant Network Contributor role to managed identity for public IP management
# Required for auto-assign-public-ip.azure.sh script to associate static IPs to SBC instances
resource "azurerm_role_assignment" "network_contributor" {
  scope                = azurerm_resource_group.jambonz.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.jambonz.principal_id
}

# Grant Virtual Machine Contributor role to managed identity for VMSS NIC access
# Required for auto-assign-public-ip.azure.sh script to read VM/VMSS instance info
resource "azurerm_role_assignment" "vm_contributor" {
  scope                = azurerm_resource_group.jambonz.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_user_assigned_identity.jambonz.principal_id
}

# ------------------------------------------------------------------------------
# KEY VAULT FOR SECRETS
# ------------------------------------------------------------------------------

resource "azurerm_key_vault" "jambonz" {
  name                        = "${var.name_prefix}-kv"
  location                    = azurerm_resource_group.jambonz.location
  resource_group_name         = azurerm_resource_group.jambonz.name
  enabled_for_deployment      = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"

  access_policy {
    tenant_id = var.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge"
    ]
  }

  access_policy {
    tenant_id = var.tenant_id
    object_id = azurerm_user_assigned_identity.jambonz.principal_id

    secret_permissions = [
      "Get", "List"
    ]
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_key_vault_secret" "encryption_secret" {
  name         = "encryption-secret"
  value        = random_password.encryption_secret.result
  key_vault_id = azurerm_key_vault.jambonz.id
}

# ------------------------------------------------------------------------------
# VIRTUAL NETWORK
# ------------------------------------------------------------------------------

resource "azurerm_virtual_network" "jambonz" {
  name                = "${var.name_prefix}-vnet"
  address_space       = [var.vpc_cidr]
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# Public Subnet 1
resource "azurerm_subnet" "public1" {
  name                 = "${var.name_prefix}-public-subnet-1"
  resource_group_name  = azurerm_resource_group.jambonz.name
  virtual_network_name = azurerm_virtual_network.jambonz.name
  address_prefixes     = [var.public_subnet_cidr]
}

# Public Subnet 2 (in different availability zone)
resource "azurerm_subnet" "public2" {
  name                 = "${var.name_prefix}-public-subnet-2"
  resource_group_name  = azurerm_resource_group.jambonz.name
  virtual_network_name = azurerm_virtual_network.jambonz.name
  address_prefixes     = [var.public_subnet_cidr2]
}

# Delegated subnet for MySQL Flexible Server
resource "azurerm_subnet" "mysql" {
  name                 = "${var.name_prefix}-mysql-subnet"
  resource_group_name  = azurerm_resource_group.jambonz.name
  virtual_network_name = azurerm_virtual_network.jambonz.name
  address_prefixes     = [var.mysql_subnet_cidr]

  delegation {
    name = "mysql-delegation"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# ------------------------------------------------------------------------------
# NETWORK SECURITY GROUPS
# ------------------------------------------------------------------------------

# SSH Security Group
resource "azurerm_network_security_group" "ssh" {
  name                = "${var.name_prefix}-ssh-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

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

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# Redis Security Group
resource "azurerm_network_security_group" "redis" {
  name                = "${var.name_prefix}-redis-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  security_rule {
    name                       = "Redis"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6379"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# MySQL Security Group
resource "azurerm_network_security_group" "mysql" {
  name                = "${var.name_prefix}-mysql-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  security_rule {
    name                       = "MySQL"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# Feature Server Security Group
resource "azurerm_network_security_group" "feature_server" {
  name                = "${var.name_prefix}-feature-server-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP-Internal"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000-3009"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP-External"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3010-3019"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SIP-TCP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SIP-UDP"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RTP"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "25000-40000"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# SBC Security Group
resource "azurerm_network_security_group" "sbc" {
  name                = "${var.name_prefix}-sbc-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP-Internal"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000-3009"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP-External"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3010-3019"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SIP-TCP-TLS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5060-5061"
    source_address_prefix      = var.allowed_sbc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SIP-UDP"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = var.allowed_sbc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SIP-WSS"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix      = var.allowed_sbc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RTP-External"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "40000-60000"
    source_address_prefix      = var.allowed_sbc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RTP-VPC"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "40000-60000"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SIP-UDP-VPC"
    priority                   = 1008
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RTPEngine-NG"
    priority                   = 1009
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "22222-22223"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RTPEngine-WS"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP-Callback"
    priority                   = 1011
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3001"
    source_address_prefix      = var.allowed_http_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Prometheus"
    priority                   = 1012
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DTMF-Events"
    priority                   = 1013
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "22224-22233"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# Web/Monitoring Security Group
resource "azurerm_network_security_group" "web_monitoring" {
  name                = "${var.name_prefix}-web-monitoring-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.allowed_http_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.allowed_http_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "API"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = var.allowed_http_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Upload-Recordings"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3017"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Grafana"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4000"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "InfluxDB"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8086"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "InfluxDB-Backup"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8088"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Homer-Web"
    priority                   = 1008
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9080"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Homer-HEP"
    priority                   = 1009
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "9060"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Jaeger-Query"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "16686"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Jaeger-Collector"
    priority                   = 1011
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "14268-14269"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# Recording ALB Security Group (conditional)
resource "azurerm_network_security_group" "recording_lb" {
  count               = var.deploy_recording_cluster ? 1 : 0
  name                = "${var.name_prefix}-recording-lb-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  security_rule {
    name                       = "HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.allowed_http_cidr
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# Recording Instance Security Group (conditional)
resource "azurerm_network_security_group" "recording_instance" {
  count               = var.deploy_recording_cluster ? 1 : 0
  name                = "${var.name_prefix}-recording-instance-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP-from-LB"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = var.vpc_cidr
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# ------------------------------------------------------------------------------
# PRIVATE DNS ZONE FOR MYSQL
# ------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "mysql" {
  name                = "${var.name_prefix}.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.jambonz.name

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "${var.name_prefix}-mysql-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.jambonz.id
  resource_group_name   = azurerm_resource_group.jambonz.name

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# ------------------------------------------------------------------------------
# AZURE MYSQL FLEXIBLE SERVER
# ------------------------------------------------------------------------------

resource "azurerm_mysql_flexible_server" "jambonz" {
  name                   = "${var.name_prefix}-mysql"
  resource_group_name    = azurerm_resource_group.jambonz.name
  location               = azurerm_resource_group.jambonz.location
  administrator_login    = var.mysql_username
  administrator_password = local.db_password
  backup_retention_days  = 30
  delegated_subnet_id    = azurerm_subnet.mysql.id
  private_dns_zone_id    = azurerm_private_dns_zone.mysql.id
  sku_name               = var.mysql_sku_name
  version                = "8.0.21"
  # zone omitted - let Azure pick an available zone

  storage {
    auto_grow_enabled = true
    size_gb           = 20
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_mysql_flexible_database" "jambonz" {
  name                = "jambones"
  resource_group_name = azurerm_resource_group.jambonz.name
  server_name         = azurerm_mysql_flexible_server.jambonz.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# MySQL server parameters
resource "azurerm_mysql_flexible_server_configuration" "max_connections" {
  name                = "max_connections"
  resource_group_name = azurerm_resource_group.jambonz.name
  server_name         = azurerm_mysql_flexible_server.jambonz.name
  value               = "300"
}

resource "azurerm_mysql_flexible_server_configuration" "require_secure_transport" {
  name                = "require_secure_transport"
  resource_group_name = azurerm_resource_group.jambonz.name
  server_name         = azurerm_mysql_flexible_server.jambonz.name
  value               = "OFF"
}

# ------------------------------------------------------------------------------
# AZURE REDIS CACHE
# ------------------------------------------------------------------------------

resource "azurerm_redis_cache" "jambonz" {
  name                = "${var.name_prefix}-redis"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  capacity            = var.redis_capacity
  family              = var.redis_family
  sku_name            = var.redis_sku_name
  non_ssl_port_enabled = true
  minimum_tls_version = "1.2"

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}
