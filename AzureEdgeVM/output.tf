
#################
#    Outputs    #
#################


output "device_name" {
    value = local.device_name
}

output "public_ip" {
  value = azurerm_linux_virtual_machine.vm.public_ip_address
}

output "ssh" {
  value = "ssh -i ${local.keyfile} ${var.user}@${azurerm_linux_virtual_machine.vm.public_ip_address}"
}