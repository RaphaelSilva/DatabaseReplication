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
cat <<EOF > inventory.ini
[primary]
$PRIMARY_IP

[replicas]
$REPLICA_1_IP
$REPLICA_2_IP

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