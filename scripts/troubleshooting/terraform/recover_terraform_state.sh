#!/bin/bash

# This script helps recover or localize your Terraform state from the remote Postgres backend.

# 1. Pull the remote state to a local file
echo "📥 Pulling remote state from Postgres to local terraform.tfstate..."
terraform init -backend-config=backend.hcl -reconfigure

if [ $? -eq 0 ]; then
    echo "✅ Success! Remote state has been saved to 'terraform.tfstate'."
    echo "⚠️  Note: This file contains sensitive information. Do not commit it to Git."
else
    echo "❌ Error: Failed to pull state. Make sure your 'backend.hcl' is correct and you have network access to the database."
    exit 1
fi

# 2. Instructions for full local recovery
echo ""
echo "💡 To switch back to LOCAL mode permanently:"
echo "1. Comment out or delete the 'backend \"pg\" {}' block in 'main.tf'."
echo "2. Run: terraform init -migrate-state"
