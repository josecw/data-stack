#-----------------------------------------------------------------------------------------
# S3 Buckets for Data Platform - Tiered Storage
#-----------------------------------------------------------------------------------------

locals {
  # S3 Bucket Names
  s3_bucket_public_name    = "${local.name}-public"
  s3_bucket_divisions_name = "${local.name}-divisions"
  s3_bucket_projects_name  = "${local.name}-projects"
  s3_bucket_personal_name  = "${local.name}-personal"

  # Common S3 Bucket Configuration
  s3_bucket_force_destroy = true  # For example only - please evaluate for production
  s3_bucket_versioning  = true
  s3_bucket_encryption   = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # S3 Bucket Policy for Keycloak OIDC Integration
  s3_bucket_policy_document = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KeycloakOIDC"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${local.region}.amazonaws.com/id/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          module.s3_bucket_public.s3_bucket_arn,
          "${module.s3_bucket_public.s3_bucket_arn}/*",
          module.s3_bucket_divisions.s3_bucket_arn,
          "${module.s3_bucket_divisions.s3_bucket_arn}/*",
          module.s3_bucket_projects.s3_bucket_arn,
          "${module.s3_bucket_projects.s3_bucket_arn}/*",
          module.s3_bucket_personal.s3_bucket_arn,
          "${module.s3_bucket_personal.s3_bucket_arn}/*",
        ]
        Condition = {
          StringEquals = {
            "oidc.eks.${local.region}.amazonaws.com/id/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:(${local.keycloak_namespace}/${local.keycloak_service_account})"
          }
        }
      },
      {
        Sid    = "SecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          module.s3_bucket_public.s3_bucket_arn,
          "${module.s3_bucket_public.s3_bucket_arn}/*",
          module.s3_bucket_divisions.s3_bucket_arn,
          "${module.s3_bucket_divisions.s3_bucket_arn}/*",
          module.s3_bucket_projects.s3_bucket_arn,
          "${module.s3_bucket_projects.s3_bucket_arn}/*",
          module.s3_bucket_personal.s3_bucket_arn,
          "${module.s3_bucket_personal.s3_bucket_arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  }
}

#-----------------------------------------------------------------------------------------
# Tier 1: Public Bucket (Public/shared data)
#-----------------------------------------------------------------------------------------
module "s3_bucket_public" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  bucket_prefix = "${local.s3_bucket_public_name}-"

  force_destroy = local.s3_bucket_force_destroy

  versioning = {
    enabled = local.s3_bucket_versioning
  }

  server_side_encryption_configuration = local.s3_bucket_encryption

  # Public read access for shared data
  # Note: Use bucket policy for access control, not ACL

  tags = merge(local.tags, {
    Tier     = "Public"
    Purpose   = "SharedPublic"
    ManagedBy = "terraform"
  })
}

#-----------------------------------------------------------------------------------------
# Tier 2: Divisions Bucket (Division-level data)
#-----------------------------------------------------------------------------------------
module "s3_bucket_divisions" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  bucket_prefix = "${local.s3_bucket_divisions_name}-"

  force_destroy = local.s3_bucket_force_destroy

  versioning = {
    enabled = local.s3_bucket_versioning
  }

  server_side_encryption_configuration = local.s3_bucket_encryption

  tags = merge(local.tags, {
    Tier     = "Divisions"
    Purpose   = "DivisionData"
    ManagedBy = "terraform"
  })
}

#-----------------------------------------------------------------------------------------
# Tier 3: Projects Bucket (Project-level data)
#-----------------------------------------------------------------------------------------
module "s3_bucket_projects" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  bucket_prefix = "${local.s3_bucket_projects_name}-"

  force_destroy = local.s3_bucket_force_destroy

  versioning = {
    enabled = local.s3_bucket_versioning
  }

  server_side_encryption_configuration = local.s3_bucket_encryption

  tags = merge(local.tags, {
    Tier     = "Projects"
    Purpose   = "ProjectData"
    ManagedBy = "terraform"
  })
}

#-----------------------------------------------------------------------------------------
# Tier 4: Personal Bucket (User-level data)
#-----------------------------------------------------------------------------------------
module "s3_bucket_personal" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  bucket_prefix = "${local.s3_bucket_personal_name}-"

  force_destroy = local.s3_bucket_force_destroy

  versioning = {
    enabled = local.s3_bucket_versioning
  }

  server_side_encryption_configuration = local.s3_bucket_encryption

  tags = merge(local.tags, {
    Tier     = "Personal"
    Purpose   = "PersonalData"
    ManagedBy = "terraform"
  })
}

#-----------------------------------------------------------------------------------------
# S3 Bucket Policies (Keycloak OIDC Integration)
#-----------------------------------------------------------------------------------------

# Public Bucket Policy (read-only for Keycloak users)
resource "aws_s3_bucket_policy" "s3_bucket_public_policy" {
  bucket = module.s3_bucket_public.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KeycloakOIDCReadOnly"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${local.region}.amazonaws.com/id/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          module.s3_bucket_public.s3_bucket_arn,
          "${module.s3_bucket_public.s3_bucket_arn}/*",
        ]
        Condition = {
          StringEquals = {
            "oidc.eks.${local.region}.amazonaws.com/id/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:(${local.keycloak_namespace}/${local.keycloak_service_account})"
          }
        }
      },
      {
        Sid    = "SecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          module.s3_bucket_public.s3_bucket_arn,
          "${module.s3_bucket_public.s3_bucket_arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Divisions Bucket Policy (read-write for Keycloak groups)
resource "aws_s3_bucket_policy" "s3_bucket_divisions_policy" {
  bucket = module.s3_bucket_divisions.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KeycloakOIDCReadWrite"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${local.region}.amazonaws.com/id/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          module.s3_bucket_divisions.s3_bucket_arn,
          "${module.s3_bucket_divisions.s3_bucket_arn}/*",
        ]
        Condition = {
          StringLike = {
            "oidc.eks.${local.region}.amazonaws.com/id/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:*:${local.keycloak_namespace}*"
          }
        }
      },
      {
        Sid    = "SecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          module.s3_bucket_divisions.s3_bucket_arn,
          "${module.s3_bucket_divisions.s3_bucket_arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Projects Bucket Policy (read-write for Keycloak groups)
resource "aws_s3_bucket_policy" "s3_bucket_projects_policy" {
  bucket = module.s3_bucket_projects.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KeycloakOIDCReadWrite"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${local.region}.amazonaws.com/id/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          module.s3_bucket_projects.s3_bucket_arn,
          "${module.s3_bucket_projects.s3_bucket_arn}/*",
        ]
        Condition = {
          StringLike = {
            "oidc.eks.${local.region}.amazonaws.com/id/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:*:${local.keycloak_namespace}*"
          }
        }
      },
      {
        Sid    = "SecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          module.s3_bucket_projects.s3_bucket_arn,
          "${module.s3_bucket_projects.s3_bucket_arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Personal Bucket Policy (read-write for personal Keycloak groups)
resource "aws_s3_bucket_policy" "s3_bucket_personal_policy" {
  bucket = module.s3_bucket_personal.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KeycloakOIDCReadWrite"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${local.region}.amazonaws.com/id/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          module.s3_bucket_personal.s3_bucket_arn,
          "${module.s3_bucket_personal.s3_bucket_arn}/*",
        ]
        Condition = {
          StringEquals = {
            "oidc.eks.${local.region}.amazonaws.com/id/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${local.keycloak_namespace}/${local.keycloak_service_account}"
          }
        }
      },
      {
        Sid    = "PersonalAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_policy.s3_write_jupyter[0].arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          module.s3_bucket_personal.s3_bucket_arn,
          "${module.s3_bucket_personal.s3_bucket_arn}/*",
        ]
      },
      {
        Sid    = "SecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          module.s3_bucket_personal.s3_bucket_arn,
          "${module.s3_bucket_personal.s3_bucket_arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

#-----------------------------------------------------------------------------------------
# Create Initial Directory Structure
#-----------------------------------------------------------------------------------------

# Public shared directory
resource "aws_s3_object" "public_shared" {
  bucket       = module.s3_bucket_public.s3_bucket_id
  key          = "shared/"
  content_type = "application/x-directory"

  tags = {
    Purpose = "PublicShared"
  }
}

# Divisions directories
resource "aws_s3_object" "divisions_data_engineering" {
  bucket       = module.s3_bucket_divisions.s3_bucket_id
  key          = "data-engineering/"
  content_type = "application/x-directory"

  tags = {
    Division = "DataEngineering"
  }
}

resource "aws_s3_object" "divisions_data_science" {
  bucket       = module.s3_bucket_divisions.s3_bucket_id
  key          = "data-science/"
  content_type = "application/x-directory"

  tags = {
    Division = "DataScience"
  }
}

resource "aws_s3_object" "divisions_analytics" {
  bucket       = module.s3_bucket_divisions.s3_bucket_id
  key          = "analytics/"
  content_type = "application/x-directory"

  tags = {
    Division = "Analytics"
  }
}

#-----------------------------------------------------------------------------------------
# Outputs
#-----------------------------------------------------------------------------------------
output "s3_bucket_public_id" {
  description = "Public S3 bucket ID"
  value       = module.s3_bucket_public.s3_bucket_id
}

output "s3_bucket_public_arn" {
  description = "Public S3 bucket ARN"
  value       = module.s3_bucket_public.s3_bucket_arn
}

output "s3_bucket_divisions_id" {
  description = "Divisions S3 bucket ID"
  value       = module.s3_bucket_divisions.s3_bucket_id
}

output "s3_bucket_divisions_arn" {
  description = "Divisions S3 bucket ARN"
  value       = module.s3_bucket_divisions.s3_bucket_arn
}

output "s3_bucket_projects_id" {
  description = "Projects S3 bucket ID"
  value       = module.s3_bucket_projects.s3_bucket_id
}

output "s3_bucket_projects_arn" {
  description = "Projects S3 bucket ARN"
  value       = module.s3_bucket_projects.s3_bucket_arn
}

output "s3_bucket_personal_id" {
  description = "Personal S3 bucket ID"
  value       = module.s3_bucket_personal.s3_bucket_id
}

output "s3_bucket_personal_arn" {
  description = "Personal S3 bucket ARN"
  value       = module.s3_bucket_personal.s3_bucket_arn
}
