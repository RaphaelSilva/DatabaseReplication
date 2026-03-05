terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50.0"
    }
  }

  # We can use diferent backend to store the state file
  # backend "local" {}
  # backend "pg" {}
  # backend "s3" {}
  # But the golden pattern is use HCP Terraform
  # Why HCP Terraform?
  # Native Security: The State Archive is securely encrypted (AES-256) and in transit (TLS).
  # Automatic State Locking: No risk of corruption if you run two plans simultaneously.
  # Version History: Visual interface to compare what has changed between one application and another.
  # RBAC (Role-Based Access Control): Controls who can read or modify the state.
  cloud {
    organization = "eng-my-home-lab"
    workspaces {
      name = "proxmox-lxc-automation-lab"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pve_host
  api_token = "${var.pve_token_id}=${var.pve_token_secret}"
  insecure  = true
}

resource "proxmox_virtual_environment_container" "db_container" {
  for_each = var.containers

  node_name = var.pve_node
  vm_id     = each.value.vmid

  initialization {
    hostname = each.value.hostname

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.container_gateway
      }
    }

    user_account {
      keys     = var.ssh_public_key_path != "" ? [file(var.ssh_public_key_path)] : []
      password = var.container_password
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = var.os_template
    type             = "ubuntu"
  }

  cpu {
    cores = var.container_cores
  }

  memory {
    dedicated = var.container_memory
    swap      = var.container_swap
  }

  disk {
    datastore_id = var.disk_storage
    size         = var.disk_size
  }

  features {
    nesting = true
  }

  unprivileged = true
  started      = true
}
