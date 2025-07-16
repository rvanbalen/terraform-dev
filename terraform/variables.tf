variable "primary_location" {
  type    = string
  default = "westeurope"
}

variable "subscription_id_management" {
  type        = string
  description = "Subscription ID to be used for resources"
}

variable "prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "publisher" {
  type = string
  description = "Image publisher"
  default = "MicrosoftWindowsDesktop"
}

variable "offer" {
  type = string
  description = "Image offer"
  default = "office-365"
}

variable "sku" {
  type = string
  description = "Image SKU"
  default = "win11-24h2-avd-m365"
}

variable "image_replication_regions" {
  type        = string
  description = "Image replication regions"
}

variable "aib_region" {
  type        = string
  description = "Image builder region"
}

variable "aib_api_version" {
  type        = string
  description = "Image builder API version"
  default     = "2020-02-14"
}