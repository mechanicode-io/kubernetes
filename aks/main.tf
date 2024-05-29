resource "random_pet" "prefix" {}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.90"
    }
  }
}

provider "azurerm" {
  features {

    resource_group {
      prevent_deletion_if_contains_resources = true
    }

    key_vault {
      recover_soft_deleted_key_vaults = true
      purge_soft_delete_on_destroy = true
    }
  }

  storage_use_azuread = true
}

data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "aks_rg" {
  name     = "cdc-coe-twhite-${random_pet.prefix.id}-rg"
  location = var.location

  tags = {
    owner       = var.owner
    environment = var.environment
    costCenter  = var.costCenter
  }
}

resource "azurerm_virtual_network" "vnet_cluster" {
  name                = "vnet-aks-${random_pet.prefix.id}"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "snet_cluster" {
  name                 = "snet-aks-${random_pet.prefix.id}"
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.vnet_cluster.name
  address_prefixes     = ["10.1.0.0/24"]
  private_endpoint_network_policies = "Enabled"  // will be deprcated
}

##
# Create Vnet and subnet for the Bastion VM
##
resource "azurerm_virtual_network" "vnet_bastion" {
  name                = "vnet-bastion-${random_pet.prefix.id}"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "snet_bastion_vm" {
  name                 = "snet-bastion-${random_pet.prefix.id}"
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.vnet_bastion.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "snet_azure_bastion_service" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.vnet_bastion.name
  address_prefixes     = ["10.0.1.0/24"]
}

##
# Create Vnet peering for the bastion VM to be able to access the cluster Vnet and IPs
##
resource "azurerm_virtual_network_peering" "peering_bastion_cluster" {
  name                      = "peering_bastion_cluster"
  resource_group_name       = azurerm_resource_group.aks_rg.name
  virtual_network_name      = azurerm_virtual_network.vnet_bastion.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_cluster.id
}

resource "azurerm_virtual_network_peering" "peering_cluster_bastion" {
  name                      = "peering_cluster_bastion"
  resource_group_name       = azurerm_resource_group.aks_rg.name
  virtual_network_name      = azurerm_virtual_network.vnet_cluster.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_bastion.id
}

##
# Create the AKS Cluster
##
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${random_pet.prefix.id}"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "aks-cluster"
  private_cluster_enabled = true
  role_based_access_control_enabled = true

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.snet_cluster.id
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }
    tags = {
    owner       = var.owner
    environment = var.environment
    costCenter  = var.costCenter
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "worker" {
  name                = "worker"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size             = "Standard_D2_v2"
  node_count          = 2
  os_disk_size_gb     = 30
    tags = {
    owner       = var.owner
    environment = var.environment
    costCenter  = var.costCenter
  }
}

##
# Link the Bastion Vnet to the Private DNS Zone generated to resolve the Server IP from the URL in Kubeconfig
##
resource "azurerm_private_dns_zone_virtual_network_link" "link_bastion_cluster" {
  name = "dnslink-bastion-cluster"
  private_dns_zone_name = join(".", slice(split(".", azurerm_kubernetes_cluster.aks.private_fqdn), 1, length(split(".", azurerm_kubernetes_cluster.aks.private_fqdn))))
  resource_group_name   = "MC_${azurerm_resource_group.aks_rg.name}_${azurerm_kubernetes_cluster.aks.name}_eastus"
  virtual_network_id    = azurerm_virtual_network.vnet_bastion.id
}

##
# Create a Bastion VM
##
resource "azurerm_network_interface" "bastion_nic" {
  name                = "nic-bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_bastion_vm.id
    private_ip_address_allocation = "Dynamic"
  }
    tags = {
    owner       = var.owner
    environment = var.environment
    costCenter  = var.costCenter
  }
}

resource "tls_private_key" "ubn_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "template_cloudinit_config" "vm_ubn_01" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = file("${path.module}/scripts/cloud-init.yaml")
  }
}

resource "azurerm_linux_virtual_machine" "vm_ubn_01" {
  name                            = "cdc-coe-${random_pet.prefix.id}-vm-ubn-01"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.aks_rg.name
  size                            = "Standard_D2_v2"
  computer_name                   = var.computer_name
  admin_username                  = var.admin_username
  disable_password_authentication = true
  custom_data                     = data.template_cloudinit_config.vm_ubn_01.rendered
  network_interface_ids           = [azurerm_network_interface.bastion_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "cloudmin"
    public_key = tls_private_key.ubn_ssh.public_key_openssh
  }

  tags = {
    owner       = var.owner
    environment = var.environment
    costCenter  = var.costCenter
  }
}

##
# Create an Azure Bastion Service to access the Bastion VM
##
resource "azurerm_public_ip" "pip_azure_bastion" {
  name                = "pip-azure-bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  allocation_method = "Static"
  sku               = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                  = "azure-bastion"
  location              = var.location
  resource_group_name   = azurerm_resource_group.aks_rg.name
  sku                   = "Standard"
  scale_units           = 2

  copy_paste_enabled     = true
  file_copy_enabled      = true
  shareable_link_enabled = true
  tunneling_enabled      = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.snet_azure_bastion_service.id
    public_ip_address_id = azurerm_public_ip.pip_azure_bastion.id
  }

  tags = {
    owner       = var.owner
    environment = var.environment
    costCenter  = var.costCenter
  }
}