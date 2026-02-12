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
    echo "Environment variables loaded."    
fi

# Load IPs from terraform.tfvars
TF_VARS="./terraform/terraform.tfvars"
if [ -f "$TF_VARS" ]; then
    echo "Loading IPs from $TF_VARS..."
    # Extract all IPs that are not commented out
    ALL_IPS=$(grep '^[[:space:]]*ip[[:space:]]*=[[:space:]]*"' "$TF_VARS" | cut -d'"' -f2 | cut -d'/' -f1)

    PRIMARY_IP=$(echo "$ALL_IPS" | head -n 1)
    REPLICAS_IPS=$(echo "$ALL_IPS" | tail -n +2)
    echo "Environment variables loaded from terraform.tfvars."
fi

# 1. Create Container in Proxmox
function create_container() {
    echo "Creating Container in Proxmox..."
    cd ./terraform
    terraform init # -backend-config=backend.hcl 
    terraform plan 
    terraform apply -auto-approve
    cd ../
}


function create_ansible_inventory() {
    echo "Creating Ansible inventory..."
    cd ./ansible
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
    cd ../
}

function check_container() {
    echo "Checking if containers are running..."
    cd ./terraform
    terraform output
    cd ../
}

function check_ansible() {
    echo "Checking if Ansible is working..."
    cd ./ansible
    # if all IP in inventory.ini are reachable then return 0 else return 1
    if ansible all -i inventory.ini -m ping; then
        return 0
    else
        return 1
    fi
    cd ../
}


# 2. Configure the Database
function configure_database() {
    echo "Configuring the Database..."    
    if [ -f "./ansible/inventory.ini" ]; then
        echo "Ansible inventory already exists. Skipping creation."        
    else
        create_ansible_inventory
    fi
    # try to check ansible 3 times
    for i in {1..3}; do
        if check_ansible; then
            break
        fi
        echo "Ansible is not working. Retrying in 10 seconds..."
        sleep 10
    done
    cd ./ansible
    ansible-playbook -i inventory.ini playbook.yml -e "replicator_db_password=$REPLICATOR_PASSWORD"
    cd ../
}

function configure_postgres_backend() {
    echo "Configuring send status to backend..."
    cd ./terraform
    # locate # backend "pg" {} in main.tf and uncomment it
    sed -i 's/# backend "pg" {/backend "pg" {/g' main.tf
    export PG_CONN_STR="postgres://postgres:${POSTGRES_PASSWORD}@${PRIMARY_IP}:5432/terraform_remote_state?sslmode=disable"
    terraform init -migrate-state
    cd ../
}

function recover_local_backend() {
    echo "Pulling remote state from Postgres to local terraform.tfstate..."
    cd ./terraform
    export PG_CONN_STR="postgres://postgres:${POSTGRES_PASSWORD}@${PRIMARY_IP}:5432/terraform_remote_state?sslmode=disable"
    terraform init -reconfigure
    # locate backend "pg" {} in main.tf and comment it
    sed -i 's/backend "pg" {/# backend "pg" {/g' main.tf
    cd ../
}

case "$1" in
    "deploy")
        create_container
        sleep 20
        configure_database
        ;;
    "container")
        create_container
        ;;
    "destroy")
        ./scripts/cleanup.sh
        ;;
    "config")
        configure_database
        ;;
    "check")
        check_container
        check_ansible
        ;;
    "check_ansible")
        check_ansible
        ;;
    "check_container")
        check_container
        ;;
    "configure_postgres_backend")
        configure_postgres_backend
        ;;
    "recover_local_backend")
        recover_local_backend
        ;;
    *) 
        echo "Usage: $0 <command>
deploy -------------------------- deploy container and configure database
container ----------------------- deploy container only
destroy ------------------------- destroy container
config -------------------------- configure database
check --------------------------- check container and ansible
check_ansible ------------------- check ansible
check_container ----------------- check container
configure_postgres_backend ------ configure postgres backend
recover_local_backend ----------- recover local backend
"
        exit 1
        ;;
esac