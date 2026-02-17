#-----------------------------------------------------------------------------------------
# Coder S3/Glue Pod Identity
#-----------------------------------------------------------------------------------------

locals {
  coder_namespace = "coder"
  coder_service_account = "coder-sa"
}

#-----------------------------------------------------------------------------------------
# Coder PostgreSQL Secret
#-----------------------------------------------------------------------------------------
resource "random_password" "coder_postgres" {
  length  = 32
  special = true
}

resource "kubernetes_secret" "coder_postgres_secret" {
  count = var.enable_coder ? 1 : 0

  metadata {
    name      = "coder-pg-secret"
    namespace = local.coder_namespace
  }

  data = {
    password = random_password.coder_postgres.result
  }

  type = "Opaque"

  depends_on = [
    kubectl_manifest.coder_namespace[0]
  ]
}

#-----------------------------------------------------------------------------------------
# Coder OIDC Secret
#-----------------------------------------------------------------------------------------
data "aws_iam_policy_document" "coder_s3_glue" {
  count = var.enable_coder ? 1 : 0

  statement {
    sid    = "S3Access"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
    ]

    resources = [
      module.s3_bucket_public.s3_bucket_arn,
      "${module.s3_bucket_public.s3_bucket_arn}/*",
      module.s3_bucket_divisions.s3_bucket_arn,
      "${module.s3_bucket_divisions.s3_bucket_arn}/*",
      module.s3_bucket_projects.s3_bucket_arn,
      "${module.s3_bucket_projects.s3_bucket_arn}/*",
      module.s3_bucket_personal.s3_bucket_arn,
      "${module.s3_bucket_personal.s3_bucket_arn}/*",
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
      "glue:BatchCreatePartition",
      "glue:BatchDeletePartition",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "coder_s3_glue" {
  count       = var.enable_coder ? 1 : 0
  name_prefix = "${local.name}-coder-s3-glue-"
  path        = "/"
  description = "IAM policy for Coder S3 and Glue access"

  policy = data.aws_iam_policy_document.coder_s3_glue[0].json

  tags = local.tags
}

#-----------------------------------------------------------------------------------------
# Coder Pod Identity
#-----------------------------------------------------------------------------------------
module "coder_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  count  = var.enable_coder ? 1 : 0

  name = "coder"

  additional_policy_arns = {
    s3_glue = aws_iam_policy.coder_s3_glue[0].arn
  }

  associations = {
    coder = {
      cluster_name    = module.eks.cluster_name
      namespace       = local.coder_namespace
      service_account = local.coder_service_account
    }
  }

  tags = merge(local.tags, {
    Name = "${local.name}-coder-pod-identity"
  })

  depends_on = [
    kubectl_manifest.coder_namespace[0]
  ]
}

#-----------------------------------------------------------------------------------------
# Coder Service Account (with Pod Identity annotation)
#-----------------------------------------------------------------------------------------
resource "kubectl_manifest" "coder_service_account" {
  count = var.enable_coder ? 1 : 0

  yaml_body = templatefile("${path.module}/manifests/coder/service-account.yaml", {
    service_account_name = local.coder_service_account
    namespace            = local.coder_namespace
    team_name            = "coder"
    iam_role_arn        = module.coder_pod_identity[0].iam_role_arn
  })

  depends_on = [
    kubectl_manifest.coder_namespace[0],
    module.coder_pod_identity
  ]
}

#-----------------------------------------------------------------------------------------
# Coder ArgoCD Application
#-----------------------------------------------------------------------------------------
locals {
  coder_values = templatefile("${path.module}/helm-values/coder.yaml", {
    namespace           = local.coder_namespace
    iam_role_arn        = module.coder_pod_identity[0].iam_role_arn
  })
}

resource "kubectl_manifest" "coder_argocd_app" {
  count = var.enable_coder ? 1 : 0

  yaml_body = templatefile("${path.module}/argocd-applications/coder.yaml", {
    namespace        = local.coder_namespace
    user_values_yaml = indent(8, local.coder_values)
  })

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.coder_namespace[0],
    kubectl_manifest.coder_service_account[0]
  ]
}

#-----------------------------------------------------------------------------------------
# Outputs
#-----------------------------------------------------------------------------------------
output "coder_namespace" {
  description = "Coder namespace"
  value       = var.enable_coder ? local.coder_namespace : null
}

output "coder_service_account" {
  description = "Coder service account"
  value       = var.enable_coder ? local.coder_service_account : null
}

output "coder_pod_identity_role_arn" {
  description = "Coder pod identity IAM role ARN"
  value       = var.enable_coder ? module.coder_pod_identity[0].iam_role_arn : null
}
