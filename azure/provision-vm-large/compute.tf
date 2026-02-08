# Compute resources for jambonz large cluster on Azure
# Web VM, Monitoring VM, SIP VMs, RTP VMs, Feature Server VMSS, Recording VMSS
# Image IDs are defined in images.tf
#
# Large deployment separates:
# - Web (portal/API) from Monitoring (Grafana/Homer/Jaeger)
# - SIP (drachtio signaling) from RTP (rtpengine media)

# ------------------------------------------------------------------------------
# WEB SERVER (Portal/API only)
# ------------------------------------------------------------------------------

# Public IP for Web Server
resource "azurerm_public_ip" "web" {
  name                = "${var.name_prefix}-web-pip"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "web"
  }
}

# Network Interface for Web Server
resource "azurerm_network_interface" "web" {
  name                = "${var.name_prefix}-web-nic"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "web"
  }
}

# NSG association for Web NIC
resource "azurerm_network_interface_security_group_association" "web" {
  network_interface_id      = azurerm_network_interface.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

# Web Server VM
resource "azurerm_linux_virtual_machine" "web" {
  name                = "${var.name_prefix}-web"
  resource_group_name = azurerm_resource_group.jambonz.name
  location            = azurerm_resource_group.jambonz.location
  size                = var.web_vm_size
  admin_username      = "jambonz"

  network_interface_ids = [
    azurerm_network_interface.web.id,
  ]

  admin_ssh_key {
    username   = "jambonz"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.web_disk_size
  }

  source_image_id = local.web_image_id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jambonz.id]
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-web.yaml", {
    mysql_host               = azurerm_mysql_flexible_server.jambonz.fqdn
    mysql_user               = var.mysql_username
    mysql_password           = local.db_password
    redis_host               = azurerm_redis_cache.jambonz.hostname
    redis_port               = azurerm_redis_cache.jambonz.port
    redis_password           = azurerm_redis_cache.jambonz.primary_access_key
    jwt_secret               = random_password.encryption_secret.result
    url_portal               = var.url_portal
    vpc_cidr                 = var.vpc_cidr
    deploy_recording_cluster = var.deploy_recording_cluster
    key_vault_name           = azurerm_key_vault.jambonz.name
    monitoring_private_ip    = azurerm_network_interface.monitoring.private_ip_address
  }))

  depends_on = [
    azurerm_mysql_flexible_server.jambonz,
    azurerm_redis_cache.jambonz
  ]

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "web"
  }
}

# ------------------------------------------------------------------------------
# MONITORING SERVER (Grafana/Homer/Jaeger)
# ------------------------------------------------------------------------------

# Public IP for Monitoring Server
resource "azurerm_public_ip" "monitoring" {
  name                = "${var.name_prefix}-monitoring-pip"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "monitoring"
  }
}

# Network Interface for Monitoring Server
resource "azurerm_network_interface" "monitoring" {
  name                = "${var.name_prefix}-monitoring-nic"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.monitoring.id
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "monitoring"
  }
}

# NSG association for Monitoring NIC
resource "azurerm_network_interface_security_group_association" "monitoring" {
  network_interface_id      = azurerm_network_interface.monitoring.id
  network_security_group_id = azurerm_network_security_group.monitoring.id
}

# Monitoring Server VM
resource "azurerm_linux_virtual_machine" "monitoring" {
  name                = "${var.name_prefix}-monitoring"
  resource_group_name = azurerm_resource_group.jambonz.name
  location            = azurerm_resource_group.jambonz.location
  size                = var.monitoring_vm_size
  admin_username      = "jambonz"

  network_interface_ids = [
    azurerm_network_interface.monitoring.id,
  ]

  admin_ssh_key {
    username   = "jambonz"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.monitoring_disk_size
  }

  source_image_id = local.monitoring_image_id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jambonz.id]
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-monitoring.yaml", {
    mysql_host     = azurerm_mysql_flexible_server.jambonz.fqdn
    mysql_user     = var.mysql_username
    mysql_password = local.db_password
    jwt_secret     = random_password.encryption_secret.result
    vpc_cidr       = var.vpc_cidr
    key_vault_name = azurerm_key_vault.jambonz.name
  }))

  depends_on = [
    azurerm_mysql_flexible_server.jambonz,
    azurerm_redis_cache.jambonz
  ]

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "monitoring"
  }
}

# ------------------------------------------------------------------------------
# RTP SERVERS (rtpengine media only)
# Must be created before SIP servers so SIP can get RTP IPs
# ------------------------------------------------------------------------------

# Static public IPs for RTP instances (one per instance)
resource "azurerm_public_ip" "rtp" {
  count               = var.rtp_count
  name                = "${var.name_prefix}-rtp-pip-${count.index}"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "rtp"
  }
}

# Network Interface for RTP instances
resource "azurerm_network_interface" "rtp" {
  count               = var.rtp_count
  name                = "${var.name_prefix}-rtp-nic-${count.index}"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.rtp[count.index].id
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "rtp"
  }
}

# NSG association for RTP NICs
resource "azurerm_network_interface_security_group_association" "rtp" {
  count                     = var.rtp_count
  network_interface_id      = azurerm_network_interface.rtp[count.index].id
  network_security_group_id = azurerm_network_security_group.rtp.id
}

# RTP Server Virtual Machines
resource "azurerm_linux_virtual_machine" "rtp" {
  count               = var.rtp_count
  name                = "${var.name_prefix}-rtp-${count.index}"
  resource_group_name = azurerm_resource_group.jambonz.name
  location            = azurerm_resource_group.jambonz.location
  size                = var.rtp_vm_size
  admin_username      = "jambonz"

  network_interface_ids = [
    azurerm_network_interface.rtp[count.index].id,
  ]

  admin_ssh_key {
    username   = "jambonz"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.rtp_disk_size
  }

  source_image_id = local.rtp_image_id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jambonz.id]
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-rtp.yaml", {
    monitoring_private_ip = azurerm_network_interface.monitoring.private_ip_address
    vpc_cidr              = var.vpc_cidr
    key_vault_name        = azurerm_key_vault.jambonz.name
  }))

  depends_on = [
    azurerm_linux_virtual_machine.monitoring
  ]

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "rtp"
  }
}

# ------------------------------------------------------------------------------
# SIP SERVERS (drachtio signaling only)
# Depends on RTP servers to get their IPs for rtpengine connection
# ------------------------------------------------------------------------------

# Static public IPs for SIP instances (one per instance)
resource "azurerm_public_ip" "sip" {
  count               = var.sip_count
  name                = "${var.name_prefix}-sip-pip-${count.index}"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "sip"
  }
}

# Network Interface for SIP instances
resource "azurerm_network_interface" "sip" {
  count               = var.sip_count
  name                = "${var.name_prefix}-sip-nic-${count.index}"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.sip[count.index].id
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "sip"
  }
}

# NSG association for SIP NICs
resource "azurerm_network_interface_security_group_association" "sip" {
  count                     = var.sip_count
  network_interface_id      = azurerm_network_interface.sip[count.index].id
  network_security_group_id = azurerm_network_security_group.sip.id
}

# SIP Server Virtual Machines
resource "azurerm_linux_virtual_machine" "sip" {
  count               = var.sip_count
  name                = "${var.name_prefix}-sip-${count.index}"
  resource_group_name = azurerm_resource_group.jambonz.name
  location            = azurerm_resource_group.jambonz.location
  size                = var.sip_vm_size
  admin_username      = "jambonz"

  network_interface_ids = [
    azurerm_network_interface.sip[count.index].id,
  ]

  admin_ssh_key {
    username   = "jambonz"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.sip_disk_size
  }

  source_image_id = local.sip_image_id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jambonz.id]
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-sip.yaml", {
    mysql_host            = azurerm_mysql_flexible_server.jambonz.fqdn
    mysql_user            = var.mysql_username
    mysql_password        = local.db_password
    redis_host            = azurerm_redis_cache.jambonz.hostname
    redis_port            = azurerm_redis_cache.jambonz.port
    redis_password        = azurerm_redis_cache.jambonz.primary_access_key
    jwt_secret            = random_password.encryption_secret.result
    monitoring_private_ip = azurerm_network_interface.monitoring.private_ip_address
    rtp_private_ips       = join(",", azurerm_network_interface.rtp[*].private_ip_address)
    vpc_cidr              = var.vpc_cidr
    enable_pcaps          = var.enable_pcaps
    key_vault_name        = azurerm_key_vault.jambonz.name
    apiban_key            = var.apiban_key
    apiban_client_id      = var.apiban_client_id
    apiban_client_secret  = var.apiban_client_secret
  }))

  depends_on = [
    azurerm_linux_virtual_machine.monitoring,
    azurerm_linux_virtual_machine.rtp
  ]

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "sip"
  }
}

# ------------------------------------------------------------------------------
# FEATURE SERVER VIRTUAL MACHINE SCALE SET
# ------------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine_scale_set" "feature_server" {
  name                = "${var.name_prefix}-fs-vmss"
  resource_group_name = azurerm_resource_group.jambonz.name
  location            = azurerm_resource_group.jambonz.location
  sku                 = var.feature_server_vm_size
  instances           = var.feature_server_desired_capacity
  admin_username      = "jambonz"
  upgrade_mode        = "Manual"

  admin_ssh_key {
    username   = "jambonz"
    public_key = var.ssh_public_key
  }

  source_image_id = local.feature_server_image_id

  os_disk {
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
    disk_size_gb         = var.feature_server_disk_size
  }

  network_interface {
    name    = "fs-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.public1.id
      public_ip_address {
        name = "fs-pip"
      }
    }

    network_security_group_id = azurerm_network_security_group.feature_server.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jambonz.id]
  }

  # 15-minute termination notification for graceful scale-in
  termination_notification {
    enabled = true
    timeout = "PT15M"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-feature-server.yaml", {
    mysql_host            = azurerm_mysql_flexible_server.jambonz.fqdn
    mysql_user            = var.mysql_username
    mysql_password        = local.db_password
    redis_host            = azurerm_redis_cache.jambonz.hostname
    redis_port            = azurerm_redis_cache.jambonz.port
    redis_password        = azurerm_redis_cache.jambonz.primary_access_key
    jwt_secret            = random_password.encryption_secret.result
    monitoring_private_ip = azurerm_network_interface.monitoring.private_ip_address
    vpc_cidr              = var.vpc_cidr
    url_portal            = var.url_portal
    key_vault_name        = azurerm_key_vault.jambonz.name
    recording_ws_base_url = var.deploy_recording_cluster ? "ws://${azurerm_lb.recording[0].private_ip_address}" : "ws://${azurerm_network_interface.web.private_ip_address}:3017"
  }))

  depends_on = [
    azurerm_linux_virtual_machine.monitoring
  ]

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "feature-server"
  }
}

# ------------------------------------------------------------------------------
# RECORDING SERVER CLUSTER (CONDITIONAL)
# ------------------------------------------------------------------------------

# Internal Load Balancer for Recording Servers
resource "azurerm_lb" "recording" {
  count               = var.deploy_recording_cluster ? 1 : 0
  name                = "${var.name_prefix}-recording-lb"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "RecordingFrontend"
    subnet_id                     = azurerm_subnet.public1.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "recording"
  }
}

resource "azurerm_lb_backend_address_pool" "recording" {
  count           = var.deploy_recording_cluster ? 1 : 0
  loadbalancer_id = azurerm_lb.recording[0].id
  name            = "RecordingBackendPool"
}

resource "azurerm_lb_probe" "recording" {
  count               = var.deploy_recording_cluster ? 1 : 0
  loadbalancer_id     = azurerm_lb.recording[0].id
  name                = "recording-health-probe"
  protocol            = "Http"
  port                = 3000
  request_path        = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "recording" {
  count                          = var.deploy_recording_cluster ? 1 : 0
  loadbalancer_id                = azurerm_lb.recording[0].id
  name                           = "RecordingRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 3000
  frontend_ip_configuration_name = "RecordingFrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.recording[0].id]
  probe_id                       = azurerm_lb_probe.recording[0].id
  idle_timeout_in_minutes        = 30
  enable_tcp_reset               = true
}

resource "azurerm_linux_virtual_machine_scale_set" "recording" {
  count               = var.deploy_recording_cluster ? 1 : 0
  name                = "${var.name_prefix}-recording-vmss"
  resource_group_name = azurerm_resource_group.jambonz.name
  location            = azurerm_resource_group.jambonz.location
  sku                 = var.recording_vm_size
  instances           = var.recording_desired_capacity
  admin_username      = "jambonz"
  upgrade_mode        = "Manual"

  admin_ssh_key {
    username   = "jambonz"
    public_key = var.ssh_public_key
  }

  source_image_id = local.recording_image_id

  os_disk {
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
    disk_size_gb         = var.recording_disk_size
  }

  network_interface {
    name    = "recording-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.public1.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.recording[0].id]
    }

    network_security_group_id = azurerm_network_security_group.recording_instance[0].id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jambonz.id]
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-recording.yaml", {
    mysql_host            = azurerm_mysql_flexible_server.jambonz.fqdn
    mysql_user            = var.mysql_username
    mysql_password        = local.db_password
    jwt_secret            = random_password.encryption_secret.result
    monitoring_private_ip = azurerm_network_interface.monitoring.private_ip_address
    key_vault_name        = azurerm_key_vault.jambonz.name
  }))

  depends_on = [
    azurerm_linux_virtual_machine.monitoring,
    azurerm_lb_rule.recording
  ]

  tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "recording"
  }
}
