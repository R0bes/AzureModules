

#################
#    Locals     #
#################

locals {
  external_storage = var.storage_name != ""
  storage_name = local.external_storage ? var.storage_name : "${var.prefix}tsistg"
}


#################
#     Data      #
#################

data "azurerm_client_config" "current" {}


#################
#   Resources   #
#################

# TSI Storage Account
resource "azurerm_storage_account" "tsi" {
  count                     = local.external_storage ? 0 : 1
  name                      = local.storage_name
  resource_group_name       = var.resourcegroup_name
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "GRS"
}


resource "azurerm_iothub_consumer_group" "tsi" {
  name                   = "${var.prefix}tsicg"
  iothub_name            = var.iothub_name
  eventhub_endpoint_name = var.iothub_endpoint
  resource_group_name    = var.resourcegroup_name
}


resource "azurerm_iot_time_series_insights_gen2_environment" "tsi" {
  name                            = "${var.prefix}tsienv"
  location                        = var.location
  resource_group_name             = var.resourcegroup_name
  sku_name                        = "L1"
  warm_store_data_retention_time  = "P7D"  
  id_properties                   = ["iothub-connection-device-id"]

  storage {
    name = local.storage_name
    key  = local.external_storage ? var.storage_key : azurerm_storage_account.tsi[0].primary_access_key
  }
    
  provisioner "local-exec" {
      when        = create
      interpreter = ["pwsh", "-Command"]
      command     = <<SCRIPT
        az tsi event-source iothub create `
          --consumer-group-name ${azurerm_iothub_consumer_group.tsi.name} `
          --environment-name ${azurerm_iot_time_series_insights_gen2_environment.tsi.name} `
          --name iot-hub-source-1 --resource-id ${var.iothub_id} `
          --location ${var.location} `
          --iot-hub-name ${var.iothub_name} `
          --key-name iothubowner `
          --resource-group ${var.resourcegroup_name} `
          --shared-access-key ${var.iothub_key}
      SCRIPT
  }
}


resource "azurerm_iot_time_series_insights_access_policy" "custom_ap" {
  count                                 = length(var.principal_object_ids)
  name                                  = var.principal_object_ids[count.index].name
  principal_object_id                   = var.principal_object_ids[count.index].id
  time_series_insights_environment_id   = azurerm_iot_time_series_insights_gen2_environment.tsi.id
  roles                                 = ["Contributor", "Reader"]
}


resource "azurerm_iot_time_series_insights_access_policy" "default_ap" {
  count                                 = length(var.principal_object_ids) == 0 ? 1 : 0
  name                                  = "tsi"
  principal_object_id                   = data.azurerm_client_config.current.object_id
  time_series_insights_environment_id   = azurerm_iot_time_series_insights_gen2_environment.tsi.id
  roles                                 = ["Contributor", "Reader"]
}
