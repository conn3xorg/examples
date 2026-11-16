# nginx and PostgreSQL on the same server. PostgreSQL listens on localhost
# only, so your app on the server reaches it and nothing else does.
module "web" {
  source = "github.com/conn3xorg/circuit-nginx?ref=v0.3.0"

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  index_html = file("${path.module}/index.html")
}

module "postgres" {
  source = "github.com/conn3xorg/circuit-postgres?ref=v0.3.0"

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  users          = ["app"]
  user_passwords = { app = var.db_password }
  databases      = { app = "app" }
}

output "postgres_config_dirs" {
  value = module.postgres.config_dirs
}

output "postgres_services" {
  value = module.postgres.services
}
