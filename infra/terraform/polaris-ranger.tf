# Phase 5: Polaris + Ranger
# Polaris - Apache Iceberg Catalog (REST API)
# Ranger - Fine-grained authorization framework

# ----------------------------------------------------------------------
# Namespaces
# ----------------------------------------------------------------------

resource "kubernetes_manifest" "polaris_namespace" {
  manifest = yamldecode(file("${path.module}/manifests/polaris/namespace.yaml"))
  depends_on = [module.eks]
}

resource "kubernetes_manifest" "ranger_namespace" {
  manifest = yamldecode(file("${path.module}/manifests/ranger/namespace.yaml"))
  depends_on = [module.eks]
}

# ----------------------------------------------------------------------
# Secrets
# ----------------------------------------------------------------------

# Polaris PostgreSQL password
resource "random_password" "polaris_postgresql" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "kubernetes_secret_v1" "polaris_postgresql" {
  metadata {
    name      = "polaris-postgresql-secret"
    namespace = "polaris"
  }

  data = {
    postgres-password = base64encode(random_password.polaris_postgresql.result)
    password         = base64encode(random_password.polaris_postgresql.result)
    username         = base64encode("polaris")
    database         = base64encode("polaris")
  }

  depends_on = [kubernetes_manifest.polaris_namespace]
}

# Ranger PostgreSQL password
resource "random_password" "ranger_postgresql" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "kubernetes_secret_v1" "ranger_postgresql" {
  metadata {
    name      = "ranger-postgresql-secret"
    namespace = "ranger"
  }

  data = {
    postgres-password = base64encode(random_password.ranger_postgresql.result)
    password         = base64encode(random_password.ranger_postgresql.result)
    username         = base64encode("ranger")
    database         = base64encode("ranger")
  }

  depends_on = [kubernetes_manifest.ranger_namespace]
}

# Polaris OIDC client secret
resource "random_password" "polaris_oidc" {
  length           = 64
  special          = true
  override_special = "_-."
}

resource "kubernetes_secret_v1" "polaris_oidc" {
  metadata {
    name      = "polaris-oidc-secret"
    namespace = "polaris"
  }

  data = {
    client-id     = base64encode("polaris")
    client-secret = base64encode(random_password.polaris_oidc.result)
  }

  depends_on = [kubernetes_manifest.polaris_namespace]
}

# Ranger OIDC client secret
resource "random_password" "ranger_oidc" {
  length           = 64
  special          = true
  override_special = "_-."
}

resource "kubernetes_secret_v1" "ranger_oidc" {
  metadata {
    name      = "ranger-oidc-secret"
    namespace = "ranger"
  }

  data = {
    client-id     = base64encode("ranger")
    client-secret = base64encode(random_password.ranger_oidc.result)
  }

  depends_on = [kubernetes_manifest.ranger_namespace]
}

# Polaris root user credentials
resource "random_password" "polaris_root" {
  length           = 64
  special          = true
  override_special = "_-."
}

resource "kubernetes_secret_v1" "polaris_root" {
  metadata {
    name      = "polaris-root-secret"
    namespace = "polaris"
  }

  data = {
    root-client-id     = base64encode("root")
    root-client-secret = base64encode(random_password.polaris_root.result)
  }

  depends_on = [kubernetes_manifest.polaris_namespace]
}

# Ranger admin password
resource "random_password" "ranger_admin" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "kubernetes_secret_v1" "ranger_admin" {
  metadata {
    name      = "ranger-admin-secret"
    namespace = "ranger"
  }

  data = {
    admin-password = base64encode(random_password.ranger_admin.result)
  }

  depends_on = [kubernetes_manifest.ranger_namespace]
}

# Ranger LDAP bind password
resource "random_password" "ranger_ldap_bind" {
  length           = 64
  special          = true
  override_special = "_-."
}

resource "kubernetes_secret_v1" "ranger_ldap" {
  metadata {
    name      = "ranger-ldap-secret"
    namespace = "ranger"
  }

  data = {
    bind-password = base64encode(random_password.ranger_ldap_bind.result)
  }

  depends_on = [kubernetes_manifest.ranger_namespace]
}

# ----------------------------------------------------------------------
# EKS Pod Identity (IAM)
# ----------------------------------------------------------------------

# Polaris Pod Identity - S3 access for catalog storage
module "polaris_pod_identity" {
  source  = "./modules/polaris_pod_identity"
  enabled = var.polaris_enabled

  # EKS cluster
  cluster_name    = module.eks.cluster_name
  cluster_region  = var.aws_region

  # IAM role
  role_name       = "polaris-pod-identity"
  namespace       = "polaris"
  service_account = "polaris"

  # IAM policy (S3 access)
  policy_arns = [
    module.s3_bucket_personal.arn,
    module.s3_bucket_projects.arn,
    module.s3_bucket_public.arn,
  ]

  depends_on = [kubernetes_manifest.polaris_namespace]
}

# Ranger Pod Identity - S3 access for audit logs
module "ranger_pod_identity" {
  source  = "./modules/ranger_pod_identity"
  enabled = var.ranger_enabled

  # EKS cluster
  cluster_name    = module.eks.cluster_name
  cluster_region  = var.aws_region

  # IAM role
  role_name       = "ranger-pod-identity"
  namespace       = "ranger"
  service_account = "ranger"

  # IAM policy (S3 audit access)
  policy_arns = [
    module.s3_bucket_public.arn,
  ]

  depends_on = [kubernetes_manifest.ranger_namespace]
}

# ----------------------------------------------------------------------
# ArgoCD Applications
# ----------------------------------------------------------------------

# Polaris ArgoCD application
resource "kubernetes_manifest" "polaris_argocd" {
  count = var.polaris_enabled ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "polaris"
      namespace = "argocd"
    }
    spec = {
      project = "data-stack"
      source = {
        repoURL        = var.gitops_repo
        targetRevision  = "main"
        path           = "helm-charts/polaris"
        helm = {
          valueFiles = [
            "values-prod.yaml",
            "secrets-prod.yaml",
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "polaris"
      }
      syncPolicy = {
        automated = {
          prune     = true
          selfHeal  = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "PruneLast=true",
        ]
      }
    }
  }

  depends_on = [
    kubernetes_manifest.polaris_namespace,
    kubernetes_secret_v1.polaris_postgresql,
    kubernetes_secret_v1.polaris_oidc,
    kubernetes_secret_v1.polaris_root,
    module.polaris_pod_identity,
  ]
}

# Ranger ArgoCD application
resource "kubernetes_manifest" "ranger_argocd" {
  count = var.ranger_enabled ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "ranger"
      namespace = "argocd"
    }
    spec = {
      project = "data-stack"
      source = {
        repoURL        = var.gitops_repo
        targetRevision  = "main"
        path           = "helm-charts/ranger"
        helm = {
          valueFiles = [
            "values-prod.yaml",
            "secrets-prod.yaml",
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "ranger"
      }
      syncPolicy = {
        automated = {
          prune     = true
          selfHeal  = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "PruneLast=true",
        ]
      }
    }
  }

  depends_on = [
    kubernetes_manifest.ranger_namespace,
    kubernetes_secret_v1.ranger_postgresql,
    kubernetes_secret_v1.ranger_oidc,
    kubernetes_secret_v1.ranger_admin,
    kubernetes_secret_v1.ranger_ldap,
    module.ranger_pod_identity,
  ]
}

# ----------------------------------------------------------------------
# Outputs
# ----------------------------------------------------------------------

output "polaris_namespace" {
  value = "polaris"
}

output "ranger_namespace" {
  value = "ranger"
}

output "polaris_oidc_client_id" {
  value     = "polaris"
  sensitive = true
}

output "polaris_oidc_client_secret" {
  value     = random_password.polaris_oidc.result
  sensitive = true
}

output "polaris_root_credentials" {
  value = {
    client_id     = "root"
    client_secret = random_password.polaris_root.result
  }
  sensitive = true
}

output "ranger_admin_password" {
  value     = random_password.ranger_admin.result
  sensitive = true
}

output "polaris_url" {
  value = "https://polaris.${var.hostname}"
}

output "ranger_url" {
  value = "https://ranger.${var.hostname}"
}
