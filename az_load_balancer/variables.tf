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
        default = "az-lb-vnet"
}

variable "network-interface-name" {
        type = string
        default = "az-lb-net-intr"
}

variable "virtual-machine" {
        type = string
        default = "az-lb-vm"
}

variable "app_nsg" {
        type = string
        default = "az-lb-app-nsg"
}

variable "availability_set" {
        default = "avail-set"
}

variable "storage_account_name" {
        default = "azlbstorage05"
}

variable "public_ip" {
        default = "azlbpublicip"
}

variable "az_lb" {
        default = "az-load-balancer"
}