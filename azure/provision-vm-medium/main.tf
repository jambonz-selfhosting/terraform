# Terraform configuration for jambonz medium cluster deployment on Azure
# Equivalent to the AWS CloudFormation jambonz.yaml deployment

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # 4.55 adds azurerm_log_analytics_workspace_table_custom_log (pm2 log table)
      version = "~> 4.55"
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

  # Spread across availability zones when the region has them (var.zones).
  # Each tier with more than one instance lands in more than one zone.
  zonal    = length(var.zones) > 1
  mysql_ha = local.zonal && var.mysql_high_availability
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

# The identity holds no Azure RBAC roles. Nothing on the VMs calls the Azure
# management API; the identity's only job is reading secrets from Key Vault
# (see the access policy below) and authenticating the Azure Monitor Agent.

# ------------------------------------------------------------------------------
# KEY VAULT FOR SECRETS
# ------------------------------------------------------------------------------

resource "azurerm_key_vault" "jambonz" {
  name                       = "${var.name_prefix}-kv"
  location                   = azurerm_resource_group.jambonz.location
  resource_group_name        = azurerm_resource_group.jambonz.name
  enabled_for_deployment     = true
  tenant_id                  = var.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  sku_name                   = "standard"

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

    # Read named secrets only. Boot scripts fetch each secret by name, so the
    # VMs never need to enumerate the vault.
    secret_permissions = [
      "Get"
    ]
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# Every secret the VMs need lives here. cloud-init fetches them at boot with the
# VM's managed identity, so none is written into custom_data (which Azure keeps
# with the VM model and anyone with read access to the VM can see).
resource "azurerm_key_vault_secret" "encryption_secret" {
  name         = "encryption-secret"
  value        = random_password.encryption_secret.result
  key_vault_id = azurerm_key_vault.jambonz.id
}

resource "azurerm_key_vault_secret" "mysql_password" {
  name         = "mysql-password"
  value        = local.db_password
  key_vault_id = azurerm_key_vault.jambonz.id
}

resource "azurerm_key_vault_secret" "redis_password" {
  name         = "redis-password"
  value        = azurerm_managed_redis.jambonz.default_database[0].primary_access_key
  key_vault_id = azurerm_key_vault.jambonz.id
}

resource "azurerm_key_vault_secret" "apiban_key" {
  count        = var.apiban_key != "" ? 1 : 0
  name         = "apiban-key"
  value        = var.apiban_key
  key_vault_id = azurerm_key_vault.jambonz.id
}

resource "azurerm_key_vault_secret" "apiban_client_secret" {
  count        = var.apiban_client_secret != "" ? 1 : 0
  name         = "apiban-client-secret"
  value        = var.apiban_client_secret
  key_vault_id = azurerm_key_vault.jambonz.id
}

resource "azurerm_key_vault_secret" "krisp_license_key" {
  count        = var.krisp_license_key != "" ? 1 : 0
  name         = "krisp-license-key"
  value        = var.krisp_license_key
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

# Public Subnet 2 (recording servers, behind the NAT gateway). Azure subnets
# span every zone in the region, so subnets are not what makes the deployment
# zone-redundant; the zones on each VM, scale set and public IP do that.
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
# NAT GATEWAY (for outbound internet access from private instances)
# ------------------------------------------------------------------------------

resource "azurerm_public_ip" "nat" {
  name                = "${var.name_prefix}-nat-pip"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_nat_gateway" "jambonz" {
  name                    = "${var.name_prefix}-nat-gateway"
  location                = azurerm_resource_group.jambonz.location
  resource_group_name     = azurerm_resource_group.jambonz.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_nat_gateway_public_ip_association" "jambonz" {
  nat_gateway_id       = azurerm_nat_gateway.jambonz.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

# Only associate NAT Gateway with subnet2 (for recording servers without public IPs)
# Subnet1 has Feature Server VMSS with public IPs which are incompatible with NAT Gateway
resource "azurerm_subnet_nat_gateway_association" "public2" {
  subnet_id      = azurerm_subnet.public2.id
  nat_gateway_id = azurerm_nat_gateway.jambonz.id
}

# ------------------------------------------------------------------------------
# NETWORK SECURITY GROUPS
#
# One NSG per role, each listing exactly the ports that role serves (taken from
# the AWS large template's security groups, which have no implicit allows).
#
# Azure's built-in AllowVnetInBound rule (priority 65000) admits ALL traffic
# from anywhere in the VNet. Every NSG therefore ends with an explicit deny of
# other VNet traffic at priority 4000; without it the VNet-only rules would be
# decorative and any compromised VM could reach every port on every other VM.
# Azure load balancer health probes come from the AzureLoadBalancer service
# tag, not the VNet, so the default AllowAzureLoadBalancerInBound rule still
# applies.
# ------------------------------------------------------------------------------

locals {
  deny_vnet_rule = {
    name     = "Deny-VNet-Other"
    priority = 4000
    access   = "Deny"
    protocol = "*"
    ports    = "*"
    source   = "VirtualNetwork"
  }

  ssh_rule = { name = "SSH", priority = 1000, access = "Allow", protocol = "Tcp", ports = "22", source = var.allowed_ssh_cidr }

  nsg_rules = {
    feature_server = [
      local.ssh_rule,
      { name = "HTTP-Internal", priority = 1001, access = "Allow", protocol = "Tcp", ports = "3000-3009", source = var.vpc_cidr },
      { name = "SIP-TCP", priority = 1002, access = "Allow", protocol = "Tcp", ports = "5060", source = var.vpc_cidr },
      { name = "SIP-UDP", priority = 1003, access = "Allow", protocol = "Udp", ports = "5060", source = var.vpc_cidr },
      { name = "RTP-mediajam", priority = 1004, access = "Allow", protocol = "Udp", ports = "16000-32000", source = var.vpc_cidr },
    ]

    # SIP signaling and rtpengine media on one host
    sbc = [
      local.ssh_rule,
      { name = "HTTP-Internal", priority = 1001, access = "Allow", protocol = "Tcp", ports = "3000-3009", source = var.vpc_cidr },
      { name = "SIP-TCP-TLS", priority = 1002, access = "Allow", protocol = "Tcp", ports = "5060-5061", source = var.allowed_sbc_cidr },
      { name = "SIP-UDP", priority = 1003, access = "Allow", protocol = "Udp", ports = "5060", source = var.allowed_sbc_cidr },
      { name = "SIP-WSS", priority = 1004, access = "Allow", protocol = "Tcp", ports = "8443", source = var.allowed_sbc_cidr },
      { name = "RTP-External", priority = 1005, access = "Allow", protocol = "Udp", ports = "40000-60000", source = var.allowed_sbc_cidr },
      { name = "RTP-VNet", priority = 1006, access = "Allow", protocol = "Udp", ports = "40000-60000", source = var.vpc_cidr },
      # Feature servers reach the SBC on 5060 even when allowed_sbc_cidr is
      # narrowed to carrier addresses.
      { name = "SIP-TCP-VNet", priority = 1007, access = "Allow", protocol = "Tcp", ports = "5060", source = var.vpc_cidr },
      { name = "SIP-UDP-VNet", priority = 1008, access = "Allow", protocol = "Udp", ports = "5060", source = var.vpc_cidr },
      { name = "RTPEngine-NG", priority = 1009, access = "Allow", protocol = "Udp", ports = "22222-22223", source = var.vpc_cidr },
      { name = "DTMF-Events", priority = 1010, access = "Allow", protocol = "Udp", ports = "22224-22233", source = var.vpc_cidr },
      { name = "RTPEngine-WS", priority = 1011, access = "Allow", protocol = "Tcp", ports = "8080", source = var.vpc_cidr },
      { name = "Prometheus", priority = 1012, access = "Allow", protocol = "Tcp", ports = "9090", source = var.vpc_cidr },
    ]

    # Portal/API and monitoring on one host. Grafana is reached through nginx on
    # this host, so it needs no rule of its own.
    web_monitoring = concat([
      local.ssh_rule,
      { name = "HTTP", priority = 1001, access = "Allow", protocol = "Tcp", ports = "80", source = var.allowed_http_cidr },
      { name = "HTTPS", priority = 1002, access = "Allow", protocol = "Tcp", ports = "443", source = var.allowed_http_cidr },
      # The API is reached publicly through nginx on 80/443; port 3000 is only
      # for feature servers inside the VNet.
      { name = "API-Internal", priority = 1003, access = "Allow", protocol = "Tcp", ports = "3000", source = var.vpc_cidr },
      { name = "InfluxDB", priority = 1004, access = "Allow", protocol = "Tcp", ports = "8086", source = var.vpc_cidr },
      { name = "InfluxDB-Backup", priority = 1005, access = "Allow", protocol = "Tcp", ports = "8088", source = var.vpc_cidr },
      { name = "Homer-Web", priority = 1006, access = "Allow", protocol = "Tcp", ports = "9080", source = var.vpc_cidr },
      { name = "Homer-HEP", priority = 1007, access = "Allow", protocol = "Udp", ports = "9060", source = var.vpc_cidr },
      { name = "Jaeger-Query", priority = 1008, access = "Allow", protocol = "Tcp", ports = "16686", source = var.vpc_cidr },
      { name = "Jaeger-Collector", priority = 1009, access = "Allow", protocol = "Tcp", ports = "14268-14269", source = var.vpc_cidr },
      ], var.deploy_recording_cluster ? [] : [
      { name = "Upload-Recordings", priority = 1010, access = "Allow", protocol = "Tcp", ports = "3017", source = var.vpc_cidr },
    ])

    recording = [
      local.ssh_rule,
      # Standard load balancers keep the client address, so traffic arrives
      # from the feature servers' VNet addresses.
      { name = "HTTP-from-VNet", priority = 1001, access = "Allow", protocol = "Tcp", ports = "3000", source = var.vpc_cidr },
      { name = "HTTP-LB-Probe", priority = 1002, access = "Allow", protocol = "Tcp", ports = "3000", source = "AzureLoadBalancer" },
    ]
  }
}

resource "azurerm_network_security_group" "feature_server" {
  name                = "${var.name_prefix}-feature-server-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  dynamic "security_rule" {
    for_each = concat(local.nsg_rules.feature_server, [local.deny_vnet_rule])
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_range     = security_rule.value.ports
      source_address_prefix      = security_rule.value.source
      destination_address_prefix = "*"
    }
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_network_security_group" "sbc" {
  name                = "${var.name_prefix}-sbc-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  dynamic "security_rule" {
    for_each = concat(local.nsg_rules.sbc, [local.deny_vnet_rule])
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_range     = security_rule.value.ports
      source_address_prefix      = security_rule.value.source
      destination_address_prefix = "*"
    }
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_network_security_group" "web_monitoring" {
  name                = "${var.name_prefix}-web-monitoring-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  dynamic "security_rule" {
    for_each = concat(local.nsg_rules.web_monitoring, [local.deny_vnet_rule])
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_range     = security_rule.value.ports
      source_address_prefix      = security_rule.value.source
      destination_address_prefix = "*"
    }
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_network_security_group" "recording_instance" {
  count               = var.deploy_recording_cluster ? 1 : 0
  name                = "${var.name_prefix}-recording-instance-nsg"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  dynamic "security_rule" {
    for_each = concat(local.nsg_rules.recording, [local.deny_vnet_rule])
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_range     = security_rule.value.ports
      source_address_prefix      = security_rule.value.source
      destination_address_prefix = "*"
    }
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
#
# Encrypted at rest by Azure (always on for Flexible Server), 30 days of
# backups, a zone-redundant standby, connection auditing to Log Analytics, and
# a delete lock.
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
  zone                   = local.zonal ? var.zones[0] : null

  dynamic "high_availability" {
    for_each = local.mysql_ha ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.zones[1]
    }
  }

  storage {
    auto_grow_enabled = true
    size_gb           = 20
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]

  lifecycle {
    # A failover swaps the primary and standby zones; don't fight it.
    ignore_changes = [zone, high_availability[0].standby_availability_zone]

    precondition {
      condition     = !local.mysql_ha || !startswith(var.mysql_sku_name, "B_")
      error_message = "Zone-redundant MySQL needs a General Purpose or Business Critical SKU (e.g. GP_Standard_D2ds_v4); Burstable (B_) SKUs don't support high availability. Set mysql_high_availability = false to keep a Burstable SKU."
    }
  }

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

# MySQL server parameters. Flexible Server applies configuration changes one at
# a time, so each waits for the previous one.
resource "azurerm_mysql_flexible_server_configuration" "max_connections" {
  name                = "max_connections"
  resource_group_name = azurerm_resource_group.jambonz.name
  server_name         = azurerm_mysql_flexible_server.jambonz.name
  value               = "300"
}

# TODO(soc2): turn this ON once drachtio and upload-recordings are confirmed to
# connect over TLS. The Node apps can (JAMBONES_MYSQL_REJECT_UNAUTHORIZED=1);
# the C++ components are untested. Traffic stays on the private delegated subnet.
resource "azurerm_mysql_flexible_server_configuration" "require_secure_transport" {
  name                = "require_secure_transport"
  resource_group_name = azurerm_resource_group.jambonz.name
  server_name         = azurerm_mysql_flexible_server.jambonz.name
  value               = "OFF"

  depends_on = [azurerm_mysql_flexible_server_configuration.max_connections]
}

# Log every connection (logins, logouts, failed logins) to the audit log, which
# the diagnostic setting in logging.tf sends to Log Analytics.
resource "azurerm_mysql_flexible_server_configuration" "audit_log_enabled" {
  name                = "audit_log_enabled"
  resource_group_name = azurerm_resource_group.jambonz.name
  server_name         = azurerm_mysql_flexible_server.jambonz.name
  value               = "ON"

  depends_on = [azurerm_mysql_flexible_server_configuration.require_secure_transport]
}

resource "azurerm_mysql_flexible_server_configuration" "audit_log_events" {
  name                = "audit_log_events"
  resource_group_name = azurerm_resource_group.jambonz.name
  server_name         = azurerm_mysql_flexible_server.jambonz.name
  value               = "CONNECTION"

  depends_on = [azurerm_mysql_flexible_server_configuration.audit_log_enabled]
}

# Azure's equivalent of deletion protection: the server can't be deleted from
# the portal, the CLI or by deleting the resource group while this exists.
#
# The lock also covers everything under the server (its database, settings
# and diagnostic setting), so it must be created after them and destroyed
# before them -- hence the depends_on. Without it terraform destroy deletes
# them in parallel with the lock and Azure refuses with ScopeLocked.
resource "azurerm_management_lock" "mysql" {
  count      = var.mysql_delete_lock ? 1 : 0
  name       = "${var.name_prefix}-mysql-no-delete"
  scope      = azurerm_mysql_flexible_server.jambonz.id
  lock_level = "CanNotDelete"
  notes      = "jambonz database. Remove this lock deliberately before deleting the server."

  depends_on = [
    azurerm_mysql_flexible_database.jambonz,
    azurerm_mysql_flexible_server_configuration.max_connections,
    azurerm_mysql_flexible_server_configuration.require_secure_transport,
    azurerm_mysql_flexible_server_configuration.audit_log_enabled,
    azurerm_mysql_flexible_server_configuration.audit_log_events,
    azurerm_monitor_diagnostic_setting.mysql,
  ]
}

# ------------------------------------------------------------------------------
# AZURE MANAGED REDIS
#
# Reachable only through a private endpoint in the VNet; public network access
# is off. TLS (port 10000) and access-key auth as before. High availability
# (a replica in another zone where the region has zones) is on by default.
# ------------------------------------------------------------------------------

resource "azurerm_managed_redis" "jambonz" {
  name                      = "${var.name_prefix}-redis"
  location                  = azurerm_resource_group.jambonz.location
  resource_group_name       = azurerm_resource_group.jambonz.name
  sku_name                  = var.redis_sku_name
  high_availability_enabled = true
  public_network_access     = "Disabled"

  default_database {
    access_keys_authentication_enabled = true
    clustering_policy                  = "NoCluster"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.azure.net"
  resource_group_name = azurerm_resource_group.jambonz.name

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "${var.name_prefix}-redis-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = azurerm_virtual_network.jambonz.id
  resource_group_name   = azurerm_resource_group.jambonz.name

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_private_endpoint" "redis" {
  name                = "${var.name_prefix}-redis-pe"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  subnet_id           = azurerm_subnet.public1.id

  private_service_connection {
    name                           = "${var.name_prefix}-redis-psc"
    private_connection_resource_id = azurerm_managed_redis.jambonz.id
    subresource_names              = ["redisEnterprise"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "redis"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}
