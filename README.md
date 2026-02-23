![Data on EKS](website/static/img/doeks-logo-green.png)
# [Data on Amazon EKS (DoEKS)](https://awslabs.github.io/data-on-eks/)
_(Pronounced: "Do.eks")_
> 💡 **Optimized Blueprints for Running Scalable Data Workloads on Kubernetes with Amazon EKS**

---

## 🔗 Quick Access

| Workload Type | Repository | Website |
|---------------|------------|---------|
| 📊 **Data on EKS (This Repo)** | [github.com/awslabs/data-on-eks](https://github.com/awslabs/data-on-eks) | [awslabs.github.io/data-on-eks](https://awslabs.github.io/data-on-eks) |
| 🤖 **AI on EKS (AI/ML Blueprints)** | [github.com/awslabs/ai-on-eks](https://github.com/awslabs/ai-on-eks) | [awslabs.github.io/ai-on-eks](https://awslabs.github.io/ai-on-eks) |

### Build, Scale, and Optimize Data Platforms on [Amazon EKS](https://aws.amazon.com/eks/) 🚀

Welcome to **Data on EKS**, your launchpad for deploying **data platforms at scale** on [Amazon EKS](https://aws.amazon.com/eks/).

Explore practical examples and patterns for running Data workloads on EKS using advanced frameworks such as [Apache Spark](https://spark.apache.org/) for distributed data processing, [Apache Flink](https://flink.apache.org/) for real-time stream processing, and [Apache Kafka](https://kafka.apache.org/) for high-throughput distributed messaging. Automate and orchestrate complex workflows with [Apache Airflow](https://airflow.apache.org/) and leverage the robust capabilities of [Amazon EMR on EKS](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/emr-eks.html) to build resilient clusters, seamlessly integrating Kubernetes with big data solutions for enhanced scalability and performance.

> **Latest Release (v0.0.2):** This fork includes significant enhancements including Spotify Backstage, Keycloak integration, tiered S3 buckets, Coder development environment, Polaris + Ranger for governance, Open Metadata, and the LGTM observability stack. See [Release 0.0.2](https://github.com/josecw/data-stack/releases/tag/0.0.2) for details.

> **Note:** DoEKS is in active development. For upcoming features and enhancements, check out the [issues](https://github.com/awslabs/data-on-eks/issues) section.


## 🏗️ Architecture
The diagram below showcases the wide array of open-source data tools, Kubernetes operators, and frameworks used by DoEKS. It also highlights the seamless integration of AWS Data Analytics managed services with the powerful capabilities of DoEKS open-source tools.

<img width="779" alt="image" src="https://user-images.githubusercontent.com/19464259/208900860-a7ccdaeb-158d-4767-baad-fbc76388bc09.png">


## 🌟 Features
Data on EKS(DoEKS) solution is categorized into the following focus areas.

🎯  [Data Analytics](https://awslabs.github.io/data-on-eks/docs/blueprints/data-analytics) on EKS

🎯  [Streaming Platforms](https://awslabs.github.io/data-on-eks/docs/blueprints/streaming-platforms) on EKS

🎯  [Scheduler Workflow Platforms](https://awslabs.github.io/data-on-eks/docs/blueprints/job-schedulers) on EKS

🎯  [Distributed Databases & Query Engine](https://awslabs.github.io/data-on-eks/docs/blueprints/distributed-databases) on EKS

## 🏃‍♀️ Getting Started
In this repository, you'll find a variety of deployment blueprints for creating Data/ML platforms with Amazon EKS clusters. These examples are just a small selection of the available blueprints - visit the [DoEKS website](https://awslabs.github.io/data-on-eks/) for the complete list of options.


### 📊 Data

Here are some of the ready-to-deploy blueprints included in this repo:

| Blueprint | Description |
|-------------|-------------|
| 🚀 **[EMR-on-EKS with Karpenter](https://awslabs.github.io/data-on-eks/docs/blueprints/amazon-emr-on-eks/emr-eks-karpenter)** | Run EMR Spark workloads on EKS with cost-effective autoscaling |
| 🚀 **[Spark Operator with YuniKorn](https://awslabs.github.io/data-on-eks/docs/blueprints/data-analytics/spark-operator-yunikorn)** | Self-managed Spark with multi-tenant scheduling |
| 🚀 **[Apache Flink Operator](https://awslabs.github.io/data-on-eks/docs/blueprints/streaming-platforms/flink)** | Self-managed Flink clusters on EKS |
| 🚀 **[Apache Kafka with Strimzi](https://awslabs.github.io/data-on-eks/docs/blueprints/streaming-platforms/kafka)** | High-throughput Kafka messaging on EKS |
| 🚀 **[Airflow on EKS](https://awslabs.github.io/data-on-eks/docs/blueprints/job-schedulers/self-managed-airflow)** | DAG-based data pipeline orchestration using Apache Airflow |
| 🚀 **[Argo Workflows](https://awslabs.github.io/data-on-eks/docs/blueprints/job-schedulers/argo-workflows-eks)** | Kubernetes-native workflow engine for CI/CD or data pipelines |

### 🎛️ Platform & DevOps

Platform and developer productivity blueprints for managing your data infrastructure:

| Blueprint | Description |
|-------------|-------------|
| 🔐 **[Keycloak OIDC Provider](infra/terraform/keycloak-v2.tf)** | Identity and access management with OIDC integration for EKS |
| 🔑 **[Tiered S3 Buckets](infra/terraform/storage-v2.tf)** | Bronze/Silver/Gold buckets following Medallion architecture |
| 👥 **[Teams with Keycloak Integration](infra/terraform/teams-v3.tf)** | Team-based access control with Keycloak RBAC |
| 💻 **[Coder Development Environment](infra/terraform/coder-v4.tf)** | Remote development environments with VSCode, Jupyter, RStudio templates |
| 🎭 **[Spotify Backstage](data-stacks/backstage-on-eks/README.md)** | Developer portal platform with service catalog, TechDocs, and plugins |
| 🔍 **[Open Metadata](infra/terraform/openmetadata-v6.tf)** | Enterprise metadata platform for cataloging and lineage |

### 🛡️ Security & Governance

Security, authorization, and compliance blueprints:

| Blueprint | Description |
|-------------|-------------|
| 🏛️ **[Polaris + Ranger](infra/terraform/polaris-ranger.tf)** | Apache Polaris for Iceberg catalog and Ranger for fine-grained authorization |
| 📋 **[Open Metadata](infra/terraform/openmetadata-v6.tf)** | Enterprise metadata platform with data catalog and governance |

### 📊 Observability & Monitoring

Observability stack for logs, metrics, and traces:

| Blueprint | Description |
|-------------|-------------|
| 📈 **[LGTM Stack](infra/terraform/lgtm-v8.tf)** | Loki (logs), Grafana (metrics), Tempo (traces) for full observability |


## 📚 Documentation
For instructions on how to deploy Data on EKS patterns and run sample tests, visit the [DoEKS website](https://awslabs.github.io/data-on-eks/).

## 🏆 Motivation
[Kubernetes](https://kubernetes.io/) is a widely adopted system for orchestrating containerized software at scale. As more users migrate their data platforms and workloads to Kubernetes, they often face the complexity of managing the Kubernetes ecosystem and selecting the right tools and configurations for their specific needs.

At [AWS](https://aws.amazon.com/), we understand the challenges users encounter when deploying and scaling data workloads on Kubernetes. To simplify the process and enable users to quickly conduct proof-of-concepts and build production-ready clusters, we have developed Data on EKS (DoEKS). DoEKS offers opinionated open-source blueprints that provide end-to-end logging and observability, making it easier for users to deploy and manage Spark on EKS, Airflow, Presto, Kafka and other data workloads. With DoEKS, users can confidently leverage the power of Kubernetes for their data needs without getting overwhelmed by its complexity.

## 🤝 Support & Feedback
DoEKS is maintained by AWS Solution Architects and is not an AWS service. Support is provided on a best effort basis by the Data on EKS Blueprints community. If you have feedback, feature ideas, or wish to report bugs, please use the [Issues](https://github.com/awslabs/data-on-eks/issues) section of this GitHub.

## 🔐 Security
See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## 💼 License
This library is licensed under the Apache 2.0 License.

## 🙌 Community
We're building an open-source community focused on **Data Engineering, Streaming, and Analytics** on Kubernetes.

Come join us and contribute to shaping the future of data platforms on Amazon EKS!

Built with ❤️ at AWS.

## Deployment Steps 
1. Change directory into `infra/terraform`

2. Duplicate variables.tf.example into variables.tf, and update the value accordingly.

3. Duplicate data-stack.tfvars.example into data-stack.tfvars

4. First apply the networking resources
    ```bash
    terraform apply \
    -target=module.vpc \
    -target=module.vpc_endpoints \
    -target=aws_security_group.vpc_endpoints \
    -target=aws_security_group.vpc_endpoint_s3 \
    -target=aws_vpc_endpoint.ec2 \
    -target=aws_vpc_endpoint.ecr_api \
    -target=aws_vpc_endpoint.ecr_dkr \
    -target=aws_vpc_endpoint.sts \
    -target=aws_vpc_endpoint.autoscaling \
    -target=aws_vpc_endpoint.logs \
    -target=aws_vpc_endpoint.ssm \
    -target=aws_vpc_endpoint.ssmmessages \
    -target=aws_vpc_endpoint.ec2messages \
    -target=aws_vpc_endpoint.elasticloadbalancing \
    -target=aws_vpc_endpoint.eks_auth \
    -target=aws_vpc_endpoint.eks \
    -target=aws_vpc_endpoint.kms \
    -target=aws_vpc_endpoint.bedrock \
    -target=aws_ec2_tag.private_subnet_karpenter \
    -target=aws_ec2_tag.private_subnet_cluster \
    -target=aws_ec2_tag.private_subnet_internal_elb \
    -target=aws_ec2_tag.public_subnet_internal_elb \
    -var-file=data-stack.tfvars \
    -auto-approve
    ```  

5. Then apply EKS module
    ```bash
    terraform apply -auto-approve -target=module.eks -var-file=data-stack.tfvars
    ```  

6. Then apply for the rest of resources
    ```bash
    terraform apply -auto-approve -var-file=data-stack.tfvars
    ```

## 🎯 Version 0.0.2 Highlights

This release introduces major platform enhancements and integrations:

### 🆕 New Features

- **Spotify Backstage** - Developer portal with service catalog, TechDocs, and plugin ecosystem
- **Keycloak Integration** - OIDC provider for EKS authentication and team-based RBAC
- **Tiered S3 Buckets** - Bronze/Silver/Gold buckets following Medallion architecture
- **Coder Environment** - Remote development with VSCode, Jupyter, RStudio templates
- **Polaris + Ranger** - Iceberg catalog and fine-grained authorization
- **Open Metadata** - Enterprise metadata platform for cataloging and lineage
- **LGTM Stack** - Loki, Grafana, Tempo for full observability

### 📦 Configuration

Enable new features in `data-stack.tfvars`:

```hcl
# Identity & Access
enable_keycloak          = true

# Storage
enable_tiered_storage   = true

# Platform
enable_teams_integration = true
enable_coder            = true
enable_backstage         = true

# Governance
enable_polaris          = true
enable_ranger            = true
enable_open_metadata     = true

# Observability
enable_lgtm             = true
```

### 📖 Documentation

See the following files for detailed deployment guides:
- `PHASE8-LGTM.md` - LGTM Stack deployment
- `PHASE6-OPENMETADATA.md` - Open Metadata setup
- `PHASE5-POLARIS-RANGER.md` - Polaris + Ranger configuration
- `data-stacks/backstage-on-eks/README.md` - Backstage integration

## 📈 Release Notes

- **[v0.0.2](https://github.com/josecw/data-stack/releases/tag/0.0.2)** (Latest) - Phases 1-6 + Backstage + LGTM
- **v0.0.1** - Initial fork from AWS Labs

