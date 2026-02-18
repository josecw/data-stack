# Phase 5: Polaris + Ranger

## Overview

Phase 5 deploys two critical components for data governance and catalog management:

### Polaris (Apache Iceberg Catalog REST API)
- **Purpose**: Provides a unified, REST-based catalog for Apache Iceberg tables
- **Key Features**:
  - Implements Iceberg REST API specification
  - Multi-engine interoperability (Spark, Trino, Flink, etc.)
  - Supports multiple storage backends (S3, GCS, Azure)
  - Fine-grained access control
  - GitOps-ready deployment

### Apache Ranger
- **Purpose**: Fine-grained authorization framework for data platforms
- **Key Features**:
  - Centralized policy management
  - Service definitions for multiple data platforms (Iceberg, S3, Glue, etc.)
  - User/role-based access control
  - Audit logging
  - Integration with Keycloak for authentication

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Keycloak                              │
│                  (OIDC Provider)                           │
└──────────────┬──────────────────────────────────────────────┘
               │
               ├─────────────────────┬─────────────────────┐
               │                     │                     │
               ▼                     ▼                     ▼
    ┌─────────────────┐   ┌──────────────────┐   ┌─────────────────┐
    │    Polaris     │   │     Ranger       │   │     Coder      │
    │ (Iceberg Cat.)  │   │  (AuthZ)        │   │  (Dev Env)     │
    └────────┬────────┘   └────────┬─────────┘   └─────────────────┘
             │                     │
             ▼                     ▼
    ┌─────────────────┐   ┌──────────────────┐
    │   PostgreSQL    │   │   PostgreSQL    │
    │  (Metadata)    │   │  (Policies)     │
    └────────┬────────┘   └────────┬─────────┘
             │                     │
             └──────────┬──────────┘
                        ▼
               ┌─────────────────┐
               │  AWS S3 / Glue │
               │  (Data Storage) │
               └─────────────────┘
```

## Components

### Polaris Components
- **Namespace**: `polaris`
- **Pod Identity**: EKS Pod Identity for S3 access
- **PostgreSQL**: Metadata storage (50Gi)
- **Services**:
  - Polaris API (port 8181)
  - Management API (port 8182)
- **Ingress**: TLS via cert-manager
- **Keycloak Integration**: OIDC authentication

### Ranger Components
- **Namespace**: `ranger`
- **Pod Identity**: EKS Pod Identity for S3 audit logs
- **PostgreSQL**: Policy storage (100Gi)
- **Services**:
  - Ranger Admin UI (port 6080)
  - Ranger API (port 6081)
- **Ingress**: TLS via cert-manager
- **Keycloak Integration**: OIDC + User sync
- **Services**:
  - Iceberg/Polaris service
  - S3 service
  - Glue service

## Deployment Steps

### 1. Create S3 Buckets

```bash
# Polaris catalog bucket
aws s3api create-bucket \
  --bucket ${var.polaris_catalog_bucket} \
  --region ${var.aws_region}

# Ranger audit bucket
aws s3api create-bucket \
  --bucket ${var.ranger_audit_bucket} \
  --region ${var.aws_region}
```

### 2. Configure Keycloak Clients

Create OIDC clients in Keycloak:
- **Polaris Client**:
  - Client ID: `polaris`
  - Enabled: ON
  - Valid Redirect URIs: `https://polaris.${var.hostname}/*`
  - Access Type: confidential

- **Ranger Client**:
  - Client ID: `ranger`
  - Enabled: ON
  - Valid Redirect URIs: `https://ranger.${var.hostname}/*`
  - Access Type: confidential

### 3. Enable Phase 5 Variables

Update `data-stack.tfvars`:
```hcl
# Enable Phase 5
enable_polaris = true
enable_ranger = true

# S3 buckets
polaris_catalog_bucket = "your-polaris-catalog-bucket"
ranger_audit_bucket = "your-ranger-audit-bucket"

# Keycloak configuration
keycloak_realm = "DoEKS"
hostname = "data.example.com"

# Optional
monitoring_enabled = true
solr_enabled = false  # Use S3 for audit logs
```

### 4. Apply Terraform

```bash
cd ~/projects/data-stack/infra/terraform
terraform apply -var-file=data-stack.tfvars
```

### 5. Bootstrap Polaris Root User

After deployment, bootstrap the Polaris root user:

```bash
# Get root credentials from secret
kubectl get secret polaris-root-secret -n polaris -o jsonpath='{.data.root-client-secret}' | base64 -d

# Bootstrap using polaris-admin-tool
kubectl run bootstrap-polaris -n polaris --restart=Never --rm -it \
  --image=apache/polaris-admin-tool:latest \
  --env ROOT_CLIENT_ID=root \
  --env ROOT_CLIENT_SECRET=<root-secret> \
  -- bootstrap -c POLARIS,root,<root-secret> -r POLARIS
```

### 6. Configure Ranger Services

After deployment, access Ranger Admin UI:
```
https://ranger.${var.hostname}
```

Login with Keycloak credentials and configure:
1. **Iceberg/Polaris Service**:
   - Service Name: `iceberg`
   - Repository Name: `iceberg_repo`
   - Username: `polaris`
   - Password: `<from secret>`
   - Iceberg REST URL: `http://polaris:8181/api/catalog`

2. **S3 Service**:
   - Service Name: `s3`
   - Repository Name: `s3_repo`
   - Authentication Type: `S3 IAM`

3. **Glue Service**:
   - Service Name: `glue`
   - Repository Name: `glue_repo`
   - Region: `${var.aws_region}`

## Integration Points

### Keycloak Integration
- **Polaris**: OIDC client for authentication
- **Ranger**: OIDC client + LDAP user sync (every 5 minutes)

### S3 Integration
- **Polaris**: Catalog storage for Iceberg metadata
- **Ranger**: Audit log storage
- **Pod Identity**: IAM role for S3 access

### Glue Integration
- **Ranger**: Glue service definition for AWS Glue catalog policies

### Coder Integration
- Developers can access Polaris catalog from Coder workspaces
- Ranger policies enforce access to S3 buckets

## Access URLs

After deployment:
- **Polaris API**: `https://polaris.${var.hostname}`
- **Polaris Management**: `https://polaris.${var.hostname}:8182`
- **Ranger Admin**: `https://ranger.${var.hostname}`
- **Ranger API**: `https://ranger.${var.hostname}:6081`

## Verification

### Check Polaris
```bash
# Port forward to Polaris
kubectl port-forward -n polaris svc/polaris 8181:8181

# List catalogs (requires polaris CLI)
polaris catalogs list --url http://localhost:8181/api/catalog
```

### Check Ranger
```bash
# Port forward to Ranger
kubectl port-forward -n ranger svc/ranger 6080:6080

# Access Ranger Admin UI
# Open: https://localhost:6080
```

## Troubleshooting

### Polaris Issues
- **Bootstrap fails**: Check PostgreSQL connection
- **S3 access denied**: Verify IAM role and Pod Identity
- **OIDC errors**: Check Keycloak client configuration

### Ranger Issues
- **User sync fails**: Verify Keycloak LDAP connection
- **Policy download errors**: Check service configuration
- **Audit logs not writing**: Verify S3 bucket permissions

## Resources

- [Apache Polaris](https://polaris.apache.org/)
- [Apache Ranger](https://ranger.apache.org/)
- [Iceberg REST API](https://iceberg.apache.org/docs/latest/api/rest/)
- [Keycloak Documentation](https://www.keycloak.org/documentation/)

## Next Steps

After Phase 5 completion:
1. **Phase 6**: Metadata service deployment
2. **Phase 7**: Streaming platform (Kafka/Flink)
3. **Phase 8**: LGTM Stack (Loki, Grafana, Tempo)
