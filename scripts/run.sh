#!/bin/bash
#verify if the script is run from the root directory
if [ "$(basename "$(pwd)")" != "DatabaseReplication" ]; then
    echo "Please run the script from the root directory"
    exit 1
fi

echo "Starting the script..."
# Load environment variables from parent directory
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Load IPs from terraform.tfvars
TF_VARS="./terraform/terraform.tfvars"
if [ -f "$TF_VARS" ]; then
    echo "Loading IPs from $TF_VARS..."
    # Extract all IPs that are not commented out
    ALL_IPS=$(grep '^[[:space:]]*ip[[:space:]]*=[[:space:]]*"' "$TF_VARS" | cut -d'"' -f2 | cut -d'/' -f1)

    PRIMARY_IP=$(echo "$ALL_IPS" | head -n 1)
    REPLICAS_IPS=$(echo "$ALL_IPS" | tail -n +2)
fi

# 1. Create Container in Proxmox
echo "Creating Container in Proxmox..."
cd ./terraform
terraform init -backend-config=backend.hcl 
terraform apply -auto-approve
cd ../
sleep 10

# 2. Configure the Database
cd ./ansible
echo "Configuring the Database..."
cat <<EOF > inventory.ini
[primary]
$PRIMARY_IP

[replicas]
$REPLICAS_IPS

[postgres_all:children]
primary
replicas

[postgres_all:vars]
ansible_user=$ANSIBLE_USER
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

ansible all -i inventory.ini -m ping

ansible-playbook -i inventory.ini playbook.yml -e "replicator_db_password=$REPLICATOR_PASSWORD"