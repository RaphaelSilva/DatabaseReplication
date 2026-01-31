#!/bin/bash
# Test Proxmox API connection with your token

TOKEN_ID="${PROXMOX_TOKEN_ID:-user_name@pam!token_id}"
TOKEN_SECRET="${PROXMOX_TOKEN_SECRET:-token_secret}"
HOST="${PROXMOX_HOST:-192.168.1.100}"

echo "Testing Proxmox API connection..."
echo ""

# Test API connection
curl -k -s \
  -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
  "https://${HOST}:8006/api2/json/version" | jq .

echo ""
echo "Testing node access..."
curl -k -s \
  -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
  "https://${HOST}:8006/api2/json/nodes/pve/status" | jq .

echo ""
echo "Testing container creation permissions..."
curl -k -s \
  -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
  "https://${HOST}:8006/api2/json/nodes/pve/lxc" | jq .
