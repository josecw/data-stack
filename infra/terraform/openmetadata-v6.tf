# Phase 6: Open Metadata - Enterprise Metadata Platform
# Provides data catalog, lineage, and governance

# ----------------------------------------------------------------------
# Namespaces
# ----------------------------------------------------------------------

resource "kubernetes_manifest" "openmetadata_namespace" {
  manifest = yamldecode(file("${path.module}/manifests/openmetadata/namespace.yaml"))
  depends_on = [module.eks]
}

# ----------------------------------------------------------------------
# Secrets
# ----------------------------------------------------------------------

# PostgreSQL password
resource "random_password" "openmetadata_postgresql" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "kubernetes_secret_v1" "openmetadata_postgresql" {
  metadata {
    name      = "openmetadata-postgresql-secret"
    namespace = "openmetadata"
  }

  data = {
    postgres-password = base64encode(random_password.openmetadata_postgresql.result)
    password         = base64encode(random_password.openmetadata_postgresql.result)
    username         = base64encode("openmetadata")
    database         = base64encode("openmetadata_db")
  }

  depends_on = [kubernetes_manifest.openmetadata_namespace]
}

# Elasticsearch password
resource "random_password" "openmetadata_elasticsearch" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "kubernetes_secret_v1" "openmetadata_elasticsearch" {
  metadata {
    name      = "openmetadata-elasticsearch-secret"
    namespace = "openmetadata"
  }

  data = {
    password = base64encode(random_password.openmetadata_elasticsearch.result)
  }

  depends_on = [kubernetes_manifest.openmetadata_namespace]
}

# Airflow Fernet key
resource "random_password" "airflow_fernet_key" {
  length  = 64
  special = true
}

resource "kubernetes_secret_v1" "airflow_fernet_key" {
  metadata {
    name      = "openmetadata-airflow-secret"
    namespace = "openmetadata"
  }

  data = {
    fernet-key = base64encode(random_password.airflow_fernet_key.result)
  }

  depends_on = [kubernetes_manifest.openmetadata_namespace]
}

# Airflow secret key
resource "random_password" "airflow_secret_key" {
  length  = 64
  special = true
}

resource "kubernetes_secret_v1" "airflow_secret_key" {
  metadata {
    name      = "openmetadata-airflow-secret"
    namespace = "openmetadata"
  }

  data = {
    secret-key = base64encode(random_password.airflow_secret_key.result)
  }

  depends_on = [kubernetes_manifest.openmetadata_namespace]
}

# OpenMetadata bot token
resource "random_password" "openmetadata_bot_token" {
  length           = 64
  special          = true
  override_special = "_-."
}

resource "kubernetes_secret_v1" "openmetadata_bot_token" {
  metadata {
    name      = "openmetadata-bot-secret"
    namespace = "openmetadata"
  }

  data = {
    bot-token = base64encode(random_password.openmetadata_bot_token.result)
  }

  depends_on = [kubernetes_manifest.openmetadata_namespace]
}

# ----------------------------------------------------------------------
# S3 Buckets (optional - use existing buckets)
# ----------------------------------------------------------------------

# Airflow DAGs and logs bucket
resource "aws_s3_bucket" "openmetadata_airflow" {
  count  = var.openmetadata_create_buckets ? 1 : 0

  bucket = "${var.name}-openmetadata-airflow-${var.deployment_id}"
  region = var.aws_region

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-openmetadata-airflow"
      Component = "OpenMetadata"
    }
  )
}

resource "aws_s3_bucket_versioning" "openmetadata_airflow" {
  count  = var.openmetadata_create_buckets ? 1 : 0

  bucket = aws_s3_bucket.openmetadata_airflow[0].id
}

# Backup bucket
resource "aws_s3_bucket" "openmetadata_backup" {
  count  = var.openmetadata_create_buckets ? 1 : 0

  bucket = "${var.name}-openmetadata-backup-${var.deployment_id}"
  region = var.aws_region

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-openmetadata-backup"
      Component = "OpenMetadata"
    }
  )
}

resource "aws_s3_bucket_versioning" "openmetadata_backup" {
  count  = var.openmetadata_create_buckets ? 1 : 0

  bucket = aws_s3_bucket.openmetadata_backup[0].id
}

resource "aws_s3_bucket_lifecycle_configuration" "openmetadata_backup" {
  count  = var.openmetadata_create_buckets ? 1 : 0

  bucket = aws_s3_bucket.openmetadata_backup[0].id

  rule {
    id      = "backup-lifecycle"
    enabled = true

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ----------------------------------------------------------------------
# EKS Pod Identity (IAM)
# ----------------------------------------------------------------------

# OpenMetadata Airflow Pod Identity - S3 access
module "openmetadata_airflow_pod_identity" {
  source  = "./modules/openmetadata_pod_identity"
  enabled = var.enable_open_metadata

  # EKS cluster
  cluster_name    = module.eks.cluster_name
  cluster_region  = var.aws_region

  # IAM role
  role_name       = "openmetadata-airflow-pod-identity"
  namespace       = "openmetadata"
  service_account = "openmetadata-airflow"

  # IAM policy (S3 access)
  policy_arns = concat(
    [
      var.openmetadata_airflow_bucket != "" ? aws_s3_bucket.openmetadata_airflow[0].arn : "",
      var.openmetadata_backup_bucket != "" ? aws_s3_bucket.openmetadata_backup[0].arn : "",
    ]
  )

  depends_on = [kubernetes_manifest.openmetadata_namespace]
}

# ----------------------------------------------------------------------
# Keycloak OIDC Client
# ----------------------------------------------------------------------

# Note: This should be created manually in Keycloak or via a separate module
# The client ID is "openmetadata" in the configured realm

# ----------------------------------------------------------------------
# ArgoCD Application
# ----------------------------------------------------------------------

# OpenMetadata ArgoCD application
resource "kubernetes_manifest" "openmetadata_argocd" {
  count = var.enable_open_metadata ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "openmetadata"
      namespace = "argocd"
    }
    spec = {
      project = "data-stack"
      source = {
        repoURL        = var.gitops_repo
        targetRevision  = "main"
        path           = "helm-charts/openmetadata"
        helm = {
          valueFiles = [
            "values-prod.yaml",
            "secrets-prod.yaml",
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "openmetadata"
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
    kubernetes_manifest.openmetadata_namespace,
    kubernetes_secret_v1.openmetadata_postgresql,
    kubernetes_secret_v1.openmetadata_elasticsearch,
    kubernetes_secret_v1.airflow_fernet_key,
    kubernetes_secret_v1.airflow_secret_key,
    kubernetes_secret_v1.openmetadata_bot_token,
    module.openmetadata_airflow_pod_identity,
  ]
}

# ----------------------------------------------------------------------
# Outputs
# ----------------------------------------------------------------------

output "openmetadata_namespace" {
  value = "openmetadata"
}

output "openmetadata_url" {
  value = "https://openmetadata.${var.hostname}"
}

output "openmetadata_airflow_url" {
  value = "https://openmetadata.${var.hostname}/airflow"
}

output "openmetadata_airflow_bucket" {
  value = var.openmetadata_create_buckets ? aws_s3_bucket.openmetadata_airflow[0].id : var.openmetadata_airflow_bucket
}

output "openmetadata_backup_bucket" {
  value = var.openmetadata_create_buckets ? aws_s3_bucket.openmetadata_backup[0].id : var.openmetadata_backup_bucket
}

output "openmetadata_postgresql_password" {
  value     = random_password.openmetadata_postgresql.result
  sensitive = true
}

output "openmetadata_elasticsearch_password" {
  value     = random_password.openmetadata_elasticsearch.result
  sensitive = true
}

output "openmetadata_bot_token" {
  value     = random_password.openmetadata_bot_token.result
  sensitive = true
}
