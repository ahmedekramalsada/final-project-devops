# =============================================================================
# TargetGroupBinding for NGINX Ingress
# =============================================================================
resource "kubectl_manifest" "nginx_tgb" {
  yaml_body = yamlencode({
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "nginx-tgb"
      namespace = "ingress-nginx"
    }
    spec = {
      serviceRef = {
        name = "nginx-ingress-ingress-nginx-controller"
        port = 80
      }
      targetGroupARN = data.terraform_remote_state.infrastructure.outputs.nlb_target_group_arn
      targetType     = "ip"
    }
  })

  depends_on = [
    helm_release.nginx,
    helm_release.aws_load_balancer_controller,
    time_sleep.wait_nginx
  ]
}

# =============================================================================
# Fetch Nexus credentials from Vault
# =============================================================================
data "vault_kv_secret_v2" "nexus" {
  mount = "kv"
  name  = "nexus"
}

# =============================================================================
# Nexus Docker registry secret for pulling images
# =============================================================================
resource "kubernetes_secret" "nexus_registry" {
  metadata {
    name      = "nexus-registry-secret"
    namespace = "default"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.nexus_url}:${var.nexus_docker_port}" = {
          username = data.vault_kv_secret_v2.nexus.data["username"]
          password = data.vault_kv_secret_v2.nexus.data["password"]
          auth     = base64encode("${data.vault_kv_secret_v2.nexus.data["username"]}:${data.vault_kv_secret_v2.nexus.data["password"]}")
        }
      }
    })
  }
}

# =============================================================================
# Ingress for ArgoCD
# =============================================================================
resource "kubectl_manifest" "argocd_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: argocd-ingress
      namespace: argocd
      annotations:
        nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
        nginx.ingress.kubernetes.io/rewrite-target: /$2
        nginx.ingress.kubernetes.io/use-regex: "true"
    spec:
      ingressClassName: nginx
      rules:
        - http:
            paths:
              - path: /argocd(/|$)(.*)
                pathType: ImplementationSpecific
                backend:
                  service:
                    name: argocd-server
                    port:
                      number: 80
  YAML

  depends_on = [
    helm_release.argocd,
    helm_release.nginx,
    time_sleep.wait_argocd
  ]
}

# =============================================================================
# Ingress for SonarQube
# =============================================================================
resource "kubectl_manifest" "sonarqube_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: sonarqube-ingress
      namespace: tooling
      annotations:
        nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
        nginx.ingress.kubernetes.io/rewrite-target: /sonarqube/$2
        nginx.ingress.kubernetes.io/use-regex: "true"
    spec:
      ingressClassName: nginx
      rules:
        - http:
            paths:
              - path: /sonarqube(/|$)(.*)
                pathType: ImplementationSpecific
                backend:
                  service:
                    name: sonarqube-sonarqube
                    port:
                      number: 9000
  YAML

  depends_on = [
    helm_release.sonarqube,
    helm_release.nginx,
    time_sleep.wait_sonarqube
  ]
}

# =============================================================================
# ArgoCD Application for DevOps App
# =============================================================================
resource "kubectl_manifest" "argocd_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "devops-app"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repo_url
        targetRevision = "main"
        path           = "k8s/app"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })

  depends_on = [
    helm_release.argocd,
    time_sleep.wait_argocd
  ]
}
