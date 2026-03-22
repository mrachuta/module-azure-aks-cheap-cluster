resource "azurerm_user_assigned_identity" "aks_managed_identity" {
  name                = "${var.aks_name}-aks-uami"
  resource_group_name = data.azurerm_resource_group.rg.name
  location = (var.aks_custom_region != null ?
    var.aks_custom_region :
    data.azurerm_resource_group.rg.location
  )
}

# Role is required to create network connections
resource "azurerm_role_assignment" "aks_managed_identity_role_network_contributor" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_managed_identity.principal_id
}

resource "azurerm_kubernetes_cluster" "aks" {
  count = var.aks_provision == true ? 1 : 0

  name                = var.aks_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location = (var.aks_custom_region != null ?
    var.aks_custom_region :
    data.azurerm_resource_group.rg.location
  )
  tags = local.common_tags

  dns_prefix          = var.aks_name
  sku_tier            = "Free"
  node_resource_group = var.aks_resources_rg_name

  disk_encryption_set_id = var.aks_disk_encryption_set_id

  network_profile {
    network_plugin    = var.aks_outbound_type == "loadBalancer" ? "kubenet" : "azure"
    load_balancer_sku = var.aks_outbound_type == "loadBalancer" ? "standard" : null
    service_cidr      = var.aks_outbound_type == "loadBalancer" ? null : "172.29.0.0/16"
    dns_service_ip    = var.aks_outbound_type == "loadBalancer" ? null : "172.29.0.10"
    outbound_type     = var.aks_outbound_type
  }

  dynamic "api_server_access_profile" {
    for_each = (
      length(var.aks_auth_ip_ranges) > 0
    ) ? [1] : [0]
    content {
      authorized_ip_ranges                = var.aks_auth_ip_ranges
      virtual_network_integration_enabled = var.aks_outbound_type == "loadBalancer" ? null : true
      subnet_id                           = var.aks_outbound_type == "loadBalancer" ? null : var.aks_api_server_subnetwork_id
    }
  }

  default_node_pool {
    name                        = "defaultnp"
    temporary_name_for_rotation = "defaultnptmp"
    node_count                  = var.aks_node_count
    vm_size                     = var.aks_node_sku
    os_disk_size_gb             = 32
    os_disk_type                = "Managed"
    auto_scaling_enabled        = false
    vnet_subnet_id              = var.aks_outbound_type == "loadBalancer" ? null : var.aks_node_pool_subnetwork_id
    tags = merge(
      local.common_tags,
      {
        "node_pool_autoscale_tag" = "${var.aks_name}-default-node-pool"
      },
      var.aks_nodes_extra_tags
    )

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_managed_identity.id]
  }

  depends_on = [azurerm_role_assignment.aks_managed_identity_role_network_contributor]
}

resource "azurerm_kubernetes_cluster_node_pool" "aks_spot_node_pool" {
  count = (
    var.aks_provision == true &&
    var.aks_enable_spot_node_pool == true &&
    var.aks_spot_node_pool_config != null
  ) ? 1 : 0

  name                        = var.aks_spot_node_pool_config.name
  temporary_name_for_rotation = "${var.aks_spot_node_pool_config.name}tmp"
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.aks[0].id
  vm_size                     = var.aks_spot_node_pool_config.sku
  node_count                  = var.aks_spot_node_pool_config.count
  auto_scaling_enabled        = false
  priority                    = "Spot"
  os_disk_size_gb             = "32"
  vnet_subnet_id              = var.aks_node_pool_subnetwork_id
  tags = merge(
    local.common_tags,
    {
      "node_pool_autoscale_tag" = "${var.aks_name}-${var.aks_spot_node_pool_config.name}"
    },
    var.aks_nodes_extra_tags
  )

  lifecycle {
    ignore_changes = [eviction_policy, node_taints]
  }
}

# TODO: to be fixed
# # Get loadbalancer
# data "azurerm_lb" "aks_loadbalancer" {
#   count = (
#     var.provision_aks == true &&
#     var.enable_aks_default_node_pool_autoscaling_to_zero == true
#   ) ? 1 : 0

#   name                = "kubernetes"
#   resource_group_name = var.aks_resources_rg_name

#   depends_on = [
#     azurerm_kubernetes_cluster.aks,
#     null_resource.run_aks_config_job
#   ]
# }

# # Get loadbalancer external IP address
# data "azurerm_public_ip" "aks_loadbalancer_ip" {
#   count = (
#     var.provision_aks == true &&
#     var.enable_aks_default_node_pool_autoscaling_to_zero == true
#   ) ? 1 : 0

#   name                = basename(data.azurerm_lb.aks_loadbalancer[0].frontend_ip_configuration[0].public_ip_address_id)
#   resource_group_name = var.aks_resources_rg_name
# }

# Get default's nodepool vmss

data "azurerm_resources" "aks_default_node_pool" {
  count = (
    var.aks_provision == true &&
    var.aks_enable_default_node_pool_autoscaling_to_zero == true
  ) ? 1 : 0

  resource_group_name = var.aks_resources_rg_name
  type                = "Microsoft.Compute/virtualMachineScaleSets"
  required_tags = merge(
    local.common_tags,
    {
      "node_pool_autoscale_tag" = "${var.aks_name}-default-node-pool"
    }
  )

  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "azurerm_monitor_autoscale_setting" "aks_default_node_pool_autoscaler" {
  count = (
    var.aks_provision == true &&
    var.aks_enable_default_node_pool_autoscaling_to_zero == true &&
    var.aks_default_node_pool_autoscaling_to_zero_details != null
  ) ? 1 : 0

  name                = "${var.aks_name}-default-node-pool-autoscaler"
  resource_group_name = azurerm_kubernetes_cluster.aks[0].node_resource_group
  location            = azurerm_kubernetes_cluster.aks[0].location
  tags                = local.common_tags

  target_resource_id = data.azurerm_resources.aks_default_node_pool[0].resources[0].id

  profile {
    name = "inactiveProfile"

    capacity {
      default = 0
      minimum = 0
      maximum = 0
    }

    recurrence {
      timezone = var.aks_default_node_pool_autoscaling_to_zero_details.timezone
      days     = var.aks_default_node_pool_autoscaling_to_zero_details.days
      hours    = [var.aks_default_node_pool_autoscaling_to_zero_details.stop_time_HH]
      minutes  = [var.aks_default_node_pool_autoscaling_to_zero_details.stop_time_MM]
    }
  }

  profile {
    name = "activeProfile"

    capacity {
      default = var.aks_node_count
      minimum = var.aks_node_count
      maximum = var.aks_node_count
    }

    recurrence {
      timezone = var.aks_default_node_pool_autoscaling_to_zero_details.timezone
      days     = var.aks_default_node_pool_autoscaling_to_zero_details.days
      hours    = [var.aks_default_node_pool_autoscaling_to_zero_details.start_time_HH]
      minutes  = [var.aks_default_node_pool_autoscaling_to_zero_details.start_time_MM]
    }
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Get spoot's nodepool vmss
data "azurerm_resources" "aks_spot_node_pool" {
  count = (
    var.aks_provision == true &&
    var.aks_enable_spot_node_pool == true &&
    var.aks_enable_spot_node_pool_autoscaling == true &&
    var.aks_spot_node_pool_autoscaling_details != null
  ) ? 1 : 0

  resource_group_name = var.aks_resources_rg_name
  type                = "Microsoft.Compute/virtualMachineScaleSets"
  required_tags = merge(
    local.common_tags,
    {
      "node_pool_autoscale_tag" = "${var.aks_name}-${var.aks_spot_node_pool_config.name}"
    }
  )

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_kubernetes_cluster_node_pool.aks_spot_node_pool
  ]
}

resource "azurerm_monitor_autoscale_setting" "aks_spot_node_pool_autoscaler" {
  count = (
    var.aks_provision == true &&
    var.aks_enable_spot_node_pool_autoscaling == true &&
    var.aks_spot_node_pool_autoscaling_details != null &&
    var.aks_spot_node_pool_config != null
  ) ? 1 : 0

  name                = "${var.aks_name}-${var.aks_spot_node_pool_config.name}-autoscaler"
  resource_group_name = azurerm_kubernetes_cluster.aks[0].node_resource_group
  location            = azurerm_kubernetes_cluster.aks[0].location
  tags                = local.common_tags

  target_resource_id = data.azurerm_resources.aks_spot_node_pool[0].resources[0].id

  profile {
    name = "inactiveProfile"

    capacity {
      default = 0
      minimum = 0
      maximum = 0
    }

    recurrence {
      timezone = var.aks_spot_node_pool_autoscaling_details.timezone
      days     = var.aks_spot_node_pool_autoscaling_details.days
      hours    = [var.aks_spot_node_pool_autoscaling_details.stop_time_HH]
      minutes  = [var.aks_spot_node_pool_autoscaling_details.stop_time_MM]
    }
  }

  profile {
    name = "activeProfile"

    capacity {
      default = var.aks_spot_node_pool_autoscaling_details.capacity
      minimum = var.aks_spot_node_pool_autoscaling_details.capacity
      maximum = var.aks_spot_node_pool_autoscaling_details.capacity
    }

    recurrence {
      timezone = var.aks_spot_node_pool_autoscaling_details.timezone
      days     = var.aks_spot_node_pool_autoscaling_details.days
      hours    = [var.aks_spot_node_pool_autoscaling_details.start_time_HH]
      minutes  = [var.aks_spot_node_pool_autoscaling_details.start_time_MM]
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_kubernetes_cluster_node_pool.aks_spot_node_pool
  ]
}
