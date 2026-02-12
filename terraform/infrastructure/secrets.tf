# Fetch app secrets from Vault (MongoDB URI, Datadog keys)
data "vault_kv_secret_v2" "app" {
  mount = "kv"
  name  = "app"
}

# Create Kubernetes secret for app (MongoDB connection, Datadog)
resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "app-secrets"
    namespace = "default"
  }

  data = {
    mongodb_uri    = data.vault_kv_secret_v2.app.data["mongodb_uri"]
    datadog_api_key = try(data.vault_kv_secret_v2.app.data["datadog_api_key"], "")
  }

  type = "Opaque"

  depends_on = [time_sleep.wait_eks]
}
