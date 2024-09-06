variable "storage_account_name" {
        default = "azterrastrorage1"
}

variable "az-vnet-name" {
        default = "az-tf-vnet"
}

variable "network-interface-name" {
        default = "az-tf-network-interface"
}

variable "virtual-machine" {
        default = "az-tf-vm"
}

variable "public-ip" {
        default = "az-tf-public-ip"
}

variable "location" {
        type = string
        default = "Central India"
}