variable "existing_rg" {
  type        = string
  default     = "myexistingrg01"
  description = "Existing resoure group name; have to be created manually outside of terraform"
}

variable "extra_tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to be added to each resource"
}

variable "acr_provision" {
  type        = bool
  default     = true
  description = "Set to true to provision Azure Container Registry"
}

variable "acr_name" {
  type        = string
  default     = "myacr01"
  description = "Name of Azure Container Registry"
}

# https://github.com/claranet/terraform-azurerm-regions/blob/master/REGIONS.md#azure-regions-mapping-list
variable "acr_custom_region" {
  type        = string
  default     = null
  description = "Define region to create ACR in; by default ACR will be created in the same region as RG"
}

variable "acr_grant_pull_role_to_aks" {
  type        = bool
  default     = false
  description = "Grant role over ACR to allow to pull images by AKS identity"
}

variable "aks_provision" {
  type        = bool
  default     = true
  description = "Set to true to provision Azure Kubernetes Service (Cluster)"
}

variable "aks_name" {
  type        = string
  default     = "myaks01"
  description = "Name of AKS cluster; will be used also as DNS prefix"
}

variable "aks_custom_region" {
  type        = string
  default     = null
  description = "Define region to create AKS in; by default AKS will be created in the same region as RG"
}

variable "aks_managed_identity_name" {
  type    = string
  default = "myaks01_uami"
}

variable "aks_resources_rg_name" {
  type        = string
  default     = "myacr01_rg"
  description = "Name of resource group where AKS resources will be placed; will be created automatically"
}

variable "aks_outbound_type" {
  type        = string
  default     = "loadBalancer"
  description = "Use simple AKS setup with loadBalancer or define different outboundType: userAssignedNATGateway or userDefinedRouting"
}

variable "aks_api_server_subnetwork_id" {
  type    = string
  default = null
  validation {
    condition     = can(var.aks_outbound_type != "loadBalancer" && var.aks_api_server_subnetwork_id == null)
    error_message = "You need to provide ID of subnetwork, where nodes will be placed if you are using user managed output type for AKS"
  }
  description = "ID of subnetwork to use with AKS API server"
}

variable "aks_node_pool_subnetwork_id" {
  type    = string
  default = null
  validation {
    condition     = can(var.aks_outbound_type != "loadBalancer" && var.aks_node_pool_subnetwork_id == null)
    error_message = "You need to provide ID of subnetwork, where nodes will be placed if you are using user managed output type for AKS"
  }
  description = "ID of subnetwork to use with AKS nodes"
}

variable "aks_auth_ip_ranges" {
  type        = list(string)
  default     = []
  description = "IP range to be able to access Kubernetes (AKS) cluster API"
}

variable "aks_node_count" {
  type        = number
  default     = 1
  description = "Node count for default nodepool"
}

variable "aks_node_sku" {
  type        = string
  default     = "Standard_B2s"
  description = "Machine SKU for default nodepool"
}

variable "aks_enable_spot_node_pool" {
  type        = bool
  default     = false
  description = "Provision additional nodepools using cheap spot instances"
}

variable "aks_spot_node_pool_config" {
  type = object({
    name  = string
    sku   = string
    count = number
  })
  default = null
  description = "Configure spot node pool details"
}

variable "contapp_provision" {
  type        = bool
  default     = false
  description = "Provision Container Apps environment to install ingress-nginx"
}

variable "contapp_env_name" {
  type        = string
  default     = "mycontappenv01"
  description = "Name of Azure Container Apps environment"
}

variable "contapp_nginx_ingress_additional_params" {
  type        = map(string)
  default     = {}
  description = "Additional ingress-nginx params, to be declared during helm chart installation. WARNING, --set-string is used so everything will be parsed as a string."
}

variable "aks_enable_default_node_pool_autoscaling_to_zero" {
  type        = bool
  default     = false
  description = "Enable autoscaling for AKS default node pool to zero machines to reduce costs"
}

variable "aks_default_node_pool_autoscaling_to_zero_details" {
  type = object({
    days          = list(string)
    start_time_HH = number
    start_time_MM = number
    stop_time_HH  = number
    stop_time_MM  = number
    timezone      = string
  })
  default     = null
  description = "Configure default node pool autoscaling to reduce costs"
}

variable "aks_enable_spot_node_pool_autoscaling" {
  type        = bool
  default     = false
  description = "Enable autoscaling for AKS spot node pool to zero machines to reduce costs and ensure availability"
}

variable "aks_spot_node_pool_autoscaling_details" {
  type = object({
    days          = list(string)
    start_time_HH = number
    start_time_MM = number
    stop_time_HH  = number
    stop_time_MM  = number
    timezone      = string
    capacity      = number
  })
  default     = null
  description = "Configure spot node pool autoscaling to ensure required number of nodes and schedule"
}

variable "az_cli_path" {
  type        = string
  default     = "az"
  description = "Command or path to call azure-cli command in your local environment"
}

variable "provisioner_arm_client_secret" {
  type    = string
  default = null
  # Not required, bash is not expanding environment variables within provisioner
  #sensitive   = true
  validation {
    condition     = can(var.contapp_provision == true && var.provisioner_arm_client_secret == null)
    error_message = "Environment variable TF_VAR_provisioner_arm_client_secret is not set properly!"
  }
  description = "Service principal client secret to be used with local-exec provider"
}
