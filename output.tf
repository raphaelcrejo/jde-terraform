resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.aks-lab-jde]
  filename   = "kubeconfig.yaml"
  content    = azurerm_kubernetes_cluster.aks-lab-jde.kube_config_raw
}