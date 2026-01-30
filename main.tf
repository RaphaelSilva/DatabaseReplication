terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.pve_host
  api_token = "${var.pve_token_id}=${var.pve_token_secret}"
  insecure  = true
}

resource "proxmox_virtual_environment_container" "db_container" {
  node_name = var.pve_node
  vm_id     = var.container_vmid

  initialization {
    hostname = var.container_hostname

    ip_config {
      ipv4 {
        address = var.container_ip
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
    type            = "ubuntu"
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