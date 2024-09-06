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

resource "azurerm_resource_group" "new_resource" {
  location = var.location
  name     = "az-rg-group1"
}

resource "azurerm_virtual_network" "new_vnet" {
  name                = var.az-vnet-name
  location            = azurerm_resource_group.new_resource.location
  resource_group_name = azurerm_resource_group.new_resource.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]
  depends_on = [azurerm_resource_group.new_resource]
}

resource "azurerm_subnet" "az-subnet" {
  name                 = "subnetA"
  resource_group_name  = azurerm_resource_group.new_resource.name
  virtual_network_name = azurerm_virtual_network.new_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [azurerm_virtual_network.new_vnet]
}

resource "azurerm_network_interface" "new_interface" {
  name                = var.network-interface-name
  location            = azurerm_resource_group.new_resource.location
  resource_group_name = azurerm_resource_group.new_resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.az-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.az-public-ip.id
  }
  depends_on = [
    azurerm_virtual_network.new_vnet,
    azurerm_subnet.az-subnet,
    azurerm_public_ip.az-public-ip
  ]
}

resource "azurerm_windows_virtual_machine" "new-az-vm" {
  name                = var.virtual-machine
  resource_group_name = azurerm_resource_group.new_resource.name
  location            = azurerm_resource_group.new_resource.location
  size                = "Standard_F2"
  admin_username      = "testuser"
  admin_password      = azurerm_key_vault_secret.vmpswd.value
  availability_set_id = azurerm_availability_set.avail-set.id
  network_interface_ids = [
    azurerm_network_interface.new_interface.id
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
  depends_on = [azurerm_network_interface.new_interface,
  azurerm_availability_set.avail-set,
  azurerm_key_vault_secret.vmpswd]
}

resource "azurerm_public_ip" "az-public-ip" {
  name                = var.public-ip
  resource_group_name = azurerm_resource_group.new_resource.name
  location            = azurerm_resource_group.new_resource.location
  allocation_method   = "Static"
}

resource "azurerm_managed_disk" "new_data_disk" {
  name                 = "${var.az-vnet-name}-disk1"
  location             = azurerm_resource_group.new_resource.location
  resource_group_name  = azurerm_resource_group.new_resource.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 5
}

resource "azurerm_virtual_machine_data_disk_attachment" "new_disk_attach" {
  managed_disk_id    = azurerm_managed_disk.new_data_disk.id
  virtual_machine_id = azurerm_windows_virtual_machine.new-az-vm.id
  lun                = "10"
  caching            = "ReadWrite"
  depends_on = [
    azurerm_windows_virtual_machine.new-az-vm,
    azurerm_managed_disk.new_data_disk
  ]
}

resource "azurerm_availability_set" "avail-set" {
  name                = "az-tf-availability-set"
  location            = azurerm_resource_group.new_resource.location
  resource_group_name = azurerm_resource_group.new_resource.name
  platform_fault_domain_count=2

  depends_on = [azurerm_resource_group.new_resource]
}

resource "azurerm_network_security_group" "app_nsg" {
  name                = "app_nsg1"
  location            = azurerm_resource_group.new_resource.location
  resource_group_name = azurerm_resource_group.new_resource.name

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
  depends_on = [azurerm_resource_group.new_resource]
}

resource "azurerm_subnet_network_security_group_association" "az_nsg_sub" {
  subnet_id                 = azurerm_subnet.az-subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
  depends_on = [azurerm_network_security_group.app_nsg]
}

resource "azurerm_key_vault" "app_keyvault" {
  name                       = "az-tf-keyvault"
  location                   = azurerm_resource_group.new_resource.location
  resource_group_name        = azurerm_resource_group.new_resource.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  depends_on = [azurerm_resource_group.new_resource]
}

resource "azurerm_key_vault_access_policy" "app_key_vault_acc_plcy" {
  key_vault_id = azurerm_key_vault.app_keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create",
    "Get",
  ]

  secret_permissions = [
    "Set",
    "Get",
    "Delete",
    "Purge",
    "Recover",
    "List",
  ]

  storage_permissions = [
    "Get",
  ]
  depends_on = [azurerm_key_vault.app_keyvault]
}

resource "azurerm_key_vault_secret" "vmpswd" {
  name         = "vmsecret"
  value        = "Test123$"
  key_vault_id = azurerm_key_vault.app_keyvault.id

  depends_on = [azurerm_key_vault.app_keyvault, azurerm_key_vault_access_policy.app_key_vault_acc_plcy]
}

resource "azurerm_app_service_plan" "az_app_srvc_plan" {
  name                = "az-tf-appserviceplan1"
  location            = azurerm_resource_group.new_resource.location
  resource_group_name = azurerm_resource_group.new_resource.name

  sku {
    tier = "Free"
    size = "F1"
  }
  depends_on = [azurerm_resource_group.new_resource]
}

resource "azurerm_app_service" "az_webapp" {
  name                = "az-tf-webapp-service"
  location            = azurerm_resource_group.new_resource.location
  resource_group_name = azurerm_resource_group.new_resource.name
  app_service_plan_id = azurerm_app_service_plan.az_app_srvc_plan.id
  depends_on = [azurerm_resource_group.new_resource, azurerm_app_service_plan.az_app_srvc_plan]
}
