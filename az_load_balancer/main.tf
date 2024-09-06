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

resource "azurerm_network_interface" "az_net_interface1" {
  name                = "${var.network-interface-name}1"
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

resource "azurerm_network_interface" "az_net_interface2" {
  name                = "${var.network-interface-name}2"
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

resource "azurerm_windows_virtual_machine" "new-az-vm1" {
  name                = "${var.virtual-machine}1"
  resource_group_name = azurerm_resource_group.rg_new_resource.name
  location            = azurerm_resource_group.rg_new_resource.location
  size                = "Standard_F2"
  admin_username      = "testuser1"
  admin_password      = "Azure@234"
  availability_set_id = azurerm_availability_set.avail_set.id
  network_interface_ids = [
    azurerm_network_interface.az_net_interface1.id
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
  depends_on = [azurerm_network_interface.az_net_interface1, azurerm_resource_group.rg_new_resource,
    azurerm_availability_set.avail_set]
}

resource "azurerm_virtual_machine_extension" "vm_extension1" {
  name                 = "appvm-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.new-az-vm1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [
    azurerm_storage_blob.config_upload
  ]
  settings = <<SETTINGS
    {
        "fileUris": ["https://${azurerm_storage_account.app_storage_lb.name}.blob.core.windows.net/container1/config.ps1"],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file config.ps1"
    }
SETTINGS
}

resource "azurerm_virtual_machine_extension" "vm_extension2" {
  name                 = "appvm-extension2"
  virtual_machine_id   = azurerm_windows_virtual_machine.new-az-vm2.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [
    azurerm_storage_blob.config_upload
  ]
  settings = <<SETTINGS
    {
        "fileUris": ["https://${azurerm_storage_account.app_storage_lb.name}.blob.core.windows.net/container1/config.ps1"],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file config.ps1"
    }
SETTINGS
}

resource "azurerm_windows_virtual_machine" "new-az-vm2" {
  name                = "${var.virtual-machine}2"
  resource_group_name = azurerm_resource_group.rg_new_resource.name
  location            = azurerm_resource_group.rg_new_resource.location
  size                = "Standard_F2"
  admin_username      = "testuser2"
  admin_password      = "Azure@234"
  availability_set_id = azurerm_availability_set.avail_set.id
  network_interface_ids = [
    azurerm_network_interface.az_net_interface2.id
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
  depends_on = [azurerm_network_interface.az_net_interface2, azurerm_resource_group.rg_new_resource,
  azurerm_availability_set.avail_set]
}

resource "azurerm_availability_set" "avail_set" {
  name                = var.availability_set
  location            = azurerm_resource_group.rg_new_resource.location
  resource_group_name = azurerm_resource_group.rg_new_resource.name
  platform_fault_domain_count=2

  depends_on = [azurerm_resource_group.rg_new_resource]
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

resource "azurerm_storage_account" "app_storage_lb" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg_new_resource.name
  location                 = azurerm_resource_group.rg_new_resource.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "new_storage_container" {
  name                  = "container1"
  storage_account_name  = azurerm_storage_account.app_storage_lb.name
  container_access_type = "blob"
  depends_on = [
    azurerm_storage_account.app_storage_lb
  ]
}

resource "azurerm_storage_blob" "config_upload" {
  name                   = "config.ps1"
  storage_account_name   = azurerm_storage_account.app_storage_lb.name
  storage_container_name = azurerm_storage_container.new_storage_container.name
  type                   = "Block"
  source                 = "config.ps1"
  depends_on = [azurerm_storage_container.new_storage_container]
}

resource "azurerm_public_ip" "az_lb_public_ip" {
  name                = var.public_ip
  resource_group_name = azurerm_resource_group.rg_new_resource.name
  location            = azurerm_resource_group.rg_new_resource.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "app_load_balancer" {
  name                = var.az_lb
  location            = azurerm_resource_group.rg_new_resource.location
  resource_group_name = azurerm_resource_group.rg_new_resource.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.az_lb_public_ip.id
  }
  depends_on = [azurerm_public_ip.az_lb_public_ip]
}

resource "azurerm_lb_backend_address_pool" "az_lb_bck_pool" {
  loadbalancer_id = azurerm_lb.app_load_balancer.id
  name            = "BackEndAddressPool"
  depends_on = [azurerm_lb.app_load_balancer]
}

resource "azurerm_lb_backend_address_pool_address" "VMAddr1" {
  name                                = "appVM1"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.az_lb_bck_pool.id
#  backend_address_ip_configuration_id = azurerm_lb.app_load_balancer.frontend_ip_configuration[0].id
  virtual_network_id = azurerm_virtual_network.new_vnet.id
  ip_address = azurerm_network_interface.az_net_interface1.private_ip_address
  depends_on = [azurerm_lb_backend_address_pool.az_lb_bck_pool]
}

resource "azurerm_lb_backend_address_pool_address" "VMAddr2" {
  name                                = "appVM2"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.az_lb_bck_pool.id
#backend_address_ip_configuration_id = azurerm_lb.app_load_balancer.frontend_ip_configuration[0].id
  virtual_network_id = azurerm_virtual_network.new_vnet.id
  ip_address = azurerm_network_interface.az_net_interface2.private_ip_address
  depends_on = [azurerm_lb_backend_address_pool.az_lb_bck_pool]
}

resource "azurerm_lb_probe" "app_lb_probe" {
  loadbalancer_id = azurerm_lb.app_load_balancer.id
  name            = "ProbeA"
  port            = 80
  depends_on = [azurerm_lb.app_load_balancer]
}

resource "azurerm_lb_rule" "example" {
  loadbalancer_id                = azurerm_lb.app_load_balancer.id
  name                           = "RuleA"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.az_lb_bck_pool.id]
  probe_id = azurerm_lb_probe.app_lb_probe.id
  depends_on = [azurerm_lb.app_load_balancer, azurerm_lb_probe.app_lb_probe]
}


