# General info

Terraform module for creating Azure Container Registry, Azure Kubernertes Service and additional helper objects. 
The idea behind this module is to bring as cheapest as possible Kubernetes stack in cloud.
Personally I am using region Central India and Standard_B2als_v2 VM (1 machine) because of best price/capacity ratio.
Main features are:
* module is able to provision ACR and AKS
* option to chose between Outbound Connection metho for AKS (`loadBalancer` as default mode and `userAssignedNatGateway`/ `userDefinedRouting` for clusters inside private network)
* scaling default node pool to 0 machines to save budget
* option to use additional spot node pool that is very cheap
* preconfiguration of cluster using Azure Container App

# Requirements

* *az-cli* installed in latest version
* Registered providers:
  ```
  az provider register --namespace Microsoft.Storage
  az provider register --namespace Microsoft.ContainerService
  az provider register --namespace Microsoft.Kubernetes
  az provider register --namespace Microsoft.ContainerRegistry
  az provider register --namespace Microsoft.ManagedIdentity
  az provider register --namespace Microsoft.App
  az provider register --namespace Microsft.Insights
  ```

# Usage

See *variables.tf* file for required / optional variables
