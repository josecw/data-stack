# Backstage on EKS

[Spotify Backstage](https://backstage.io/) is an open-source developer portal platform that provides a centralized location for managing your software catalog, documentation, and developer tools.

![Backstage Logo](https://backstage.io/img/logo.svg)

## 🚀 Features

- **Service Catalog:** Centralized catalog of all your services, APIs, and libraries
- **Software Templates:** Create new services and projects with customizable templates
- **Tech Docs:** Render and manage technical documentation (powered by MkDocs)
- **Plugin System:** Extensible plugin ecosystem for integrations (GitHub, CI/CD, monitoring, etc.)
- **Search:** Powerful search across all catalog entities
- **CI/CD Integration:** Visualize build and deployment status
- **Kubernetes Integration:** View and manage Kubernetes resources

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        EKS Cluster                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Backstage Deployment                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌───────────────┐│   │
│  │  │   Frontend  │  │   Backend   │  │   Database    ││   │
│  │  │  (Node.js)  │  │  (Node.js)  │  │   (PostgreSQL)││   │
│  │  └─────────────┘  └─────────────┘  └───────────────┘│   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            Integrations via Plugins                    │   │
│  │  • GitHub  • Jira  • CI/CD  • Monitoring  • K8s       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

- AWS account with appropriate IAM permissions
- EKS cluster (deployed via DoEKS terraform)
- kubectl configured to connect to EKS
- Helm 3.x installed

## 🚦 Quick Start

### 1. Set Environment Variables

```bash
export AWS_REGION="us-east-1"
export DOMAIN_NAME="example.com"  # Your Route53 hosted zone
export ENABLE_BACKSTAGE=true
```

### 2. Deploy Backstage

```bash
cd ~/projects/data-stack/data-stacks/backstage-on-eks
./deploy.sh
```

### 3. Access Backstage

After deployment completes, access Backstage at:

```
http://backstage.<DOMAIN_NAME>
```

### 4. Default Credentials

Check the secret for credentials:

```bash
kubectl -n backstage get secret backstage-admin-credentials -o jsonpath="{.data.password}" | base64 -d
```

## 🔧 Configuration

### Enable Backstage in Terraform

In `infra/terraform/data-stack.tfvars`:

```hcl
enable_backstage = true
```

### Helm Values

Customize Backstage by modifying `infra/terraform/helm-values/backstage.yaml`:

```yaml
backstage:
  appConfig:
    baseUrl: "https://backstage.example.com"
    integrations:
      github:
        - host: github.com
          token: ${GITHUB_TOKEN}
```

### Database

By default, Backstage uses PostgreSQL. Configure in `backstage.yaml`:

```yaml
postgresql:
  enabled: true
  auth:
    username: backstage
    password: ${BACKSTAGE_DB_PASSWORD}
    database: backstage_db
```

## 📚 Examples

See the `examples/` directory for:

- **Sample catalog entities:** Example service, component, and API definitions
- **Configuration templates:** Integration configs for GitHub, Jira, etc.
- **TechDocs templates:** Example markdown documentation

### Registering Entities

Add entities to the catalog:

```yaml
# examples/entities/sample-service.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: sample-service
  description: A sample service for demonstration
  tags:
    - example
    - microservice
spec:
  type: service
  lifecycle: production
  owner: team-a
```

Import via Backstage UI or place in your Git repository:

```yaml
# app-config.yaml
catalog:
  locations:
    - type: url
      target: https://github.com/your-org/your-repo/blob/main/examples/entities/*.yaml
```

## 🔌 Popular Plugins

### GitHub Integration

```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}
```

### CI/CD Integration

```yaml
catalog:
  providers:
    github:
      providerId:
        organization: your-org
        catalogPath: /catalog-info.yaml
```

### Kubernetes Integration

```yaml
kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'
```

## 🧪 Cleanup

```bash
cd ~/projects/data-stack/data-stacks/backstage-on-eks
./cleanup.sh
```

## 📖 Additional Resources

- [Backstage Documentation](https://backstage.io/docs)
- [Backstage GitHub](https://github.com/backstage/backstage)
- [Backstage Plugins](https://backstage.io/plugins)
- [Backstage Showcase](https://backstage.io/showcase)

## 🤝 Contributing

Contributions to the DoEKS Backstage integration are welcome! Please open an issue or submit a pull request.

## 📄 License

Backstage is licensed under the Apache 2.0 License.

## 🆘 Support

For DoEKS-specific issues, open an issue in the [Data on EKS repository](https://github.com/awslabs/data-on-eks/issues).

For Backstage-specific issues, visit the [Backstage GitHub discussions](https://github.com/backstage/backstage/discussions).
