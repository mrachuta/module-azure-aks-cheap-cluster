locals {
  common_tags = merge(
    {
      "managed_by"  = "terraform"
      "module_name" = "azure-aks-cheap-cluster"
    },
    var.extra_tags
  )
}
