

#################
#   Variables   #
#################

variable "location" {
    description = "The resource groups location"
    type        = string
}

variable "resource_group" {
    description = "The resource group name"
    type        = string
}

variable "name" {
    type        = string    
    validation {
        condition     = can(regex("^[a-z][a-z0-9-]{1,56}[a-z0-9].", var.name))
        error_message = "Edge base name. Needs to fulfill the regular expression: '^[a-z][a-z0-9-]{1,56}[a-z0-9]$'."
    }
}

variable "user" {
    description = "VM user name"
    type        = string
}

variable "keyfile" {
    description = "VM key"
    type = string
    default = ""
}

variable "ubuntu_version" {
    description = "Ubuntu version"
    default = "18.04-LTS"
}

variable "iothub_name" {
    description = "The iot hub name"
    type        = string
}

variable "root_ca_cert" {}

variable "device_ca_cert" {}

variable "device_ca_key" {}