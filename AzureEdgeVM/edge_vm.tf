
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
    custom_data    = base64encode(data.template_file.cloud_init_script.rendered)
  }
}
# provide variables
data "template_file" "cloud_init_script" {
    template =<<TMPL
#cloud-config
apt:
    preserve_sources_list: true
    sources:
        msft.list:
            source: "deb https://packages.microsoft.com/ubuntu/18.04/multiarch/prod bionic main"
            key: |
                -----BEGIN PGP PUBLIC KEY BLOCK-----
                Version: GnuPG v1.4.7 (GNU/Linux)

                mQENBFYxWIwBCADAKoZhZlJxGNGWzqV+1OG1xiQeoowKhssGAKvd+buXCGISZJwT
                LXZqIcIiLP7pqdcZWtE9bSc7yBY2MalDp9Liu0KekywQ6VVX1T72NPf5Ev6x6DLV
                7aVWsCzUAF+eb7DC9fPuFLEdxmOEYoPjzrQ7cCnSV4JQxAqhU4T6OjbvRazGl3ag
                OeizPXmRljMtUUttHQZnRhtlzkmwIrUivbfFPD+fEoHJ1+uIdfOzZX8/oKHKLe2j
                H632kvsNzJFlROVvGLYAk2WRcLu+RjjggixhwiB+Mu/A8Tf4V6b+YppS44q8EvVr
                M+QvY7LNSOffSO6Slsy9oisGTdfE39nC7pVRABEBAAG0N01pY3Jvc29mdCAoUmVs
                ZWFzZSBzaWduaW5nKSA8Z3Bnc2VjdXJpdHlAbWljcm9zb2Z0LmNvbT6JATUEEwEC
                AB8FAlYxWIwCGwMGCwkIBwMCBBUCCAMDFgIBAh4BAheAAAoJEOs+lK2+EinPGpsH
                /32vKy29Hg51H9dfFJMx0/a/F+5vKeCeVqimvyTM04C+XENNuSbYZ3eRPHGHFLqe
                MNGxsfb7C7ZxEeW7J/vSzRgHxm7ZvESisUYRFq2sgkJ+HFERNrqfci45bdhmrUsy
                7SWw9ybxdFOkuQoyKD3tBmiGfONQMlBaOMWdAsic965rvJsd5zYaZZFI1UwTkFXV
                KJt3bp3Ngn1vEYXwijGTa+FXz6GLHueJwF0I7ug34DgUkAFvAs8Hacr2DRYxL5RJ
                XdNgj4Jd2/g6T9InmWT0hASljur+dJnzNiNCkbn9KbX7J/qK1IbR8y560yRmFsU+
                NdCFTW7wY0Fb1fWJ+/KTsC4=
                =J6gs
                -----END PGP PUBLIC KEY BLOCK-----
packages:
 - moby-cli
 - libiothsm-std
 - moby-engine
 runcmd:
 - |
    set -x
    (
        # Wait for docker daemon to start
        while [ $(ps -ef | grep -v grep | grep docker | wc -l) -le 0 ]; do 
            sleep 3
        done

        # Prevent iotedge from starting before the device connection string is set in config.yaml
        sudo ln -s /dev/null /etc/systemd/system/iotedge.service
        apt install iotedge
        sed -i \"s#\\(device_connection_string: \\).*#\\1\\\"', $${device_key}, '\\\"#g\" /etc/iotedge/config.yaml
        systemctl unmask iotedge
        systemctl start iotedge
    ) &
TMPL

    vars = {
        device_key = module.device_twin.connection_string
    }
}

# provide variables
#data "template_file" "cloud_init_script" {
#    template = "${path.module}/cloudinit.conf.tmpl"
#    vars = {
#        device_key = module.device_twin.connection_string
#    }
#}


# local template file
#data "local_file" "cloud_init_template" {
#    filename = "${path.module}/cloudinit.conf"
#}


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