
variable "resource_group" {
    description = "The resource group name"
    type        = string
}

variable "iot_hub" {
    description = "The iot hub name"
    type        = string
}

variable "name" {
    type        = string    
    validation {
        condition     = can(regex("^[a-z][a-z0-9-]{1,56}[a-z0-9].", var.name))
        error_message = "Edge base name. Needs to fulfill the regular expression: '^[a-z][a-z0-9-]{1,56}[a-z0-9]$'."
    }
}

variable "vm_user" {
    description = "VM user name"
    type        = string
}

variable "vm_password" {
    description = "VM user password"
    type = string
    sensitive = true
}

variable "ubuntuVersion" {
    description = "Ubuntu version"
    default = "18.04-LTS"
}