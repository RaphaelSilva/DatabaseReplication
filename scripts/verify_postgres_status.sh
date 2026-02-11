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
    echo "Environment variables loaded successfully"
    # REPLICAS_IPS=($REPLICA_1_IP $REPLICA_2_IP)
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

# A script to check the status of PostgreSQL primary and replica instances.

# PRIMARY_IP="[IP_ADDRESS]"
# REPLICAS_IPS=("[IP_ADDRESS]" "[IP_ADDRESS]")

echo "--- Checking Primary Server: $PRIMARY_IP ---"
# The [p] in grep is a trick to prevent the grep process itself from showing up in the output.
ssh root@$PRIMARY_IP "ps aux | grep '[p]ostgres'"
echo ""

for replica_ip in $REPLICAS_IPS; do
  echo "--- Checking Replica Server: $replica_ip ---"
  ssh root@$replica_ip "ps aux | grep '[p]ostgres'"
  echo ""
done

echo "--- Verification Complete ---"
