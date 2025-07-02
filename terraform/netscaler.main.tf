# Deployment RG
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# RG voor VNet (zelfde of anders)
locals {
  vnet_rg = length(var.vnet_resource_group) > 0 ? var.vnet_resource_group : data.azurerm_resource_group.rg.name
}

# VNet: nieuw of bestaand
resource "azurerm_virtual_network" "vnet" {
  count               = var.vnet_new_or_existing == "new" ? 1 : 0
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  address_space       = [var.snet_address_prefix_01, var.snet_address_prefix_11, var.snet_address_prefix_12]
}

data "azurerm_virtual_network" "existing" {
  count               = var.vnet_new_or_existing == "existing" ? 1 : 0
  name                = var.vnet_name
  resource_group_name = local.vnet_rg
}

# Subnets – nieuw of bestaand
resource "azurerm_subnet" "mgmt" {
  count                = var.vnet_new_or_existing == "new" ? 1 : 0
  name                 = var.snet_name_01
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = [var.snet_address_prefix_01]
}
resource "azurerm_subnet" "client" {
  count                = var.vnet_new_or_existing == "new" ? 1 : 0
  name                 = var.snet_name_11
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = [var.snet_address_prefix_11]
}
resource "azurerm_subnet" "server" {
  count                = var.vnet_new_or_existing == "new" ? 1 : 0
  name                 = var.snet_name_12
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = [var.snet_address_prefix_12]
}

data "azurerm_subnet" "mgmt_existing" {
  count                = var.vnet_new_or_existing == "existing" ? 1 : 0
  name                 = var.snet_name_01
  virtual_network_name = var.vnet_name
  resource_group_name  = local.vnet_rg
}
data "azurerm_subnet" "client_existing" {
  count                = var.vnet_new_or_existing == "existing" ? 1 : 0
  name                 = var.snet_name_11
  virtual_network_name = var.vnet_name
  resource_group_name  = local.vnet_rg
}
data "azurerm_subnet" "server_existing" {
  count                = var.vnet_new_or_existing == "existing" ? 1 : 0
  name                 = var.snet_name_12
  virtual_network_name = var.vnet_name
  resource_group_name  = local.vnet_rg
}

locals {
  snet_mgmt_id   = var.vnet_new_or_existing == "new" ? azurerm_subnet.mgmt[0].id : data.azurerm_subnet.mgmt_existing[0].id
  snet_client_id = var.vnet_new_or_existing == "new" ? azurerm_subnet.client[0].id : data.azurerm_subnet.client_existing[0].id
  snet_server_id = var.vnet_new_or_existing == "new" ? azurerm_subnet.server[0].id : data.azurerm_subnet.server_existing[0].id

  vm_prefix       = "ns-vpx"
  nic_prefix      = "ns-vpx-nic"
  nsg_prefix      = "ns-vpx-nic-nsg"
  lb_name         = "internal-lb"
  be_pool         = "bepool-11"
  probe_name      = "probe-11"
  ipconf_name     = "ipconf-11"
  mgmt_pip_suffix = "-mgmt-publicip"
}

# Storage-account voor boot diagnostics
resource "random_string" "sa_unique" {
  length  = 8
  upper   = false
  lower   = true
  numeric = true
}
resource "azurerm_storage_account" "sa" {
  name                     = "vpxha${random_string.sa_unique.result}"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Network Security Groups
resource "azurerm_network_security_group" "mgmt" {
  count               = 2
  name                = "${local.nsg_prefix}${count.index}-01"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "default-allow-ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.restricted_ssh_access_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "autoscale-daemon"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9001"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "client" {
  count               = 2
  name                = "${local.nsg_prefix}${count.index}-11"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-http-https-from-client"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "server" {
  count               = 2
  name                = "${local.nsg_prefix}${count.index}-12"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Public IP’s management (optioneel)
resource "azurerm_public_ip" "mgmt" {
  count               = var.assign_management_public_ip == "yes" ? 2 : 0
  name                = "${local.vm_prefix}${count.index}${local.mgmt_pip_suffix}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [tostring(count.index + 1)]
}

# Network Interfaces
resource "azurerm_network_interface" "mgmt" {
  count                          = 2
  name                           = "${local.nic_prefix}${count.index}-01"
  location                       = data.azurerm_resource_group.rg.location
  resource_group_name            = data.azurerm_resource_group.rg.name
  accelerated_networking_enabled = var.accelerated_networking_management
  # network_security_group_id      = azurerm_network_security_group.mgmt[count.index].id

  ip_configuration {
    name                          = "ipconfig01"
    subnet_id                     = local.snet_mgmt_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.assign_management_public_ip == "yes" ? azurerm_public_ip.mgmt[count.index].id : null
  }
}

resource "azurerm_network_interface" "client" {
  count                          = 2
  name                           = "${local.nic_prefix}${count.index}-11"
  location                       = data.azurerm_resource_group.rg.location
  resource_group_name            = data.azurerm_resource_group.rg.name
  accelerated_networking_enabled = var.accelerated_networking_client
  # network_security_group_id     = azurerm_network_security_group.client[count.index].id

  ip_configuration {
    name                          = "ipconfig11"
    subnet_id                     = local.snet_client_id
    private_ip_address_allocation = "Dynamic"
    # load_balancer_backend_address_pools_ids  = [azurerm_lb.internal.backend_address_pool[0].id]
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "client" {
  backend_address_pool_id = azurerm_lb_backend_address_pool.internal.id
  ip_configuration_name   = "testipconfiguration1"
  network_interface_id    = azurerm_network_interface.client.id

}

resource "azurerm_network_interface_security_group_association" "client" {
  network_interface_id      = azurerm_network_interface.client.id
  network_security_group_id = azurerm_network_security_group.client.id
}

resource "azurerm_network_interface" "server" {
  count                          = 2
  name                           = "${local.nic_prefix}${count.index}-12"
  location                       = data.azurerm_resource_group.rg.location
  resource_group_name            = data.azurerm_resource_group.rg.name
  accelerated_networking_enabled = var.accelerated_networking_server
  # network_security_group_id      = azurerm_network_security_group.server[count.index].id

  ip_configuration {
    name                          = "ipconfig12"
    subnet_id                     = local.snet_server_id
    private_ip_address_allocation = "Dynamic"
  }
}

# Internal Load Balancer
resource "azurerm_lb" "internal" {
  name                = local.lb_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = local.ipconf_name
    subnet_id                     = local.snet_client_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "internal" {
  loadbalancer_id = azurerm_lb.internal
  name            = local.be_pool
}

resource "azurerm_lb_probe" "internal" {
  loadbalancer_id     = azurerm_lb.internal
  name                = local.probe_name
  port                = 9000
  protocol            = "Tcp"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "internal" {
  loadbalancer_id                = azurerm_lb.internal
  name                           = "lbRule1"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  enable_floating_ip             = true
  frontend_ip_configuration_name = local.ipconf_name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.internal.id]
  probe_id                       = azurerm_lb_probe.internal
}

# Virtual Machines
resource "azurerm_virtual_machine" "vpx" {
  count                            = 2
  name                             = "${local.vm_prefix}${count.index}"
  location                         = data.azurerm_resource_group.rg.location
  resource_group_name              = data.azurerm_resource_group.rg.name
  vm_size                          = var.vm_size
  zones                            = [tostring(count.index + 1)]
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true

  network_interface_ids = [
    azurerm_network_interface.mgmt[count.index].id,
    azurerm_network_interface.client[count.index].id,
    azurerm_network_interface.server[count.index].id,
  ]

  os_profile {
    computer_name  = "${local.vm_prefix}${count.index}"
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data = base64encode(join("", [
      "\n<NS-PRE-BOOT-CONFIG>\n<NS-CONFIG>\n",
      "set systemparameter -promptString %u@%s\n",
      "add ha node 1 ${azurerm_network_interface.mgmt[count.index].ip_configuration[0].private_ip_address} -inc ENABLED\n",
      "add ns ip ${azurerm_network_interface.client[count.index].ip_configuration[0].private_ip_address} ${split("/", var.snet_address_prefix_11)[1]} -type SNIP\n",
      "add ns ip ${azurerm_network_interface.server[count.index].ip_configuration[0].private_ip_address} ${split("/", var.snet_address_prefix_12)[1]} -type SNIP\n",
      "set ns rpcNode ${azurerm_network_interface.mgmt[count.index].ip_configuration[0].private_ip_address} -password ${var.rpc_node_password} -secure YES\n",
      "set ns rpcNode ${azurerm_network_interface.mgmt[count.index == 0 ? 1 : 0].ip_configuration[0].private_ip_address} -password ${var.rpc_node_password} -secure YES\n",
      "set ns ip ${azurerm_network_interface.mgmt[count.index].ip_configuration[0].private_ip_address} -gui SECUREONLY\n",
      "</NS-CONFIG>\n</NS-PRE-BOOT-CONFIG>\n"
    ]))
  }

  plan {
    name      = var.vm_sku
    publisher = "citrix"
    product   = var.ADC_version
  }

  storage_image_reference {
    publisher = "citrix"
    offer     = var.ADC_version
    sku       = var.vm_sku
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.vm_prefix}${count.index}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  boot_diagnostics {
    enabled = false
    storage_uri = azurerm_storage_account.sa.primary_blob_endpoint
  }
}
