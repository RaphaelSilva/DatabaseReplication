#!/bin/bash

# Verify if the script is run from the root directory
if [ "$(basename "$(pwd)")" != "DatabaseReplication" ]; then
    echo "Please run the script from the root directory of the DatabaseReplication project."
    exit 1
fi

echo "Starting cleanup script..."

# 1. Clean Ansible generated files
echo "Removing ansible/inventory.ini..."
rm -f ./ansible/inventory.ini

# 2. Clean Terraform generated files
echo "Removing terraform/.terraform directory and state files..."
rm -rf ./terraform/.terraform
rm -f ./terraform/terraform.tfstate
rm -f ./terraform/terraform.tfstate.backup

# 3. Destroy infrastructure created by Terraform
read -p "Do you want to destroy the infrastructure created by Terraform (Proxmox containers)? (y/N): " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Destroying Terraform infrastructure..."
    cd ./terraform
    terraform init -backend-config=backend.hcl
    terraform destroy -auto-approve
    cd ../
    echo "Terraform infrastructure destroyed."
else
    echo "Skipping Terraform infrastructure destruction."
fi

echo "Cleanup complete."
