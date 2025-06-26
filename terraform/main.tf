resource "azurerm_resource_group" "rg" {
  name = "rg-network"
  location = var.primary_location
}

module "vnet" {
  source = "Azure/avm-res-network-virtualnetwork/azurerm"

  address_space = ["10.0.0.0/16"]
  name = "vnet-management"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  subnets = {
    "servers" = {
      name = "servers"
      address_prefixes = ["10.0.1.0/24"]
    }
  }
}
