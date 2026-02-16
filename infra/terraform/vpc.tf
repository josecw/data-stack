data "aws_availability_zones" "available" {
  count = var.create_vpc ? 1 : 0
}

locals {
  azs = var.create_vpc ? slice(data.aws_availability_zones.available[0].names, 0, 2) : []
}

#---------------------------------------------------------------
# VPC
#---------------------------------------------------------------
module "vpc" {
  count = var.create_vpc ? 1 : 0

  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.name
  cidr = var.vpc_cidr

  azs = local.azs

  # Secondary CIDR - Private subnets for EKS pods and nodes
  secondary_cidr_blocks = var.secondary_cidrs

  # Primary CIDR - Private and public subnets + Secondary CIDR subnets
  private_subnets = concat(
    [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)],
    [for k, v in local.azs : cidrsubnet(var.secondary_cidrs[0], 2, k)]
  )
  public_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  private_subnet_names = concat(
    [for k, v in local.azs : "${var.name}-private-${v}"],
    [for k, v in local.azs : "${var.name}-private-secondary-${v}"]
  )
  public_subnet_names = [for k, v in local.azs : "${var.name}-public-${v}"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # IPv6 Settings
  enable_ipv6            = true
  create_egress_only_igw = true

  public_subnet_ipv6_prefixes  = [for k, v in local.azs : k]
  private_subnet_ipv6_prefixes = [for i in range(length(local.azs) * 2) : i + length(local.azs)] # Start after public prefixes

  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_assign_ipv6_address_on_creation = true

  public_subnet_tags = merge(var.public_subnet_tags, {
    "kubernetes.io/role/elb" = 1
  })

  private_subnet_tags = merge(var.private_subnet_tags, {
    "kubernetes.io/role/internal-elb" = 1
    # Karpenter discovery tag will be added by the blueprint
    "karpenter.sh/discovery" = var.name
  })

  tags = {
      Name = "${var.name}-vpc"
  }

}

#---------------------------------------------------------------
# VPC Endpoints
#---------------------------------------------------------------

# Data source for VPC CIDR
data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  vpc_id              = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  vpc_cidr_block      = var.create_vpc ? module.vpc[0].vpc_cidr_block : data.aws_vpc.selected.cidr_block
  vpc_ipv6_cidr_block = var.create_vpc ? module.vpc[0].vpc_ipv6_cidr_block : data.aws_vpc.selected.ipv6_cidr_block
  
  # Subnet IDs for Interface endpoints
  private_subnet_ids = var.create_vpc ? module.vpc[0].private_subnets : var.private_subnet_ids
  public_subnet_ids = var.create_vpc ? module.vpc[0].public_subnets : var.public_subnet_ids
  

  # Route table IDs for Gateway endpoints
  route_table_ids = var.create_vpc ? concat(
      module.vpc[0].private_route_table_ids,
      module.vpc[0].public_route_table_ids
    ) : concat(
      var.private_route_table_ids,
      var.public_route_table_ids
    )
}


# VPC Endpoints Security Group
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = local.vpc_id
  tags = {
      Name = "${var.name}-vpc-endpoints-sg"
    }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "Allow HTTPS from VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc_cidr_block
}


resource "aws_security_group" "vpc_endpoint_s3" {

  name_prefix = "${var.name}-vpc-endpoint-s3"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = concat([local.vpc_cidr_block], var.secondary_cidrs)
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    ipv6_cidr_blocks = local.vpc_ipv6_cidr_block != "" ? [local.vpc_ipv6_cidr_block] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
      Name = "${var.name}-vpc-endpoint-s3"
  }
}

module "vpc_endpoints" {

  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  vpc_id = local.vpc_id

  endpoints = {
    s3 = {
      service            = "s3"
      subnet_ids         = local.private_subnet_ids
      security_group_ids = [aws_security_group.vpc_endpoint_s3.id]
      # route_table_ids = concat(
      #   module.vpc[0].private_route_table_ids,
      #   module.vpc[0].public_route_table_ids
      # )
      route_table_ids   = local.route_table_ids 
      ip_address_type = "ipv4"
      # dns_options = {
      #   dns_record_ip_type = "dualstack"
      # }
      private_dns_enabled = true
      tags                = { Name = "${var.name}-vpgw-s3" }
    }
  }

  tags = {
      Name = "${var.name}-vpc-endpoints"
  }
}

# EC2 (Node Lifecycle)
resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-ec2"
    }
}
# ECR API (Image Pulls)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-ecr-api"
    }
}
# ECR DKR (Layer Downloads)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-ecr-dkr"
    }
}
# STS (IRSA & Auth)
resource "aws_vpc_endpoint" "sts" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-sts"
    }
}
# Autoscaling (Cluster Autoscaler support, if used)
resource "aws_vpc_endpoint" "autoscaling" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.autoscaling"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-autoscaling"
    }
}
# CloudWatch Logs (FluentBit / Node Logging)
resource "aws_vpc_endpoint" "logs" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-logs"
    }
}
# SSM (Secure Session Manager)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-ssm"
    }
}
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-ssmmessages"
    }
}
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-ec2messages"
    }
}
# Elastic Load Balancing (AWS Load Balancer Controller)
resource "aws_vpc_endpoint" "elasticloadbalancing" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.elasticloadbalancing"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-elasticloadbalancing"
    }
}
# EKS Auth (Pod Identity)
resource "aws_vpc_endpoint" "eks_auth" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.eks-auth"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-eks-auth"
    }
}
# EKS 
resource "aws_vpc_endpoint" "eks" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.eks"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-eks"
    }
}
# KMS (Key Management Service)
resource "aws_vpc_endpoint" "kms" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.kms"
  vpc_endpoint_type = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = {
      Name = "${var.name}-vpce-kms"
    }
}

# Bedrock (Interface Endpoint)
resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  
  tags = {
      Name = "${var.name}-vpce-bedrock"
    }
}

# Tag existing private subnets for Karpenter discovery
resource "aws_ec2_tag" "private_subnet_karpenter" {
  for_each    = toset(local.private_subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.name
}

# Tag existing private subnets for EKS cluster discovery
resource "aws_ec2_tag" "private_subnet_cluster" {
  for_each    = toset(local.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.name}"
  value       = "shared"
}

# Tag existing private subnets for EKS cluster discovery
resource "aws_ec2_tag" "private_subnet_internal_elb" {
  for_each    = toset(local.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

# Tag existing private subnets for EKS cluster discovery
resource "aws_ec2_tag" "public_subnet_internal_elb" {
  for_each    = toset(local.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}
