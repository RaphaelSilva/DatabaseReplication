#!/bin/bash
# Test actual container creation to get the exact error

TOKEN_ID="${PROXMOX_TOKEN_ID:-user_name@pam!token_id}"
TOKEN_SECRET="${PROXMOX_TOKEN_SECRET:-token_secret}"
HOST="${PROXMOX_HOST:-192.168.1.100}"

echo "Testing container creation API call..."
echo ""

# Try to create a test container (this will fail but show us the exact error)
curl -k -i -X POST \
  -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "vmid=999" \
  --data-urlencode "ostemplate=local:vztmpl/ubuntu-25.04-standard_25.04-1.1_amd64.tar.zst" \
  --data-urlencode "hostname=test-permissions" \
  --data-urlencode "rootfs=WorkLoad:8" \
  --data-urlencode "cores=2" \
  --data-urlencode "memory=2048" \
  --data-urlencode "swap=512" \
  --data-urlencode "net0=name=eth0,bridge=vmbr0,ip=dhcp" \
  "https://${HOST}:8006/api2/json/nodes/pve/lxc"

echo ""
echo "====================================="
echo "If you see 403, check the error message for specific permission needed"
