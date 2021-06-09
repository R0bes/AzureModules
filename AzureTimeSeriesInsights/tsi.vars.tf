
variable "name" {
    description = "Base Name for all resources"
    type = string
}

variable "location" {
    description = "Location"
    type = string
    default = "westeurope"
}

variable "resourcegroup_name" {
    description = "Name of the resource group"
    type = string
}

variable "storage_name" {
    description = "Name of the Storage Account"
    type = string
}

variable "storage_key" {
    description = "Key for the Storage Account"
    type = string
}

variable "iothub_name" {
    description = "Name of the IoT Hub"
    type = string
}

variable "iothub_id" {
    description = "ID of the IoT Hub"
    type = string
}

# azurerm_iothub.main.shared_access_policy.0.primary_key
variable "iothub_key" {
    description = "Key for the IoT Hub: key azurerm_iothub.main.shared_access_policy.0.primary_key"
    type = string
}

variable "iothub_key_name" {
    description = "Name of the IoT Hub"
    type = string
    default = "iothubowner"
}

variable "iothub_endpoint" {
    description = "Endpoint of the IoT Hub"
    type = string
    default = "events"
}

variable "principal_object_ids" {
    description = "The principal object ids to gain access to time series insight"
    type    = list(object({ name=string, id=string }))
    default = []
}
