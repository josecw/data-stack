#-----------------------------------------------------------------------------------------
# Teams with Keycloak Integration (v3)
# This module provides Keycloak OIDC support for teams
# Use enable_teams_v3 to activate this instead of legacy teams.tf
#-----------------------------------------------------------------------------------------

locals {
  # Keycloak Configuration
  keycloak_v3_realm     = "data-platform"
  keycloak_v3_client_id  = "${var.name}-keycloak-client"

  # Teams Configuration with Keycloak Groups
  teams_v3 = {
    spark-team-a = {
      name                = "${var.name}-spark-team-a"
      namespace           = "spark-team-a"
      service_account     = "spark-team-a"
      iam_policy_arns     = [aws_iam_policy.spark_jobs.arn, aws_iam_policy.s3tables_policy.arn]
      additional_policies = {}
      tags = {
        Team = "spark-team-a"
      }
      # Keycloak Group Mapping
      keycloak_group      = "spark-team-a"
      keycloak_group_type = "division"  # division, project, personal
    }
    spark-team-b = {
      name                = "${var.name}-spark-team-b"
      namespace           = "spark-team-b"
      service_account     = "spark-team-b"
      iam_policy_arns     = [aws_iam_policy.spark_jobs.arn, aws_iam_policy.s3tables_policy.arn]
      additional_policies = {}
      tags = {
        Team = "spark-team-b"
      }
      keycloak_group      = "spark-team-b"
      keycloak_group_type = "division"
    }
    spark-team-c = {
      name                = "${var.name}-spark-team-c"
      namespace           = "spark-team-c"
      service_account     = "spark-team-c"
      iam_policy_arns     = [aws_iam_policy.spark_jobs.arn, aws_iam_policy.s3tables_policy.arn]
      additional_policies = {}
      tags = {
        Team = "spark-team-c"
      }
      keycloak_group      = "spark-team-c"
      keycloak_group_type = "division"
    }
    flink-team-a = {
      name                = "${var.name}-flink-team-a"
      namespace           = "flink-team-a"
      service_account     = "flink-team-a"
      iam_policy_arns     = [aws_iam_policy.flink_jobs.arn]
      additional_policies = {}
      tags = {
        Team = "flink-team-a"
      }
      keycloak_group      = "flink-team-a"
      keycloak_group_type = "division"
    }
    raydata = {
      name                = "${var.name}-raydata"
      namespace           = "raydata"
      service_account     = "raydata"
      iam_policy_arns     = [aws_iam_policy.spark_jobs.arn, aws_iam_policy.s3tables_policy.arn]
      additional_policies = {}
      tags = {
        Team = "raydata"
      }
      keycloak_group      = "raydata"
      keycloak_group_type = "division"
    }
  }

  # Tier 2 S3 Bucket References (if enabled)
  s3_bucket_divisions_arn  = var.enable_tiered_s3_buckets ? module.s3_bucket_divisions.s3_bucket_arn : ""
  s3_bucket_projects_arn   = var.enable_tiered_s3_buckets ? module.s3_bucket_projects.s3_bucket_arn : ""
  s3_bucket_personal_arn   = var.enable_tiered_s3_buckets ? module.s3_bucket_personal.s3_bucket_arn : ""
}

#-----------------------------------------------------------------------------------------
# Pod Identity for Teams v3 (with Keycloak annotations)
#-----------------------------------------------------------------------------------------
module "team_pod_identity_v3" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  for_each = var.enable_teams_v3 ? local.teams_v3 : {}

  name = each.value.name

  additional_policy_arns = merge(
    { for idx, arn in each.value.iam_policy_arns : "policy_${idx}" => arn },
    each.value.additional_policies
  )

  associations = {
    team = {
      cluster_name    = module.eks.cluster_name
      namespace       = each.value.namespace
      service_account = each.value.service_account
    }
  }

  tags = each.value.tags
}

#-----------------------------------------------------------------------------------------
# Kubernetes Resources for Teams v3
#-----------------------------------------------------------------------------------------

# Team Namespaces with Keycloak annotations
resource "kubectl_manifest" "team_namespaces_v3" {
  for_each = var.enable_teams_v3 ? local.teams_v3 : {}

  yaml_body = templatefile("${path.module}/manifests/teams/namespace-keycloak.yaml", {
    namespace          = each.value.namespace
    team_name          = each.value.name
    keycloak_group     = each.value.keycloak_group
    keycloak_realm    = local.keycloak_v3_realm
    keycloak_client_id = local.keycloak_v3_client_id
  })

  depends_on = [
    helm_release.argocd
  ]
}

# Team Service Accounts with Keycloak annotations
resource "kubectl_manifest" "team_service_accounts_v3" {
  for_each = var.enable_teams_v3 ? local.teams_v3 : {}

  yaml_body = templatefile("${path.module}/manifests/teams/service-account.yaml", {
    service_account = each.value.service_account
    namespace         = each.value.namespace
    team_name         = each.value.name
  })

  depends_on = [
    kubectl_manifest.team_namespaces_v3,
    module.team_pod_identity_v3
  ]
}

# Team Cluster Role Bindings (with Keycloak group references)
resource "kubectl_manifest" "team_cluster_role_bindings_v3" {
  for_each = var.enable_teams_v3 ? local.teams_v3 : {}

  yaml_body = templatefile("${path.module}/manifests/teams/cluster-role-binding.yaml", {
    team_name       = each.value.name
    service_account = each.value.service_account
    namespace       = each.value.namespace
    keycloak_group  = each.value.keycloak_group
  })

  depends_on = [
    kubectl_manifest.team_namespaces_v3,
    kubectl_manifest.team_service_accounts_v3
  ]
}

# Flink-specific RBAC v3 (with Keycloak integration)
resource "kubectl_manifest" "flink_role_v3" {
  for_each = var.enable_teams_v3 ? { for team_name, team in local.teams_v3 : team_name => team if team.keycloak_group_type == "division" } : {}

  yaml_body = templatefile("${path.module}/manifests/flink/role.yaml", {
    team_name = each.value.name
    namespace = each.value.namespace
  })

  depends_on = [
    kubectl_manifest.team_namespaces_v3
  ]
}

resource "kubectl_manifest" "flink_rolebinding_v3" {
  for_each = var.enable_teams_v3 ? { for team_name, team in local.teams_v3 : team_name => team if team.keycloak_group_type == "division" } : {}

  yaml_body = templatefile("${path.module}/manifests/flink/rolebinding.yaml", {
    team_name       = each.value.name
    namespace       = each.value.namespace
    service_account = each.value.service_account
  })

  depends_on = [
    kubectl_manifest.team_service_accounts_v3,
    kubectl_manifest.flink_role_v3
  ]
}

#-----------------------------------------------------------------------------------------
# Outputs
#-----------------------------------------------------------------------------------------
output "teams_v3" {
  description = "All teams configuration (v3)"
  value       = var.enable_teams_v3 ? local.teams_v3 : null
}

output "team_namespaces_v3" {
  description = "Team namespace names (v3)"
  value       = var.enable_teams_v3 ? { for team_name, team in local.teams_v3 : team_name => team.namespace } : null
}

output "team_service_accounts_v3" {
  description = "Team service account names (v3)"
  value       = var.enable_teams_v3 ? { for team_name, team in local.teams_v3 : team_name => team.service_account } : null
}

output "team_keycloak_groups_v3" {
  description = "Team Keycloak groups (v3)"
  value       = var.enable_teams_v3 ? { for team_name, team in local.teams_v3 : team_name => team.keycloak_group } : null
}
