#!/bin/bash

set -e

# --- Configuration ---
STACKS="backstage-on-eks"
TERRAFORM_DIR="terraform"
AWS_REGION="${AWS_REGION:-us-east-1}"
KUBECONFIG_FILE="kubeconfig.yaml"


# --- Get Repo Root ---
REPO_PATH=$(git rev-parse --show-toplevel)

# --- Source and Execute the Main Deployment Engine ---
# The centralized install.sh handles all the heavy lifting.
source $REPO_PATH/infra/terraform/install.sh

# --- Post-Deployment Steps ---
# Steps specific to this stack can be added here.
print_status "Running stack-specific post-deployment steps..."

# Backup the state file from the _local directory
cp "$TERRAFORM_DIR/_local/terraform.tfstate" "$TERRAFORM_DIR/terraform.tfstate.bak"
print_status "Backed up terraform.tfstate."

# Setup kubeconfig
setup_kubeconfig

# Get Backstage admin password
export KUBECONFIG=$KUBECONFIG_FILE
BACKSTAGE_USER="admin"
BACKSTUDIO_PASSWORD=$(kubectl -n backstage get secret backstage-admin-credentials -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Use default credentials")

print_status "Backstage is being deployed..."
print_status "Access Backstage at: http://backstage.<DOMAIN_NAME>"
print_status "Default credentials (if not overridden):"
print_status "  Username: $BACKSTAGE_USER"
print_status "  Password: Check kubectl secret or set in helm values"

print_next_steps
