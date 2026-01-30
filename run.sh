#!/bin/bash

# TODO: Load variables from terraform.tfvars

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | xargs)
fi

# 1. Create Container in Proxmox
echo "Creating Container in Proxmox..."
terraform init && terraform apply -auto-approve

# 2. Wait for the container to boot up (simple sleep or wait-for-it)
sleep 10

# 3. Configure the Database
echo "Configuring the Database..."
# Create dynamic or static temporary inventory
echo "[db_servers]" > inventory.ini
echo "$PRIMARY_IP ansible_user=$ANSIBLE_USER ansible_ssh_private_key_file=~/.ssh/id_rsa" >> inventory.ini

ansible-playbook -i inventory.ini playbook.yml