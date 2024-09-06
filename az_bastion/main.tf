terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.116.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription-id
  client_id = var.client-id
  client_secret = var.client-secret
  tenant_id = var.tenant-id
  features {}
}

resource "azurerm_resource_group" "rg_new_resource" {
  location = var.location
  name     = var.rg_name
}

resource "azurerm_virtual_network" "new_vnet" {
  name                = var.az-vnet-name
  location            = azurerm_resource_group.rg_new_resource.location
  resource_group_name = azurerm_resource_group.rg_new_resource.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]
  depends_on = [azurerm_resource_group.rg_new_resource]
}

resource "azurerm_subnet" "az-subnet" {
  name                 = "subnetA"
  resource_group_name  = azurerm_resource_group.rg_new_resource.name
  virtual_network_name = azurerm_virtual_network.new_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
  depends_on = [azurerm_virtual_network.new_vnet]
}

resource "azurerm_subnet" "subnetB" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg_new_resource.name
  virtual_network_name = azurerm_virtual_network.new_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [azurerm_virtual_network.new_vnet]
}

resource "azurerm_public_ip" "az-bastion-public-ip" {
  name                = var.bastion-public-ip
  resource_group_name = azurerm_resource_group.rg_new_resource.name
  location            = azurerm_resource_group.rg_new_resource.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "az_net_interface" {
  name                = var.network-interface-name
  location            = azurerm_resource_group.rg_new_resource.location
  resource_group_name = azurerm_resource_group.rg_new_resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.az-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [
    azurerm_virtual_network.new_vnet,
    azurerm_subnet.az-subnet
  ]
}

resource "azurerm_windows_virtual_machine" "new-az-vm" {
  name                = var.virtual-machine
  resource_group_name = azurerm_resource_group.rg_new_resource.name
  location            = azurerm_resource_group.rg_new_resource.location
  size                = "Standard_F2"
  admin_username      = "testuser"
  admin_password      = "Azure@234"
  network_interface_ids = [
    azurerm_network_interface.az_net_interface.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  depends_on = [azurerm_network_interface.az_net_interface, azurerm_resource_group.rg_new_resource]
}

resource "azurerm_network_security_group" "app_nsg" {
  name                = var.app_nsg
  location            = azurerm_resource_group.rg_new_resource.location
  resource_group_name = azurerm_resource_group.rg_new_resource.name

  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  depends_on = [azurerm_resource_group.rg_new_resource]
}

resource "azurerm_subnet_network_security_group_association" "az_nsg_sub" {
  subnet_id                 = azurerm_subnet.az-subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
  depends_on = [azurerm_network_security_group.app_nsg]
}

resource "azurerm_bastion_host" "app_bastion" {
  name                = "az-app-bastion"
  location            = azurerm_resource_group.rg_new_resource.location
  resource_group_name = azurerm_resource_group.rg_new_resource.name

  ip_configuration {
    name                 = "bastion-configuration"
    subnet_id            = azurerm_subnet.subnetB.id
    public_ip_address_id = azurerm_public_ip.az-bastion-public-ip.id
  }
}