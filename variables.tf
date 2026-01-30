# variables.tf

# Proxmox Connection Settings
variable "pve_host" {
  description = "IP ou URL do Proxmox (ex: https://192.168.1.10:8006/)"
  type        = string
}

variable "pve_token_id" {
  description = "API Token ID (ex: root@pam!terraform)"
  type        = string
  sensitive   = true
}

variable "pve_token_secret" {
  description = "API Token Secret"
  type        = string
  sensitive   = true
}

# Proxmox Node Configuration
variable "pve_node" {
  description = "Nome do nó Proxmox (ex: pve)"
  type        = string
  default     = "pve"
}

# Container Configuration
variable "container_vmid" {
  description = "ID do container (ex: 100, 101, etc)"
  type        = number
  default     = 100
}

variable "container_hostname" {
  description = "Hostname do container"
  type        = string
  default     = "postgres-dev"
}

variable "container_password" {
  description = "Senha do container"
  type        = string
  sensitive   = true
}

# Network Configuration
variable "container_ip" {
  description = "IP do container com CIDR (ex: 192.168.1.50/24)"
  type        = string
}

variable "container_gateway" {
  description = "Gateway do container (ex: 192.168.1.1)"
  type        = string
}

variable "network_bridge" {
  description = "Bridge de rede (ex: vmbr0)"
  type        = string
  default     = "vmbr0"
}

# OS Template
variable "os_template" {
  description = "Template do OS (ex: local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst)"
  type        = string
}

# Resources
variable "container_cores" {
  description = "Número de cores da CPU"
  type        = number
  default     = 2
}

variable "container_memory" {
  description = "Memória RAM em MB"
  type        = number
  default     = 2048
}

variable "container_swap" {
  description = "Swap em MB"
  type        = number
  default     = 512
}

# Storage
variable "disk_storage" {
  description = "Datastore para o disco (ex: local-lvm)"
  type        = string
  default     = "local-lvm"
}

variable "disk_size" {
  description = "Tamanho do disco em GB"
  type        = number
  default     = 8
}

# SSH Configuration
variable "ssh_public_key_path" {
  description = "Caminho para sua chave pública SSH (ex: ~/.ssh/id_rsa.pub) - deixe vazio se não tiver"
  type        = string
  default     = ""
}