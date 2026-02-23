locals {
  backstage_values = templatefile("${path.module}/helm-values/backstage.yaml", {
    db_host             = module.rds_postgres_instance[0].endpoint
    db_port             = var.database_port
    db_user             = var.database_username
    db_password         = var.database_password
    db_name             = "backstage"
    backstage_user      = "admin"
    backstage_password  = var.backstage_admin_password
    github_token        = var.github_token
    domain_name         = var.domain_name
  })
}

resource "kubectl_manifest" "backstage" {
  count = var.enable_backstage ? 1 : 0

  yaml_body = templatefile("${path.module}/argocd-applications/backstage.yaml", {
    user_values_yaml = indent(10, local.backstage_values)
  })

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.ingress_nginx[0],
  ]
}

#---------------------------------------------------------------
# Backstage Namespace
#---------------------------------------------------------------
resource "kubectl_manifest" "backstage_namespace" {
  count = var.enable_backstage ? 1 : 0

  yaml_body = templatefile("${path.module}/manifests/backstage/namespace.yaml", {})
}

#---------------------------------------------------------------
# Backstage Secrets
#---------------------------------------------------------------
resource "kubectl_secret" "backstage_admin_credentials" {
  count = var.enable_backstage ? 1 : 0

  metadata {
    name      = "backstage-admin-credentials"
    namespace = "backstage"
  }

  data = {
    username = "admin"
    password = var.backstage_admin_password
  }

  depends_on = [
    kubectl_manifest.backstage_namespace[0]
  ]
}

resource "kubectl_secret" "backstage_github_token" {
  count = var.enable_backstage && var.github_token != "" ? 1 : 0

  metadata {
    name      = "backstage-github-token"
    namespace = "backstage"
  }

  data = {
    token = var.github_token
  }

  depends_on = [
    kubectl_manifest.backstage_namespace[0]
  ]
}

#---------------------------------------------------------------
# Backstage Ingress
#---------------------------------------------------------------
resource "kubectl_manifest" "backstage_ingress" {
  count = var.enable_backstage ? 1 : 0

  yaml_body = templatefile("${path.module}/manifests/backstage/ingress.yaml", {
    domain_name    = var.domain_name
    alb_dns_name   = module.ingress_nginx[0].lb_dns_name
    target_port    = 7007
  })

  depends_on = [
    kubectl_manifest.backstage_namespace[0],
    kubectl_manifest.ingress_nginx[0],
  ]
}
