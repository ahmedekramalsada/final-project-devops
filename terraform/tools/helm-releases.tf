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

# SonarQube - Optimized for faster startup
# Note: Using community edition with embedded H2 database for simplicity
# For production, use external PostgreSQL
resource "helm_release" "sonarqube" {
  name             = "sonarqube"
  repository       = "https://sonarsource.github.io/helm-chart-sonarqube"
  chart            = "sonarqube"
  namespace        = "tooling"
  create_namespace = true
  version          = "10.2.0"  # More stable version
  timeout          = 1200      # Increased timeout (20 minutes)

  # Disable PostgreSQL dependency - use embedded H2 for demo/dev
  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  # Use embedded H2 database (simpler, faster startup)
  set {
    name  = "sonarProperties.sonar\\.jdbc\\.url"
    value = "jdbc:h2:tcp://127.0.0.1:9092/sonar"
  }

  set {
    name  = "sonarProperties.sonar\\.jdbc\\.username"
    value = "sonar"
  }

  set {
    name  = "sonarProperties.sonar\\.jdbc\\.password"
    value = "sonar"
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "sonarWebContext"
    value = "/sonarqube"
  }

  # Community edition (free)
  set {
    name  = "edition"
    value = "community"
  }

  # Resource configuration - optimized for t3.medium nodes
  set {
    name  = "resources.requests.memory"
    value = "1.5Gi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "resources.limits.memory"
    value = "3Gi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "1000m"
  }

  # Increase init container resources
  set {
    name  = "initContainers.resources.requests.memory"
    value = "512Mi"
  }

  set {
    name  = "initContainers.resources.limits.memory"
    value = "512Mi"
  }

  # Faster startup probes
  set {
    name  = "startupProbe.initialDelaySeconds"
    value = "60"
  }

  set {
    name  = "startupProbe.periodSeconds"
    value = "10"
  }

  set {
    name  = "livenessProbe.initialDelaySeconds"
    value = "120"
  }

  set {
    name  = "readinessProbe.initialDelaySeconds"
    value = "90"
  }

  # Disable monitoring for faster startup
  set {
    name  = "prometheusExporter.enabled"
    value = "false"
  }

  depends_on = [helm_release.nginx, time_sleep.wait_nginx]
}

# Wait for SonarQube to be fully ready
resource "time_sleep" "wait_sonarqube" {
  create_duration = "60s"
  depends_on      = [helm_release.sonarqube]
}
