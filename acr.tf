resource "azurerm_container_registry" "acr" {
  count = var.acr_provision == true ? 1 : 0

  name                = var.acr_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location = (var.acr_custom_region != null ?
    var.acr_custom_region :
    data.azurerm_resource_group.rg.location
  )

  sku           = "Basic"
  admin_enabled = false

  tags = local.common_tags
}

# Service principal has to be owner of RG or at least User Acces Admnistrator over RG
resource "azurerm_role_assignment" "acr_aks_kubelet_identity_role_acr_pull" {
  count = (
    var.acr_provision == true &&
    var.aks_provision == true &&
    var.acr_grant_pull_role_to_aks == true
  ) ? 1 : 0

  scope                = azurerm_container_registry.acr[0].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks[0].kubelet_identity[0].object_id
}
