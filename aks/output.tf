resource "null_resource" "create_ssh_key" {
  provisioner "local-exec" {
    command = "echo '${tls_private_key.ubn_ssh.private_key_pem}' > ~/.ssh/aks/${azurerm_kubernetes_cluster.aks.name}.pem && chmod 600 ~/.ssh/aks/${azurerm_kubernetes_cluster.aks.name}.pem"
  }

  triggers = {
    timestamp = timestamp()
  }
}

output "ssh_via_bastion_command" {
  value = <<-EOT
    # Ensure SSH private key file is created
    ${null_resource.create_ssh_key.triggers["timestamp"]}

    # Run Azure CLI command to SSH via Bastion
    az network bastion ssh \
      --name ${azurerm_bastion_host.bastion.name} \
      --resource-group ${azurerm_resource_group.aks_rg.name} \
      --target-resource-id "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${azurerm_resource_group.aks_rg.name}/providers/Microsoft.Compute/virtualMachines/${azurerm_linux_virtual_machine.vm_ubn_01.name}" \
      --auth-type "ssh-key" \
      --username cloudmin \
      --ssh-key "~/.ssh/aks/${azurerm_kubernetes_cluster.aks.name}.pem"
  EOT
}