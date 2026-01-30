# Database Replication - Terraform Configuration

Repository for Database Learning Replication and Containers in LXC (Infrastructure as Code)

## Overview
This project uses Terraform to provision Proxmox LXC containers for database replication using the **bpg/proxmox** provider.

## Prerequisites
- Proxmox VE server with API access
- API Token created in Proxmox
- SSH public key for container access
- Terraform installed (version 1.0+)

## Security Setup

### 1. Protect Your Secrets
Your sensitive data is stored in `terraform.tfvars` which is **automatically ignored by git**.

### 2. Initial Setup
Copy the example configuration:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:
```hcl
pve_host            = "https://YOUR_PROXMOX_IP:8006"
pve_token_id        = "your_user@pam!your_token_id"
pve_token_secret    = "your_token_secret"
container_password  = "your_secure_password"
# ... other values
```

### 3. Create Proxmox API Token
1. Log into Proxmox web UI
2. Go to Datacenter → Permissions → API Tokens
3. Create a new token with appropriate permissions
4. Copy the token ID and secret to `terraform.tfvars`

## Usage

### Initialize Terraform
```bash
terraform init
```

### Plan Changes
```bash
terraform plan
```

### Apply Configuration
```bash
terraform apply
```

### Destroy Resources
```bash
terraform destroy
```

## Configuration Variables

All variables are defined in `variables.tf` with sensible defaults where appropriate.

### Required Variables (no defaults):
- `pve_host` - Proxmox server URL
- `pve_token_id` - API token ID
- `pve_token_secret` - API token secret
- `container_password` - Container root password
- `container_ip` - Container IP with CIDR
- `container_gateway` - Network gateway
- `os_template` - OS template path in Proxmox
- `ssh_public_key` - Your SSH public key

### Optional Variables (with defaults):
- `pve_node` - Proxmox node name (default: "pve")
- `container_vmid` - Container VM ID (default: 100)
- `container_hostname` - Container hostname (default: "postgres-dev")
- `container_cores` - CPU cores (default: 2)
- `container_memory` - RAM in MB (default: 2048)
- `container_swap` - Swap in MB (default: 512)
- `network_bridge` - Network bridge (default: "vmbr0")
- `disk_storage` - Storage datastore (default: "local-lvm")
- `disk_size` - Disk size in GB (default: 8)

## Security Best Practices

✅ **DO:**
- Keep `terraform.tfvars` local and never commit it
- Use the example file as a template
- Use sensitive = true for secret variables
- Rotate API tokens regularly
- Use strong passwords

❌ **DON'T:**
- Commit `terraform.tfvars` to version control
- Share your `.env` file
- Hardcode secrets in `.tf` files
- Use default passwords in production

## Files in This Project

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `terraform.tfvars` - **Your secrets (gitignored)**
- `terraform.tfvars.example` - Template for configuration
- `.gitignore` - Protects sensitive files
- `playbook.yml` - Ansible playbook for configuration
- `run.sh` - Automation script

## Migration from telmate/proxmox

This configuration uses the newer **bpg/proxmox** provider instead of the older **telmate/proxmox** provider:

- ✅ Better maintained and more active development
- ✅ More comprehensive API coverage
- ✅ Better support for Proxmox VE 7.x and 8.x
- ✅ Cleaner resource structure

The main resource changed from `proxmox_lxc` to `proxmox_virtual_environment_container`.

## Troubleshooting

### Error: Failed to connect to Proxmox
- Check that `pve_host` is correct and accessible
- Verify API token has correct permissions
- Check firewall rules allow connection to port 8006

### Error: Template not found
- Ensure the OS template exists in Proxmox
- Verify the path in `os_template` variable
- Download template in Proxmox: `pveam update && pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst`

### Error: Invalid API token
- Verify token ID format: `user@realm!token_name`
- Check token hasn't expired
- Ensure token has necessary privileges


DatabaseReplication/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions with defaults
├── terraform.tfvars           # Your secrets (GITIGNORED) 🔒
├── terraform.tfvars.example   # Safe template
├── .gitignore                 # Protects sensitive files
├── README.md                  # Documentation
├── playbook.yml               # Ansible playbook
├── run.sh                     # Automation script
├── test_connection.sh         # API connection test
└── test_create.sh             # Creation permission test