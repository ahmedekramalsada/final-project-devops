# =============================================================================
# TargetGroupBinding for NGINX Ingress Controller
# =============================================================================
# This binds the NLB target group to the NGINX ingress service
# CRITICAL: AWS LB Controller must be fully operational with working IRSA
# =============================================================================

# Additional wait for AWS LB Controller webhook to be fully operational
# The webhook needs time to register with the Kubernetes API server
resource "time_sleep" "wait_lb_controller_webhook" {
  create_duration = "60s"
  depends_on      = [time_sleep.wait_lb_controller]
}

# Verify LB Controller is ready before creating TargetGroupBinding
resource "null_resource" "verify_lb_controller" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "Waiting for AWS Load Balancer Controller webhook to be ready..."
      for i in {1..30}; do
        if kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
          echo "LB Controller pod is running"
          break
        fi
        echo "Waiting for LB Controller pod... ($i/30)"
        sleep 5
      done
      sleep 30
      echo "LB Controller should be ready now"
    EOT
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    time_sleep.wait_lb_controller_webhook
  ]
}

# TargetGroupBinding for NGINX - connects NLB to nginx service
resource "kubectl_manifest" "nginx_tgb" {
  yaml_body = yamlencode({
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "nginx-tgb"
      namespace = "ingress-nginx"
      annotations = {
        "elbv2.k8s.aws/target-group-ownership" = "owned"
      }
    }
    spec = {
      serviceRef = {
        name = "nginx-ingress-ingress-nginx-controller"
        port = 80
      }
      targetGroupARN = data.terraform_remote_state.infrastructure.outputs.nlb_target_group_arn
      targetType     = "ip"
      networking = {
        ingress = [{
          from = [{
            securityGroup = {
              groupID = data.terraform_remote_state.infrastructure.outputs.node_security_group_id
            }
          }]
          ports = [{
            port     = 80
            protocol = "TCP"
          }]
        }]
      }
    }
  })

  depends_on = [
    helm_release.nginx,
    helm_release.aws_load_balancer_controller,
    time_sleep.wait_nginx,
    time_sleep.wait_lb_controller_webhook,
    null_resource.verify_lb_controller,
    kubernetes_service_account.lb_controller
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
# Nexus Docker Registry Secret for Image Pulling
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
        nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
        nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
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
        nginx.ingress.kubernetes.io/proxy-body-size: "50m"
        nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
        nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
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
