resource "azurerm_resource_group" "rg" {
  name     = "rg-network"
  location = var.primary_location
}

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.9.2"

  address_space       = ["10.0.0.0/16"]
  name                = "vnet-hub"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  subnets = {
    "mgmt" = {
      name             = "snet-mgmt"
      address_prefixes = ["10.0.1.0/24"]
    }
    "avd" = {
      name             = "snet-avd"
      address_prefixes = ["10.0.2.0/24"]
    }
    "servers" = {
      name             = "snet-servers"
      address_prefixes = ["10.0.3.0/24"]
    }
  }
}
