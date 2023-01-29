# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.az-subscription
  tenant_id       = var.az-tenant
}

# Create a resource group
resource "azurerm_resource_group" "rg-lab-jde" {
  name     = "rg-lab-jde"
  location = var.rg-location
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vnet-lab-jde" {
  name                = "vnet-lab-jde"
  resource_group_name = azurerm_resource_group.rg-lab-jde.name
  location            = azurerm_resource_group.rg-lab-jde.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet-lab-jde" {
  name                 = "subnet-lab-jde"
  resource_group_name  = azurerm_resource_group.rg-lab-jde.name
  virtual_network_name = azurerm_virtual_network.vnet-lab-jde.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "pip-lab-jde" {
  name                = "pip-lab-jde"
  resource_group_name = azurerm_resource_group.rg-lab-jde.name
  location            = azurerm_resource_group.rg-lab-jde.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic-lab-jde" {
  name                = "nic-lab-jde"
  location            = azurerm_resource_group.rg-lab-jde.location
  resource_group_name = azurerm_resource_group.rg-lab-jde.name

  ip_configuration {
    name                          = "subnet-lab-jde"
    subnet_id                     = azurerm_subnet.subnet-lab-jde.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip-lab-jde.id
  }
}

resource "azurerm_network_security_group" "nsg-lab-jde" {
  name                = "nsg-lab-jde"
  location            = azurerm_resource_group.rg-lab-jde.location
  resource_group_name = azurerm_resource_group.rg-lab-jde.name
}

resource "azurerm_network_security_rule" "allow_ssh_sg" {
  name                        = "allow_ssh_sg"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-lab-jde.name
  network_security_group_name = azurerm_network_security_group.nsg-lab-jde.name
}

resource "azurerm_network_security_rule" "allow_http_sg" {
  name                        = "allow_http_sg"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-lab-jde.name
  network_security_group_name = azurerm_network_security_group.nsg-lab-jde.name
}

resource "azurerm_network_security_rule" "allow_http8080_sg" {
  name                        = "allow_http_sg"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-lab-jde.name
  network_security_group_name = azurerm_network_security_group.nsg-lab-jde.name
}

resource "azurerm_network_interface_security_group_association" "sga-lab-jde" {
  network_interface_id      = azurerm_network_interface.nic-lab-jde.id
  network_security_group_id = azurerm_network_security_group.nsg-lab-jde.id
}

resource "azurerm_linux_virtual_machine" "srv-jenkins" {
  name                = "srv-jenkins"
  resource_group_name = azurerm_resource_group.rg-lab-jde.name
  location            = azurerm_resource_group.rg-lab-jde.location
  size                = "Standard_D2s_v3"
  admin_username      = "jenkinsuser"
  network_interface_ids = [
    azurerm_network_interface.nic-lab-jde.id,
  ]

  admin_ssh_key {
    username   = "jenkinsuser"
    public_key = file("~/.ssh/sshsrvjenkins.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202301130"
  }
}

resource "azurerm_kubernetes_cluster" "aks-lab-jde" {
  name                = "aks_lab_jde"
  location            = azurerm_resource_group.rg-lab-jde.location
  resource_group_name = azurerm_resource_group.rg-lab-jde.name
  dns_prefix          = "akslabjde"

  default_node_pool {
    name                = "default"
    type                = "VirtualMachineScaleSets"
    vm_size             = "Standard_B4ms"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 2
  }

  identity {
    type = "SystemAssigned"
  }
}

output "srv-jenkins-ip" {
  value = azurerm_public_ip.pip-lab-jde.*.ip_address
}