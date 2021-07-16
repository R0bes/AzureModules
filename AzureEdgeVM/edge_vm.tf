
#################
#    Locals     #
#################

locals {
  external_key    = var.keyfile != ""
  keyfile         = local.external_key ? var.keyfile : "${path.root}/${var.name}-vm.pem"
  
  root_ca_cert    = var.root_ca_cert
  device_ca_cert  = var.device_ca_cert
  device_ca_key   = var.device_ca_key

  device_name     = "${var.name}-device"
}



#################
#   Resources   #
#################

# RSA Key
resource "tls_private_key" "vm" {
  count     = local.external_key ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Private key file
resource "local_file" "private_key" {
  count           = local.external_key ? 0 : 1
  content         = tls_private_key.vm[0].private_key_pem
  filename        = local.keyfile
  file_permission = "0600"
}


# Edge Device Twin
module "device_twin" {
  source            = "./../AzureDeviceTwin/"
  name              = local.device_name
  iothub_name       = var.iothub_name
  edge              = true
}


# Public IP Adress
resource "azurerm_public_ip" "vm" {
  name                = "${var.name}-public-ip"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Dynamic"
}

# Virtual Network
resource "azurerm_virtual_network" "vm" {
  name                = "${var.name}-network"
  address_space       = [ "10.0.0.0/16" ]
  location            = var.location
  resource_group_name = var.resource_group
}

# Subnet
resource "azurerm_subnet" "vm" {
  name                 = "${var.name}-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.vm.name
  address_prefixes     = [ "10.0.2.0/24" ]
}

resource "azurerm_network_security_group" "vm" {
  name                  = "${var.name}-security-group"
  location              = var.location
  resource_group_name   = var.resource_group

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interface
resource "azurerm_network_interface" "vm" {
  name                  = "${var.name}-network-interface"
  location              = var.location
  resource_group_name   = var.resource_group

  ip_configuration {
    name                          = "internal-subnet"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}


# Network Interface + Security Group Association
resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}


# Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.name}-vm"
  resource_group_name = var.resource_group
  location            = var.location
  size                = "Standard_F2"

  admin_username      = var.user

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  admin_ssh_key {
    username   = var.user
    public_key = local.external_key ? file(var.keyfile) : tls_private_key.vm[0].public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = var.ubuntu_version
    version   = "latest"
  }

  custom_data = base64encode(data.template_file.cloud_init_template.rendered)
}


# custom user data template file
data "template_file" "cloud_init_template" {
  vars = {
      connection_string = module.device_twin.connection_string
  }
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
  - moby-engine
runcmd:
  - |
      set -x
      (
        # Wait for docker daemon to start
        while [ $(ps -ef | grep -v grep | grep docker | wc -l) -le 0 ]; do 
          sleep 3
        done

        apt install aziot-identity-service=1.2.0-1
        apt install aziot-edge=1.2.0-1

        mkdir /etc/aziot
        wget https://raw.githubusercontent.com/Azure/iotedge-vm-deploy/1.2.0/config.toml -O /etc/aziot/config.toml
        sed -i "s#connection_string = #connection_string = \x22$${connection_string}\x22#g" /etc/aziot/config.toml
        
        iotedge config apply -c /etc/aziot/config.toml

        apt install -y deviceupdate-agent 
        apt install -y deliveryoptimization-plugin-apt
        systemctl restart adu-agent
      ) &
TMPL
}