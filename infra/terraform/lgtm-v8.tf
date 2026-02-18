# Phase 8: LGTM Stack - Observability Platform
# Loki - Log aggregation system
# Grafana - Visualization and monitoring
# Tempo - Distributed tracing

# ----------------------------------------------------------------------
# Namespaces
# ----------------------------------------------------------------------

resource "kubernetes_manifest" "loki_namespace" {
  manifest = yamldecode(file("${path.module}/manifests/loki/namespace.yaml"))
  depends_on = [module.eks]
}

resource "kubernetes_manifest" "grafana_namespace" {
  manifest = yamldecode(file("${path.module}/manifests/grafana/namespace.yaml"))
  depends_on = [module.eks]
}

resource "kubernetes_manifest" "tempo_namespace" {
  manifest = yamldecode(file("${path.module}/manifests/tempo/namespace.yaml"))
  depends_on = [module.eks]
}

# ----------------------------------------------------------------------
# S3 Buckets
# ----------------------------------------------------------------------

# Loki S3 bucket for log storage
resource "aws_s3_bucket" "loki" {
  count  = var.lgtm_create_buckets ? 1 : 0

  bucket = "${var.name}-loki-${var.deployment_id}"
  region = var.aws_region

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-loki"
      Component = "LGTM"
      Service  = "Loki"
    }
  )
}

resource "aws_s3_bucket_versioning" "loki" {
  count  = var.lgtm_create_buckets ? 1 : 0

  bucket = aws_s3_bucket.loki[0].id
}

# Tempo S3 bucket for trace storage
resource "aws_s3_bucket" "tempo" {
  count  = var.lgtm_create_buckets ? 1 : 0

  bucket = "${var.name}-tempo-${var.deployment_id}"
  region = var.aws_region

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-tempo"
      Component = "LGTM"
      Service  = "Tempo"
    }
  )
}

resource "aws_s3_bucket_versioning" "tempo" {
  count  = var.lgtm_create_buckets ? 1 : 0

  bucket = aws_s3_bucket.tempo[0].id
}

# ----------------------------------------------------------------------
# Secrets
# ----------------------------------------------------------------------

# Grafana admin password
resource "random_password" "grafana_admin" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin-secret"
    namespace = "grafana"
  }

  data = {
    admin-password = base64encode(random_password.grafana_admin.result)
  }

  depends_on = [kubernetes_manifest.grafana_namespace]
}

# Grafana OIDC client secret
resource "random_password" "grafana_oidc" {
  length           = 64
  special          = true
  override_special = "_-."
}

resource "kubernetes_secret_v1" "grafana_oidc" {
  metadata {
    name      = "grafana-oidc-secret"
    namespace = "grafana"
  }

  data = {
    client-id     = base64encode("grafana")
    client-secret = base64encode(random_password.grafana_oidc.result)
  }

  depends_on = [kubernetes_manifest.grafana_namespace]
}

# ----------------------------------------------------------------------
# EKS Pod Identity (IAM)
# ----------------------------------------------------------------------

# Loki Pod Identity - S3 access for log storage
module "loki_pod_identity" {
  source  = "./modules/loki_pod_identity"
  enabled = var.enable_lgtm

  # EKS cluster
  cluster_name   = module.eks.cluster_name
  cluster_region = var.aws_region

  # IAM role
  role_name       = "loki-pod-identity"
  namespace       = "loki"
  service_account = "loki"

  # IAM policy (S3 access)
  policy_arns = concat(
    [
      var.loki_bucket != "" ? var.loki_bucket : aws_s3_bucket.loki[0].arn,
    ]
  )

  depends_on = [kubernetes_manifest.loki_namespace]
}

# Tempo Pod Identity - S3 access for trace storage
module "tempo_pod_identity" {
  source  = "./modules/tempo_pod_identity"
  enabled = var.enable_lgtm

  # EKS cluster
  cluster_name   = module.eks.cluster_name
  cluster_region = var.aws_region

  # IAM role
  role_name       = "tempo-pod-identity"
  namespace       = "tempo"
  service_account = "tempo"

  # IAM policy (S3 access)
  policy_arns = concat(
    [
      var.tempo_bucket != "" ? var.tempo_bucket : aws_s3_bucket.tempo[0].arn,
    ]
  )

  depends_on = [kubernetes_manifest.tempo_namespace]
}

# ----------------------------------------------------------------------
# ArgoCD Applications
# ----------------------------------------------------------------------

# Loki ArgoCD application
resource "kubernetes_manifest" "loki_argocd" {
  count = var.enable_lgtm ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "loki"
      namespace = "argocd"
    }
    spec = {
      project = "data-stack"
      source = {
        repoURL       = var.gitops_repo
        targetRevision = "main"
        path          = "helm-charts/loki"
        helm = {
          valueFiles = [
            "values-prod.yaml",
            "secrets-prod.yaml",
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "loki"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "PruneLast=true",
        ]
      }
    }
  }

  depends_on = [
    kubernetes_manifest.loki_namespace,
    module.loki_pod_identity,
  ]
}

# Grafana ArgoCD application
resource "kubernetes_manifest" "grafana_argocd" {
  count = var.enable_lgtm ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "grafana"
      namespace = "argocd"
    }
    spec = {
      project = "data-stack"
      source = {
        repoURL       = var.gitops_repo
        targetRevision = "main"
        path          = "helm-charts/grafana"
        helm = {
          valueFiles = [
            "values-prod.yaml",
            "secrets-prod.yaml",
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "grafana"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "PruneLast=true",
        ]
      }
    }
  }

  depends_on = [
    kubernetes_manifest.grafana_namespace,
    kubernetes_secret_v1.grafana_admin,
    kubernetes_secret_v1.grafana_oidc,
  ]
}

# Tempo ArgoCD application
resource "kubernetes_manifest" "tempo_argocd" {
  count = var.enable_lgtm ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "tempo"
      namespace = "argocd"
    }
    spec = {
      project = "data-stack"
      source = {
        repoURL       = var.gitops_repo
        targetRevision = "main"
        path          = "helm-charts/tempo"
        helm = {
          valueFiles = [
            "values-prod.yaml",
            "secrets-prod.yaml",
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "tempo"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "PruneLast=true",
        ]
      }
    }
  }

  depends_on = [
    kubernetes_manifest.tempo_namespace,
    module.tempo_pod_identity,
  ]
}

# ----------------------------------------------------------------------
# Outputs
# ----------------------------------------------------------------------

output "loki_namespace" {
  value = "loki"
}

output "grafana_namespace" {
  value = "grafana"
}

output "tempo_namespace" {
  value = "tempo"
}

output "loki_url" {
  value = "https://loki.${var.hostname}"
}

output "grafana_url" {
  value = "https://grafana.${var.hostname}"
}

output "tempo_url" {
  value = "https://tempo.${var.hostname}"
}

output "loki_bucket" {
  value = var.lgtm_create_buckets ? aws_s3_bucket.loki[0].id : var.loki_bucket
}

output "tempo_bucket" {
  value = var.lgtm_create_buckets ? aws_s3_bucket.tempo[0].id : var.tempo_bucket
}

output "grafana_admin_password" {
  value     = random_password.grafana_admin.result
  sensitive = true
}

output "grafana_oidc_client_id" {
  value     = "grafana"
  sensitive = true
}

output "grafana_oidc_client_secret" {
  value     = random_password.grafana_oidc.result
  sensitive = true
}
