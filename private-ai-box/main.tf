# Ollama and Qdrant on one server, both on 127.0.0.1. Neither faces the
# internet: you reach them through an SSH tunnel.
module "ollama" {
  source = "github.com/conn3xorg/circuit-ollama?ref=v0.1.4"

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  models = var.models
}

module "qdrant" {
  source = "github.com/conn3xorg/circuit-qdrant?ref=v0.1.2"

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  api_key = var.qdrant_api_key
}

output "ollama_api_urls" {
  value = module.ollama.api_urls
}
