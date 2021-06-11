
resource "azurerm_iothub_consumer_group" "iothub_tsi_consumer" {
  name                   = "${var.name}tsiconsumergroup"
  iothub_name            = var.iothub_name
  eventhub_endpoint_name = var.iothub_endpoint
  resource_group_name    = var.resourcegroup_name
}


resource "azurerm_iot_time_series_insights_gen2_environment" "tsi" {
  name                = "${var.name}tsi"
  location            = var.location
  resource_group_name = var.resourcegroup_name
  sku_name            = "L1"
  warm_store_data_retention_time = "P7D"  
  id_properties = ["iothub-connection-device-id"]

  storage {
    name = var.storage_name
    key  = var.storage_key
  }
    
  provisioner "local-exec" {
      when        = create
      interpreter = ["pwsh", "-Command"]
      command     = <<SCRIPT
        az tsi event-source iothub create `
          --consumer-group-name ${azurerm_iothub_consumer_group.iothub_tsi_consumer.name} `
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


resource "azurerm_iot_time_series_insights_access_policy" "iot_tsi_access" {
  count                                 = length(var.principal_object_ids)
  name                                  = var.principal_object_ids[count.index].name
  principal_object_id                   = var.principal_object_ids[count.index].id
  time_series_insights_environment_id   = azurerm_iot_time_series_insights_gen2_environment.tsi.id
  roles                                 = ["Contributor", "Reader"]
}
