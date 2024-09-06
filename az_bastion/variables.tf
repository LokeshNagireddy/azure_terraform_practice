variable "location" {
        type = string
        default = "Central India"
}

variable "rg_name" {
        type = string
        default = "az-rg-group"
}

variable "az-vnet-name" {
        type = string
        default = "az-bas-vnet"
}

variable "network-interface-name" {
        type = string
        default = "az-bas-net-intr"
}

variable "bastion-public-ip" {
        type = string
        default = "az-bas-public-ip"
}

variable "virtual-machine" {
        type = string
        default = "az-bas-vm"
}

variable "app_nsg" {
        type = string
        default = "az-bas-app-nsg"
}