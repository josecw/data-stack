# Phase 6: Open Metadata

## Overview

Phase 6 deploys Open Metadata, an enterprise-grade metadata platform that provides:

- **Data Catalog**: Central repository for all data assets
- **Lineage**: Visual representation of data flow and transformations
- **Governance**: Policy-based access control and data quality
- **Search**: Powerful search across all metadata
- **Ingestion**: Automated metadata ingestion via Apache Airflow

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Keycloak                              │
│                  (OIDC Provider)                           │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
    ┌─────────────────────────────────┐
    │    Open Metadata             │
    │  (Metadata Platform)         │
    │                              │
    │  ┌────────────────────────┐   │
    │  │ OpenMetadata Server │   │
    │  │   (UI + API)        │   │
    │  └────────┬─────────────┘   │
    │           │                   │
    │           ▼                   │
    │  ┌────────────────────────┐   │
    │  │ Apache Airflow      │   │
    │  │ (Pipeline Engine)   │   │
    │  └────────┬─────────────┘   │
    │           │                   │
    │           ▼                   │
    │  ┌────────────────────────┐   │
    │  │ PostgreSQL          │   │
    │  │ (Metadata Store)   │   │
    │  └────────────────────────┘   │
    │                              │
    │  ┌────────────────────────┐   │
    │  │ Elasticsearch       │   │
    │  │ (Search Index)     │   │
    │  └────────┬─────────────┘   │
    └───────────┼───────────────────┘
                │
                ▼
         ┌──────────────────┐
         │  AWS S3        │
         │ (DAGs, Logs,   │
         │  Backups)      │
         └──────────────────┘
```

## Components

### OpenMetadata Server
- **Namespace**: `openmetadata`
- **Service**: HTTP (8585) + HTTPS (8586)
- **Ingress**: TLS via cert-manager
- **Resources**: 2 CPU, 4Gi memory
- **Keycloak Integration**: OIDC authentication
- **Database**: PostgreSQL
- **Search**: Elasticsearch

### Apache Airflow (Ingestion)
- **Namespace**: `openmetadata`
- **Service**: HTTP (8080)
- **Executor**: KubernetesExecutor
- **Resources**: 2 CPU, 4Gi memory
- **Pod Identity**: S3 access for DAGs and logs
- **DAG Storage**: 10Gi PVC
- **Logs Storage**: 20Gi PVC
- **Database**: Shared PostgreSQL
- **SMTP**: Optional email notifications

### PostgreSQL
- **Namespace**: `openmetadata`
- **Resources**: 1 CPU, 2Gi memory
- **Storage**: 100Gi PVC (gp3-encrypted)
- **Database**: `openmetadata_db`
- **Schema**: `public`

### Elasticsearch
- **Namespace**: `openmetadata`
- **Resources**: 2 CPU, 4Gi memory
- **Storage**: 200Gi PVC (gp3-encrypted)
- **Replicas**: 1 (single node for development)
- **Purpose**: Search index for metadata

## Deployment Steps

### 1. Configure S3 Buckets

```bash
# Airflow DAGs and logs bucket (optional - can be created by Terraform)
aws s3api create-bucket \
  --bucket ${var.openmetadata_airflow_bucket} \
  --region ${var.aws_region}

# Backup bucket (optional - can be created by Terraform)
aws s3api create-bucket \
  --bucket ${var.openmetadata_backup_bucket} \
  --region ${var.aws_region}
```

### 2. Configure Keycloak Client

Create OIDC client in Keycloak:
- **Client ID**: `openmetadata`
- **Enabled**: ON
- **Valid Redirect URIs**: `https://openmetadata.${var.hostname}/*`
- **Access Type**: confidential
- **Realm**: `${var.keycloak_realm}`

### 3. Enable Phase 6 Variables

Update `data-stack.tfvars`:
```hcl
# Enable Phase 6
enable_open_metadata = true

# S3 buckets (optional - will be created by Terraform if set to empty)
openmetadata_airflow_bucket = ""  # Set to "" to auto-create
openmetadata_backup_bucket = ""    # Set to "" to auto-create

# Or use existing buckets
# openmetadata_airflow_bucket = "your-existing-airflow-bucket"
# openmetadata_backup_bucket = "your-existing-backup-bucket"

# Other configuration
openmetadata_secrets_manager = "org.openmetadata.service.secrets.NoopSecretsManager"
```

### 4. Apply Terraform

```bash
cd ~/projects/data-stack/infra/terraform
terraform apply -var-file=data-stack.tfvars
```

### 5. Verify Deployment

```bash
# Check OpenMetadata pods
kubectl get pods -n openmetadata

# Check services
kubectl get svc -n openmetadata

# Port forward to OpenMetadata
kubectl port-forward -n openmetadata svc/openmetadata 8585:8585

# Port forward to Airflow
kubectl port-forward -n openmetadata svc/openmetadata-airflow 8080:8080
```

## Access URLs

After deployment:
- **OpenMetadata UI**: `https://openmetadata.${var.hostname}`
- **OpenMetadata API**: `https://openmetadata.${var.hostname}/api`
- **Airflow UI**: `https://openmetadata.${var.hostname}/airflow`
- **Airflow API**: `https://openmetadata.${var.hostname}/airflow/api`

## Configuration

### OpenMetadata Server

Key configuration options:
- **Authentication**: Keycloak OIDC
- **Database**: PostgreSQL (external service)
- **Elasticsearch**: External service
- **Airflow**: External service
- **Secrets Manager**: Noop (default)
- **Authorizer**: RBAC
- **JWT**: RSA public key

### Apache Airflow

Key configuration options:
- **Executor**: KubernetesExecutor
- **Database**: Shared PostgreSQL
- **Logging**: Remote logging to S3
- **DAG Storage**: PVC + S3
- **Pod Identity**: EKS Pod Identity for S3 access
- **Security**: Secure proxy enabled

## Integration Points

### Keycloak Integration
- **OpenMetadata**: OIDC client for authentication
- **Realm**: `${var.keycloak_realm}` (default: `DoEKS`)

### S3 Integration
- **Airflow**: DAGs, logs, and backups
- **Pod Identity**: IAM role for S3 access
- **Lifecycle**: Versioning enabled for backup bucket

### PostgreSQL Integration
- **Shared Backend**: OpenMetadata and Airflow share same PostgreSQL
- **Databases**:
  - `openmetadata_db` (metadata)
  - `openmetadata_airflow` (Airflow)

### Elasticsearch Integration
- **Search Index**: Full-text search for metadata
- **Type**: Single node for development
- **Storage**: 200Gi PVC

## Features

### Data Catalog
- Central repository for all data assets
- Rich metadata (schema, description, tags)
- Custom properties and classifications

### Lineage
- Visual representation of data flow
- Column-level lineage
- Impact analysis

### Governance
- Policy-based access control
- Data quality rules
- Classification and sensitivity levels

### Search
- Full-text search across all metadata
- Faceted search (type, tags, owner)
- Advanced filters

### Ingestion
- Apache Airflow for automated ingestion
- Pre-built connectors for common systems
- Custom DAGs for specific sources

## Backup and Restore

### Automatic Backups
- **Schedule**: Daily at 2:00 AM
- **Retention**: 7 days
- **Storage**: S3 bucket
- **Format**: PostgreSQL dumps

### Manual Backup
```bash
# Export metadata
kubectl exec -n openmetadata deploy/openmetadata -- pg_dump \
  -U openmetadata \
  -d openmetadata_db \
  > backup.sql

# Copy to S3
aws s3 cp backup.sql s3://${var.openmetadata_backup_bucket}/manual-backups/
```

## Monitoring

### Health Checks
```bash
# OpenMetadata health
curl https://openmetadata.${var.hostname}/health

# Airflow health
curl https://openmetadata.${var.hostname}/airflow/health
```

### Metrics
- **OpenMetadata**: JMX metrics (if monitoring enabled)
- **Airflow**: StatsD/Prometheus metrics (if monitoring enabled)
- **PostgreSQL**: Database metrics
- **Elasticsearch**: Search metrics

## Troubleshooting

### OpenMetadata Issues
- **Login fails**: Check Keycloak client configuration
- **Search not working**: Verify Elasticsearch connection
- **Database errors**: Check PostgreSQL connection and credentials

### Airflow Issues
- **DAGs not loading**: Check DAGs storage and S3 access
- **Tasks failing**: Check Pod Identity and IAM role
- **Logs not writing**: Verify S3 bucket permissions

### PostgreSQL Issues
- **Connection errors**: Check service name and namespace
- **Performance issues**: Increase resource limits
- **Storage full**: Increase PVC size

## Resources

- [Open Metadata Documentation](https://docs.open-metadata.org/)
- [Open Metadata GitHub](https://github.com/open-metadata/OpenMetadata)
- [Open Metadata Helm Charts](https://github.com/open-metadata/openmetadata-helm-charts)
- [Airflow Documentation](https://airflow.apache.org/docs/)

## Next Steps

After Phase 6 completion:
1. **Phase 8**: LGTM Stack (Loki, Grafana, Tempo)
2. **Phase 9**: Cost monitoring and optimization tools

**Note**: Phase 7 (Streaming) is skipped per request.

## Security Best Practices

1. **Authentication**: Use Keycloak OIDC for all access
2. **Secrets**: Use Kubernetes secrets for all credentials
3. **Network**: Use NetworkPolicies to restrict traffic
4. **RBAC**: Configure proper roles and permissions
5. **Audit**: Enable Airflow logging to S3
6. **Backup**: Regular backups with retention policy
7. **Updates**: Keep OpenMetadata and dependencies updated

## Performance Tuning

### OpenMetadata Server
- Increase memory for large catalogs (> 10k tables)
- Tune Java GC settings
- Enable Elasticsearch clustering for high availability

### Apache Airflow
- Scale executor resources based on workload
- Use multiple schedulers for high throughput
- Optimize DAG concurrency

### Elasticsearch
- Increase shard count for large datasets
- Use hot-warm architecture for cost optimization
- Enable index lifecycle management
