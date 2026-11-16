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
