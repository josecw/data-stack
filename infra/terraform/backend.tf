# Terraform Backend Configuration - S3
# Store state in S3 bucket for team collaboration and state locking

terraform {
  backend "s3" {
    bucket         = "yggdrasil-stg-tf-state-ap-southeast-1"
    key            = "eks-beta/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    # use_lockfile   = true
    #dynamodb_table = "yggdrasil-stg-tf-state-lock"
    
    # Optional: Enable versioning on the S3 bucket for state history
    # versioning = true
  }
}

