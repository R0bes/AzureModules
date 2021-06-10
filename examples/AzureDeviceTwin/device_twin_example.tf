
terraform {
    backend "local" {}
    
    required_providers {
        azurerm = {
            source  = "hashicorp/azurerm"
            version = "=2.62.1"
        }
    }
}

provider "azurerm" {
    features {}
}

variable "name" {
  type = string
  default = "example"
}

resource "azurerm_resource_group" "main" {
    name = "${var.name}-resourcegroup"
    location = "westeurope"
}

resource "azurerm_iothub" "main" {
    name = "${var.name}-iothub"
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

module "device_twin" {
    source = "./../../AzureDeviceTwin/"
    name = "ExampleDevice"
    iothub_name = azurerm_iothub.main.name
}

module "edge_device_twin" {
    source = "./../../AzureDeviceTwin/"
    name = "ExampleEdgeDevice"
    iothub_name = azurerm_iothub.main.name
    edge = true
}

module "device_twin_list" {
    source = "./../../AzureDeviceTwin/"
    for_each = toset(["ExampleListDevice1", "ExampleListDevice2", "ExampleListDevice3"])
    name = each.key
    iothub_name = azurerm_iothub.main.name
}