variable "automation_account_name" {
  default = "default"
}

data "azurerm_resource_graph" "vms" {
  subscription_id = azurerm_client_config.current.subscription_id
  filter = <<EOF
    resources | where type == 'microsoft.compute/virtualmachinescalesets' && resourceGroup == '${azurerm_resource_group.aks_rg.name}'
EOF
}

resource "azurerm_automation_schedule" "nightly_shutdown" {
  name                 = "aks-nightly-shutdown"
  resource_group_name = azurerm_resource_group.aks_rg.name
  automation_account_name = var.automation_account_name

  frequency = "Daily"
  start_time = "17:00:00" # UTC Time
}

resource "azurerm_automation_runbook" "stop_vms" {
  name                 = "stop-aks-vms"
  location             = azurerm_resource_group.automation_account_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  automation_account_name = var.automation_account_name

  draft {
    name      = "stop-aks-vms"
    # reference to your existing stop VM runbook
    runbook_type = "AzurePublished"
    # update with the appropriate runbook name
    runbook_id   = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Automation/automationAccounts/.../runbooks/stop-vms"
  }

  # Schedule reference
  schedule_id = azurerm_automation_schedule.nightly_shutdown.id
}

resource "azurerm_automation_schedule" "friday_delete" {
  name                 = "aks-resource-group-delete"
  resource_group_name = azurerm_resource_group.aks_rg.name
  automation_account_name = var.automation_account_name

  frequency = "Week"
  interval = 1

  # Friday at 6:00 PM UTC
  friday_at = "18:00:00"

  enabled = true
}