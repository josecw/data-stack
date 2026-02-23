#!/bin/bash

set -e

# --- Configuration ---
STACKS="backstage-on-eks"
TERRAFORM_DIR="terraform"

# --- Get Repo Root ---
REPO_PATH=$(git rev-parse --show-toplevel)

# --- Source and Execute the Main Cleanup Engine ---
source $REPO_PATH/infra/terraform/cleanup.sh

print_status "Backstage cleanup completed."
