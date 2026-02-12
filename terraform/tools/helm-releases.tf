# NGINX Ingress Controller
resource "helm_release" "nginx" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"
  timeout          = 600

  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}

resource "time_sleep" "wait_nginx" {
  create_duration = "30s"
  depends_on      = [helm_release.nginx]
}

# ArgoCD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "6.7.0"
  timeout          = 600

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "server.insecure"
    value = "true"
  }

  set {
    name  = "server.basehref"
    value = "/argocd"
  }

  set {
    name  = "server.rootpath"
    value = "/argocd"
  }

  depends_on = [helm_release.nginx, time_sleep.wait_nginx]
}

# SonarQube
resource "helm_release" "sonarqube" {
  name             = "sonarqube"
  repository       = "https://sonarsource.github.io/helm-chart-sonarqube"
  chart            = "sonarqube"
  namespace        = "tooling"
  create_namespace = true
  version          = "10.5.0"
  timeout          = 900

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "sonarProperties.sonar\\.web\\.context"
    value = "/sonarqube"
  }

  set {
    name  = "community.enabled"
    value = "true"
  }

  set {
    name  = "resources.requests.memory"
    value = "2Gi"
  }

  set {
    name  = "resources.limits.memory"
    value = "4Gi"
  }

  depends_on = [helm_release.nginx, time_sleep.wait_nginx]
}
