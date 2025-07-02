# variables.tf

variable "resource_group_name" {
  description = "Naam van de bestaande resource group voor deze deployment."
  type        = string
}

variable "admin_username" {
  type        = string
  description = "Username for the Virtual Machines."
}

variable "admin_password" {
  type        = string
  description = "Password for the Virtual Machines."
  sensitive   = true
}

variable "rpc_node_password" {
  type        = string
  description = "Password for the RPC Node."
  sensitive   = true
}

variable "vm_size" {
  type        = string
  default     = "Standard_D8s_v4"
  description = "Size of Citrix ADC VPX Virtual Machine."
}

variable "ADC_version" {
  type        = string
  default     = "netscalervpx-141"
  description = "Citrix ADC Version."
  validation {
    condition     = contains(["netscalervpx-141", "netscalervpx-131", "netscalervpx-130"], var.ADC_version)
    error_message = "ADC_version must be one of: netscalervpx-141, netscalervpx-131, netscalervpx-130."
  }
}

variable "vm_sku" {
  type        = string
  default     = "netscalerbyol"
  description = "SKU of Citrix ADC Image."
  validation {
    condition     = var.vm_sku == "netscalerbyol"
    error_message = "vm_sku must be 'netscalerbyol'."
  }
}

variable "vnet_name" {
  type        = string
  default     = "vnet01"
  description = "Name of Virtual Network."
}

variable "vnet_resource_group" {
  type        = string
  default     = ""
  description = "Resource Group of existing Virtual Network. Leave empty if same as deployment RG."
}

variable "vnet_new_or_existing" {
  type        = string
  default     = "new"
  description = "Create a new VNet or use existing. 'new' or 'existing'."
  validation {
    condition     = contains(["new", "existing"], var.vnet_new_or_existing)
    error_message = "vnet_new_or_existing must be 'new' or 'existing'."
  }
}

variable "snet_name_01" {
  type        = string
  default     = "subnet_mgmt"
  description = "Management subnet name."
}

variable "snet_name_11" {
  type        = string
  default     = "subnet_client"
  description = "Client subnet name."
}

variable "snet_name_12" {
  type        = string
  default     = "subnet_server"
  description = "Server subnet name."
}

variable "snet_address_prefix_01" {
  type        = string
  default     = "10.11.0.0/24"
  description = "Management subnet CIDR."
}
variable "snet_address_prefix_11" {
  type        = string
  default     = "10.11.1.0/24"
  description = "Client subnet CIDR."
}
variable "snet_address_prefix_12" {
  type        = string
  default     = "10.11.2.0/24"
  description = "Server subnet CIDR."
}

variable "accelerated_networking_management" {
  type        = bool
  default     = true
  description = "Enable accelerated networking on management NIC."
}
variable "accelerated_networking_client" {
  type        = bool
  default     = true
  description = "Enable accelerated networking on client NIC."
}
variable "accelerated_networking_server" {
  type        = bool
  default     = true
  description = "Enable accelerated networking on server NIC."
}

variable "restricted_ssh_access_cidr" {
  type        = string
  description = "Allowed SSH CIDR(s) for management interface."
}

variable "assign_management_public_ip" {
  type        = string
  default     = "yes"
  description = "Enable public IP for management interface. 'yes' or 'no'."
  validation {
    condition     = contains(["yes", "no"], var.assign_management_public_ip)
    error_message = "assign_management_public_ip must be 'yes' or 'no'."
  }
}
