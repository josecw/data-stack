locals {
  open_metadata_namespace       = "open-metadata"
  open_metadata_service_account = "open-metadata-sa"

  open_metadata_values = templatefile("${path.module}/helm-values/open-metadata.yaml", {
  })

  opensearch_open_metadata_values = templatefile("${path.module}/helm-values/opensearch-open-metadata.yaml", {})

  open_metadata_postgresql_manifests = provider::kubernetes::manifest_decode_multi(
    templatefile("${path.module}/manifests/open-metadata/postgresql.yaml", {
      namespace = local.open_metadata_namespace
    })
  )
}

#---------------------------------------------------------------
# Pod Identity for OpenMetadata S3/Glue Access
#---------------------------------------------------------------
module "open_metadata_pod_identity" {
  count   = var.enable_open_metadata ? 1 : 0
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name = "open-metadata"

  additional_policy_arns = {
    s3_glue_access = aws_iam_policy.open_metadata_s3_glue[0].arn
  }

  associations = {
    open_metadata = {
      cluster_name    = module.eks.cluster_name
      namespace       = local.open_metadata_namespace
      service_account = local.open_metadata_service_account
    }
  }
}

#---------------------------------------------------------------
# IAM Policy for S3 and Glue Access
#---------------------------------------------------------------
resource "aws_iam_policy" "open_metadata_s3_glue" {
  count       = var.enable_open_metadata ? 1 : 0
  name        = "open-metadata-s3-glue-policy"
  description = "IAM Policy for OpenMetadata S3 and Glue access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetObjectVersion"
        ]
        Resource = [
          module.s3_bucket.s3_bucket_arn,
          "${module.s3_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "glue:GetDatabases",
          "glue:GetDatabase",
          "glue:GetTables",
          "glue:GetTable"
        ],
        Resource = ["*"]
      }
    ]
  })
}


#---------------------------------------------------------------
# OpenMetadata Namespace
#---------------------------------------------------------------
resource "kubectl_manifest" "open_metadata_namespace" {
  count = var.enable_open_metadata ? 1 : 0

  yaml_body = templatefile("${path.module}/manifests/open-metadata/namespace.yaml", {
    namespace = local.open_metadata_namespace
  })
}

#---------------------------------------------------------------
# Database Secrets
#---------------------------------------------------------------

resource "kubernetes_secret" "open_metadata_postgresql_secrets" {
  count = var.enable_open_metadata ? 1 : 0

  metadata {
    name      = "postgresql-secrets"
    namespace = local.open_metadata_namespace
  }

  data = {
    postgres-password = random_password.open_metadata_postgres.result
    password          = random_password.open_metadata_postgres_user.result
  }

  type = "Opaque"

  depends_on = [kubectl_manifest.open_metadata_namespace[0]]
}

resource "random_password" "open_metadata_postgres" {
  length  = 16
  special = true
}

resource "random_password" "open_metadata_postgres_user" {
  length  = 16
  special = true
}

#---------------------------------------------------------------
# PostgreSQL StatefulSet and Service
#---------------------------------------------------------------
resource "kubectl_manifest" "open_metadata_postgresql" {
  for_each = { for idx, manifest in local.open_metadata_postgresql_manifests : idx => manifest if var.enable_open_metadata }

  yaml_body = yamlencode(each.value)

  depends_on = [
    kubectl_manifest.open_metadata_namespace[0],
    kubernetes_secret.open_metadata_postgresql_secrets[0]
  ]
}

#---------------------------------------------------------------
# OpenSearch Application (Dedicated for OpenMetadata)
#---------------------------------------------------------------
resource "kubectl_manifest" "opensearch_open_metadata" {
  count = var.enable_open_metadata ? 1 : 0

  yaml_body = templatefile("${path.module}/argocd-applications/opensearch-open-metadata.yaml", {
    user_values_yaml = indent(8, local.opensearch_open_metadata_values)
  })

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.open_metadata_namespace[0]
  ]
}

#---------------------------------------------------------------
# OpenMetadata Application
#---------------------------------------------------------------
resource "kubectl_manifest" "open_metadata" {
  count = var.enable_open_metadata ? 1 : 0

  yaml_body = templatefile("${path.module}/argocd-applications/open-metadata.yaml", {
    user_values_yaml = indent(8, local.open_metadata_values)
  })

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.open_metadata_postgresql,
    kubectl_manifest.opensearch_open_metadata[0],
    module.open_metadata_pod_identity[0],
    aws_iam_policy.open_metadata_s3_glue[0]
  ]
}
