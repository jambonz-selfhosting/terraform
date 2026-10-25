# Centralized logs with enforced retention: the Azure equivalent of the AWS
# templates' CloudWatch logging.
#
# - A Log Analytics workspace keeps everything for var.log_retention_days.
# - The Azure Monitor Agent on every VM and scale set sends syslog (including
#   auth, so SSH logins are recorded) and the jambonz application logs.
# - The MySQL audit log (connections, failed logins) goes to the same place.
#
# First boot of a new host: the agent is a VM extension, installed after the OS
# boots and the jambonz apps start, so roughly the first minute of each new
# host's logs is not collected. On the scale sets the rule is attached after
# the scale set is created, so the first instances of a new deployment wait a
# few minutes longer. Baking the agent into the image would not change either:
# it authenticates (user-assigned identity) and fetches its rule only when the
# extension's enable step runs, and Microsoft does not support cloning a
# machine with the agent installed.

locals {
  # The agent authenticates with the deployment's user-assigned identity.
  ama_settings = {
    authentication = {
      managedIdentity = {
        identifier-name  = "mi_res_id"
        identifier-value = azurerm_user_assigned_identity.jambonz.id
      }
    }
  }

  # Standalone VMs get the agent as a separate extension resource; the scale
  # sets carry it inline (compute.tf).
  logged_vms = merge(
    {
      web        = azurerm_linux_virtual_machine.web.id
      monitoring = azurerm_linux_virtual_machine.monitoring.id
    },
    { for i, vm in azurerm_linux_virtual_machine.sip : "sip-${i}" => vm.id },
    { for i, vm in azurerm_linux_virtual_machine.rtp : "rtp-${i}" => vm.id },
  )

  logged_scale_sets = merge(
    { feature-server = azurerm_linux_virtual_machine_scale_set.feature_server.id },
    { for vmss in azurerm_linux_virtual_machine_scale_set.recording : "recording" => vmss.id },
  )

  app_log_table = "JambonzApp_CL"
}

resource "azurerm_log_analytics_workspace" "jambonz" {
  name                = "${var.name_prefix}-logs"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# One table for every jambonz application log line, tagged with the host and
# the file it came from.
resource "azurerm_log_analytics_workspace_table_custom_log" "jambonz_app" {
  name                    = local.app_log_table
  workspace_id            = azurerm_log_analytics_workspace.jambonz.id
  retention_in_days       = var.log_retention_days
  total_retention_in_days = var.log_retention_days

  column {
    name = "TimeGenerated"
    type = "dateTime"
  }
  column {
    name = "RawData"
    type = "string"
  }
  column {
    name = "Computer"
    type = "string"
  }
  column {
    name = "FilePath"
    type = "string"
  }
}

resource "azurerm_monitor_data_collection_rule" "jambonz" {
  name                = "${var.name_prefix}-dcr"
  location            = azurerm_resource_group.jambonz.location
  resource_group_name = azurerm_resource_group.jambonz.name
  kind                = "Linux"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.jambonz.id
      name                  = "workspace"
    }
  }

  data_sources {
    syslog {
      name           = "syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "cron", "daemon", "kern", "syslog", "user"]
      log_levels     = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
    }

    # The same files the AWS CloudWatch agent collects, one record per line.
    log_file {
      name    = "jambonz-app-logs"
      format  = "text"
      streams = ["Custom-${local.app_log_table}"]
      file_patterns = [
        "/home/jambonz/.pm2/logs/*.log",
        "/var/log/mediajam/*.log",
        "/var/log/upload_recordings*.log",
      ]
    }
  }

  stream_declaration {
    stream_name = "Custom-${local.app_log_table}"
    column {
      name = "TimeGenerated"
      type = "datetime"
    }
    column {
      name = "RawData"
      type = "string"
    }
    column {
      name = "Computer"
      type = "string"
    }
    column {
      name = "FilePath"
      type = "string"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["workspace"]
  }

  data_flow {
    streams       = ["Custom-${local.app_log_table}"]
    destinations  = ["workspace"]
    output_stream = "Custom-${local.app_log_table}"
    transform_kql = "source"
  }

  depends_on = [azurerm_log_analytics_workspace_table_custom_log.jambonz_app]

  tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "azurerm_virtual_machine_extension" "ama" {
  for_each                   = local.logged_vms
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = each.value
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  settings                   = jsonencode(local.ama_settings)

  # Install the agent after the rule is attached, so its first config fetch
  # already includes the rule. Otherwise it picks the rule up minutes later and
  # misses everything logged before then.
  depends_on = [azurerm_monitor_data_collection_rule_association.vm]
}

resource "azurerm_monitor_data_collection_rule_association" "vm" {
  for_each                = local.logged_vms
  name                    = "${var.name_prefix}-dcra-${each.key}"
  target_resource_id      = each.value
  data_collection_rule_id = azurerm_monitor_data_collection_rule.jambonz.id
}

resource "azurerm_monitor_data_collection_rule_association" "scale_set" {
  for_each                = local.logged_scale_sets
  name                    = "${var.name_prefix}-dcra-${each.key}"
  target_resource_id      = each.value
  data_collection_rule_id = azurerm_monitor_data_collection_rule.jambonz.id
}

resource "azurerm_monitor_diagnostic_setting" "mysql" {
  name                       = "${var.name_prefix}-mysql-audit"
  target_resource_id         = azurerm_mysql_flexible_server.jambonz.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.jambonz.id

  enabled_log {
    category = "MySqlAuditLogs"
  }
}
