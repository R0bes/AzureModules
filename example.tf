
# Terraform config
terraform {
    backend "local" {}
    required_providers {
        azurerm = {
            source  = "hashicorp/azurerm"
            version = ">=2.63.0"
        }
    }
}

# Azurerm Provider
provider "azurerm" {
    features {}
}


# Base Name
variable "unique_prefix" {
  type = string
  default = "un7qu3"
}

# TSI Access
variable "principal_object_ids" {
  type    = list(object({ name=string, id=string }))
  default = []
}


# Resource Group
resource "azurerm_resource_group" "main" {
    name = "${var.unique_prefix}-resourcegroup"
    location = "westeurope"
}

# Storage Account
resource "azurerm_storage_account" "main" {
    name                      = "${var.unique_prefix}storage"
    resource_group_name       = azurerm_resource_group.main.name
    location                  = azurerm_resource_group.main.location
    account_tier              = "Standard"
    account_replication_type  = "LRS"
}

# IoT Hub
resource "azurerm_iothub" "main" {
    name = "${var.unique_prefix}-iothub"
    resource_group_name   = azurerm_resource_group.main.name
    location              = azurerm_resource_group.main.location
    sku {
        name     = "S1"
        capacity = "1"
    }

    route {
        name                = "EventGrid"
        source              = "DeviceMessages"
        condition           = "true"
        endpoint_names      = ["events"]
        enabled             = true
    }
}

# Time Series Insights
module "tsi" {
    source = "./Modules/AzureTimeSeriesInsights"
    name ="${var.unique_prefix}tsi"
    location = azurerm_resource_group.main.location
    resourcegroup_name = azurerm_resource_group.main.name
    storage_name = azurerm_storage_account.main.name
    storage_key = azurerm_storage_account.main.primary_access_key
    iothub_name = azurerm_iothub.main.name
    iothub_id = azurerm_iothub.main.id
    iothub_key = azurerm_iothub.main.shared_access_policy[0].primary_key
    principal_object_ids = var.principal_object_ids
}

# Device Twins
module "device_twin" {
    source = "./Modules/AzureDeviceTwin/"
    name = "ExampleDevice"
    iothub_name = azurerm_iothub.main.name
}

module "edge_device_twin" {
    source = "./Modules/AzureDeviceTwin/"
    name = "ExampleEdgeDevice"
    iothub_name = azurerm_iothub.main.name
    edge = true
}

module "device_twin_list" {
    source = "./Modules/AzureDeviceTwin/"
    for_each = toset(["ExampleListDevice1", "ExampleListDevice2", "ExampleListDevice3"])
    name = each.key
    iothub_name = azurerm_iothub.main.name
}

# Device Twin Connection String Output
output "device_twin_connection_string" {
    value = module.device_twin.connection_string
    sensitive = true
}