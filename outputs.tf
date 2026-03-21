output "rg_id" {
  value = data.azurerm_resource_group.rg.id
}

output "acr_address" {
  value = var.acr_provision == true ? azurerm_container_registry.acr[0].login_server : null
}

output "aks_cluster_name" {
  value = var.acr_provision == true ? azurerm_kubernetes_cluster.aks[0].name : null
}

# TODO: to be fixed
# output "aks_loadbalancer_ip" {
#   value = var.provision_aks == true ? data.azurerm_public_ip.aks_loadbalancer_ip[0].ip_address : null
# }
