#!/bin/bash

# 1. Levanta a Infra
echo "Criando Container no Proxmox..."
terraform init && terraform apply -auto-approve

# 2. Espera o container subir (simples sleep ou wait-for-it)
sleep 10

# 3. Configura o Banco
echo "Configurando Banco de Dados..."
# Cria inventário dinâmico ou estático temporário
echo "[db_servers]" > inventory.ini
echo "192.168.1.50 ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa" >> inventory.ini

ansible-playbook -i inventory.ini playbook.yml