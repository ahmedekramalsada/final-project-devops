# =============================================================================
# AWS Load Balancer Controller - MUST be installed FIRST
# =============================================================================
# Initial wait for EKS cluster to be fully ready
resource "time_sleep" "wait_for_eks" {
  create_duration = "90s"
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"
  timeout    = 600
  wait       = true

  # Cluster configuration
  set {
    name  = "clusterName"
    value = data.terraform_remote_state.infrastructure.outputs.cluster_name
  }

  # CRITICAL: Do NOT create service account - we created it with IRSA annotation
  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  # Use the pre-created service account
  set {
    name  = "serviceAccount.name"
    value = local.lb_controller_sa_name
  }

  # Region configuration for AWS SDK
  set {
    name  = "region"
    value = var.aws_region
  }

  # VPC ID for the controller
  set {
    name  = "vpcId"
    value = data.terraform_remote_state.infrastructure.outputs.vpc_id
  }

  # Enable ingress class resource
  set {
    name  = "ingressClassConfig.default"
    value = "false"
  }

  # Resource limits for t3.medium nodes
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "resources.limits.memory"
    value = "512Mi"
  }

  # Replica count
  set {
    name  = "replicaCount"
    value = "1"
  }

  # Depends on the service account being ready with IAM propagation
  depends_on = [
    kubernetes_service_account.lb_controller,
    time_sleep.wait_iam_propagation
  ]
}

# Wait for AWS LB Controller to be fully ready and webhook operational
resource "time_sleep" "wait_lb_controller" {
  create_duration = "90s"
  depends_on      = [helm_release.aws_load_balancer_controller]
}

# =============================================================================
# NGINX Ingress Controller
# =============================================================================
resource "helm_release" "nginx" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.9.1"
  timeout          = 600
  wait             = true

  # Use NodePort type for internal load balancer setup
  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  # Disable metrics to save resources
  set {
    name  = "controller.metrics.enabled"
    value = "false"
  }

  # Resource optimization for t3.medium
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "512Mi"
  }

  # Publish service on all nodes
  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  # Health check configuration
  set {
    name  = "controller.healthCheckPath"
    value = "/healthz"
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    time_sleep.wait_lb_controller
  ]
}

# Wait for NGINX to be fully ready
resource "time_sleep" "wait_nginx" {
  create_duration = "60s"
  depends_on      = [helm_release.nginx]
}

# =============================================================================
# ArgoCD - GitOps Continuous Delivery
# =============================================================================
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "6.7.11"
  timeout          = 900
  wait             = true

  # Service configuration
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # Ingress path configuration for reverse proxy
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

  set {
    name  = "server.extraArgs[0]"
    value = "--basehref=/argocd"
  }

  set {
    name  = "server.extraArgs[1]"
    value = "--rootpath=/argocd"
  }

  # Resource optimization for controller
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "512Mi"
  }

  # Resource optimization for repo-server
  set {
    name  = "repoServer.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "repoServer.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "repoServer.resources.limits.memory"
    value = "512Mi"
  }

  # Resource optimization for applicationset-controller
  set {
    name  = "applicationSet.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "applicationSet.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "applicationSet.resources.limits.memory"
    value = "512Mi"
  }

  # Disable notifications to save resources
  set {
    name  = "notifications.enabled"
    value = "false"
  }

  depends_on = [
    helm_release.nginx,
    time_sleep.wait_nginx
  ]
}

# Wait for ArgoCD to be fully ready
resource "time_sleep" "wait_argocd" {
  create_duration = "60s"
  depends_on      = [helm_release.argocd]
}

# =============================================================================
# SonarQube - Community Edition with H2 Database
# =============================================================================
resource "helm_release" "sonarqube" {
  name             = "sonarqube"
  repository       = "https://sonarsource.github.io/helm-chart-sonarqube"
  chart            = "sonarqube"
  namespace        = "tooling"
  create_namespace = true
  version          = "10.2.1"
  timeout          = 1200
  wait             = false  # Don't wait - SonarQube takes too long to initialize

  # Disable embedded PostgreSQL, use H2 instead
  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  # H2 Database configuration (embedded, file-based)
  set {
    name  = "sonarProperties.sonar\\.jdbc\\.url"
    value = "jdbc:h2:file:/opt/sonarqube/data/h2;DB_CLOSE_ON_EXIT=-1"
  }

  set {
    name  = "sonarProperties.sonar\\.jdbc\\.username"
    value = "sonar"
  }

  set {
    name  = "sonarProperties.sonar\\.jdbc\\.password"
    value = "sonar"
  }

  # Web context for reverse proxy access
  set {
    name  = "sonarProperties.sonar\\.web\\.context"
    value = "/sonarqube"
  }

  # Service configuration
  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "service.port"
    value = "9000"
  }

  # Community edition (free)
  set {
    name  = "edition"
    value = "community"
  }

  # Resource allocation optimized for t3.medium nodes
  set {
    name  = "resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "resources.requests.memory"
    value = "1.5Gi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "1000m"
  }

  set {
    name  = "resources.limits.memory"
    value = "2.5Gi"
  }

  # Init container resources
  set {
    name  = "initContainers.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "initContainers.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "initContainers.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "initContainers.resources.limits.memory"
    value = "256Mi"
  }

  # Fix Elasticsearch max_map_count issue
  set {
    name  = "elasticsearch.configureNode"
    value = "false"
  }

  set {
    name  = "elasticsearch.bootstrapSysctl"
    value = "false"
  }

  # Liveness probe configuration
  set {
    name  = "livenessProbe.initialDelaySeconds"
    value = "180"
  }

  set {
    name  = "livenessProbe.periodSeconds"
    value = "30"
  }

  # Readiness probe configuration
  set {
    name  = "readinessProbe.initialDelaySeconds"
    value = "180"
  }

  set {
    name  = "readinessProbe.periodSeconds"
    value = "30"
  }

  # Startup probe configuration
  set {
    name  = "startupProbe.initialDelaySeconds"
    value = "120"
  }

  set {
    name  = "startupProbe.periodSeconds"
    value = "15"
  }

  set {
    name  = "startupProbe.failureThreshold"
    value = "30"
  }

  # Disable Prometheus exporter
  set {
    name  = "prometheusExporter.enabled"
    value = "false"
  }

  # Persistence for H2 database
  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = "5Gi"
  }

  depends_on = [
    helm_release.argocd,
    time_sleep.wait_argocd
  ]
}

# Wait for SonarQube initial startup
resource "time_sleep" "wait_sonarqube" {
  create_duration = "30s"
  depends_on      = [helm_release.sonarqube]
}
