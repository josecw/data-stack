#-----------------------------------------------------------------------------------------
# Keycloak OIDC Provider for EKS
#-----------------------------------------------------------------------------------------

locals {
  keycloak_namespace       = "keycloak"
  keycloak_service_account = "keycloak"
  keycloak_hostname       = var.ingress_domain != "" ? "${var.keycloak_hostname_prefix}.${var.ingress_domain}" : "keycloak.local"

  keycloak_values = templatefile("${path.module}/helm-values/keycloak.yaml", {
    namespace    = local.keycloak_namespace
    hostname     = local.keycloak_hostname
    iam_role_arn = module.keycloak_pod_identity[0].iam_role_arn
  })
}

#-----------------------------------------------------------------------------------------
# AWS IAM OIDC Provider for EKS (if not exists)
#-----------------------------------------------------------------------------------------
data "aws_iam_openid_connect_provider" "cluster" {
  url = module.eks.cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  count = length(data.aws_iam_openid_connect_provider.cluster.url) > 0 ? 0 : 1

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

  url = module.eks.cluster_oidc_issuer_url
}

#-----------------------------------------------------------------------------------------
# Keycloak Namespace
#-----------------------------------------------------------------------------------------
resource "kubectl_manifest" "keycloak_namespace" {
  count = var.enable_keycloak ? 1 : 0

  yaml_body = templatefile("${path.module}/manifests/keycloak/namespace.yaml", {
    namespace = local.keycloak_namespace
  })

  depends_on = [
    helm_release.argocd
  ]
}

#-----------------------------------------------------------------------------------------
# Keycloak Admin Secret
#-----------------------------------------------------------------------------------------
resource "kubernetes_secret" "keycloak_admin" {
  count = var.enable_keycloak ? 1 : 0

  metadata {
    name      = "keycloak-admin-secret"
    namespace = local.keycloak_namespace
  }

  data = {
    admin-password = var.keycloak_admin_password
  }

  type = "Opaque"

  depends_on = [
    kubectl_manifest.keycloak_namespace[0]
  ]
}

#-----------------------------------------------------------------------------------------
# Keycloak PostgreSQL Secret
#-----------------------------------------------------------------------------------------
resource "random_password" "keycloak_postgres" {
  length  = 32
  special = true
}

resource "kubernetes_secret" "keycloak_postgresql" {
  count = var.enable_keycloak ? 1 : 0

  metadata {
    name      = "keycloak-postgresql-secret"
    namespace = local.keycloak_namespace
  }

  data = {
    password = random_password.keycloak_postgres.result
  }

  type = "Opaque"

  depends_on = [
    kubectl_manifest.keycloak_namespace[0]
  ]
}

#-----------------------------------------------------------------------------------------
# IAM Role for Keycloak Pod Identity (S3/Glue access)
#-----------------------------------------------------------------------------------------
data "aws_iam_policy_document" "keycloak_s3_glue" {
  count = var.enable_keycloak ? 1 : 0

  statement {
    sid    = "S3Access"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:ListBucketVersions",
    ]

    resources = [
      module.s3_bucket.s3_bucket_arn,
      "${module.s3_bucket.s3_bucket_arn}/*",
      module.data_bucket.s3_bucket_arn,
      "${module.data_bucket.s3_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "GlueAccess"
    effect = "Allow"

    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:CreateDatabase",
      "glue:GetTable",
      "glue:GetTables",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:CreatePartition",
      "glue:UpdatePartition",
      "glue:DeletePartition",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "EKSDescribe"
    effect = "Allow"

    actions = [
      "eks:DescribeCluster",
    ]

    resources = [module.eks.cluster_arn]
  }
}

resource "aws_iam_policy" "keycloak_s3_glue" {
  count       = var.enable_keycloak ? 1 : 0
  name_prefix = "${local.name}-keycloak-s3-glue-"
  path        = "/"
  description = "IAM policy for Keycloak S3 and Glue access"

  policy = data.aws_iam_policy_document.keycloak_s3_glue[0].json

  tags = local.tags
}

module "keycloak_pod_identity" {
  count  = var.enable_keycloak ? 1 : 0
  source = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name = "keycloak"

  additional_policy_arns = {
    s3_glue = aws_iam_policy.keycloak_s3_glue[0].arn
  }

  associations = {
    keycloak = {
      cluster_name    = module.eks.cluster_name
      namespace       = local.keycloak_namespace
      service_account = local.keycloak_service_account
    }
  }

  tags = merge(local.tags, {
    Name = "${local.name}-keycloak-pod-identity"
  })

  depends_on = [
    kubectl_manifest.keycloak_namespace[0]
  ]
}

#-----------------------------------------------------------------------------------------
# Keycloak Service Account (for Pod Identity)
#-----------------------------------------------------------------------------------------
resource "kubectl_manifest" "keycloak_service_account" {
  count = var.enable_keycloak ? 1 : 0

  yaml_body = templatefile("${path.module}/manifests/keycloak/service-account.yaml", {
    service_account_name = local.keycloak_service_account
    namespace            = local.keycloak_namespace
    iam_role_arn        = module.keycloak_pod_identity[0].iam_role_arn
  })

  depends_on = [
    kubectl_manifest.keycloak_namespace[0],
    module.keycloak_pod_identity[0]
  ]
}

#-----------------------------------------------------------------------------------------
# Keycloak ArgoCD Application
#-----------------------------------------------------------------------------------------
resource "kubectl_manifest" "keycloak_argocd_app" {
  count = var.enable_keycloak ? 1 : 0

  yaml_body = templatefile("${path.module}/argocd-applications/keycloak.yaml", {
    namespace        = local.keycloak_namespace
    user_values_yaml = indent(8, local.keycloak_values)
  })

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.keycloak_namespace[0],
    kubernetes_secret.keycloak_admin[0],
    kubernetes_secret.keycloak_postgresql[0],
    module.keycloak_pod_identity[0]
  ]
}

#-----------------------------------------------------------------------------------------
# Outputs
#-----------------------------------------------------------------------------------------
output "keycloak_namespace" {
  description = "Keycloak namespace"
  value       = var.enable_keycloak ? local.keycloak_namespace : null
}

output "keycloak_service_account" {
  description = "Keycloak service account"
  value       = var.enable_keycloak ? local.keycloak_service_account : null
}

output "keycloak_hostname" {
  description = "Keycloak hostname"
  value       = var.enable_keycloak ? local.keycloak_hostname : null
}

output "keycloak_url" {
  description = "Keycloak URL"
  value       = var.enable_keycloak ? "https://${local.keycloak_hostname}" : null
}

output "keycloak_pod_identity_role_arn" {
  description = "Keycloak Pod Identity IAM Role ARN"
  value       = var.enable_keycloak ? module.keycloak_pod_identity[0].iam_role_arn : null
}
