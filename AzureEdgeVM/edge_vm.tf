
#################
#    Locals     #
#################

locals {
  device_name = "${var.name}-device"
  vm_name     = "${var.name}-vm"
  
  custom_data = <<CUSTOM_DATA
  #!/bin/bash
  echo "Execute your super awesome commands here!"
  echo 'Hello World!' > /home/rnsd/test_file.txt
  CUSTOM_DATA
}



#################
#   Resources   #
#################

# Edge Device Twin
module "device_twin" {
  source      = "./../AzureDeviceTwin/"
  name        = local.device_name
  iothub_name = var.iot_hub
  edge        = true
}

# Public IP Adress
resource "azurerm_public_ip" "main" {
  name                = "${var.name}-public-ip"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Dynamic"
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.name}-network"
  address_space       = [ "10.0.0.0/16" ]
  location            = var.location
  resource_group_name = var.resource_group
}

# Subnet
resource "azurerm_subnet" "main" {
  name                 = "${var.name}-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [ "10.0.2.0/24" ]
}

# Network Interface
resource "azurerm_network_interface" "main" {
  name                = "${var.name}-net-interface"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "internal-subnet"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# Virtual Machine
resource "azurerm_virtual_machine" "main" {
  name                  = "${var.name}-vm"
  location              = var.location
  resource_group_name   = var.resource_group
  network_interface_ids = [ azurerm_network_interface.main.id ]
  vm_size               = "Standard_DS1_v2"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = var.ubuntu_version
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.name}-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  os_profile {
    computer_name  = local.vm_name
    admin_username = var.vm_user
    admin_password = var.vm_password
    custom_data    = base64encode(data.template_file.cloud_init.renderd)
  }
}

# Data template Bash bootstrapping file
data "local_file" "cloudinit_template" {
    filename = "${path.module}/cloudinit.conf"
}

# manifest template script in two variants (for each command)
data "template_file" "cloud_init" {
    template = local_file.cloudinit_template.content
    vars = {
        device_key = module.device_twin.connection_string
    }
}

/*
               packages:
                - moby-cli
                - libiothsm-std
                - moby-engine
              runcmd:
                - |
                set -x
                (
                  # Wait for docker daemon to start
                  while [ $(ps -ef | grep -v grep | grep docker | wc -l) -le 0 ]; 
                  do 
                    sleep 3
                  done
                  
                  # Prevent iotedge from starting before the device connection string is set in config.yaml
                  
                  sudo ln -s /dev/null /etc/systemd/system/iotedge.service
                  apt install iotedge
                  sed -i \"s#\\(device_connection_string: \\).*#\\1\\\"', variables('dcs'), '\\\"#g\" /etc/iotedge/config.yaml
                  systemctl unmask iotedge
                  systemctl start iotedge
                )
                */