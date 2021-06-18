
#################
#    Locals     #
#################

locals {
    device_name = "${var.name}-device"
    vm_name     = "${var.name}-vm"
}


#################
#   Resources   #
#################


# Edge Device Twin
module "device_twin" {
    source = "./../AzureDeviceTwin/"
    name = local.device_name
    iothub_name = var.iot_hub
    edge = true
}

# Virtual Machine with edge deployed
resource "null_resource" "edge_vm" {
    depends_on = [ module.device_twin ]
    provisioner "local-exec" {
        interpreter = ["pwsh" , "-Command"]
        command =<<EOT
            az deployment group create `
                --resource-group ${var.resource_group} `
                --template-file '${abspath("./Modules/AzureEdgeVM2/DeployEdgeVM.json")}' `
                --parameters dnsLabelPrefix='${local.vm_name}' `
                --parameters adminUsername='${var.vm_user}' `
                --parameters deviceConnectionString="${module.device_twin.connection_string}" `
                --parameters ubuntuOSVersion='${var.ubuntuVersion}' `
                --parameters adminPasswordOrKey='${var.vm_key}'
        EOT
    }
}