# node_exporter, Prometheus and Grafana on one server, each from its
# official release or repository. Prometheus scrapes node_exporter, and
# Grafana reads Prometheus. Prometheus and Grafana listen on 127.0.0.1, so
# you reach Grafana through an SSH tunnel.
module "node_exporter" {
  source = "github.com/conn3xorg/circuit-node-exporter?ref=v0.1.5"

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become
}

module "prometheus" {
  source = "github.com/conn3xorg/circuit-prometheus?ref=v0.1.2"

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  scrape_targets = { node = ["127.0.0.1:9100"] }

  depends_on = [module.node_exporter]
}

# A test in a container leaves Grafana out: its systemd unit sandboxes
# itself in ways an unprivileged container can't set up.
module "grafana" {
  source = "github.com/conn3xorg/circuit-grafana?ref=v0.2.0"
  count  = var.in_container ? 0 : 1

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  admin_password = var.grafana_admin_password

  datasources = [{
    name       = "Prometheus"
    type       = "prometheus"
    uid        = "prometheus"
    url        = "http://127.0.0.1:9090"
    is_default = true
  }]
}

output "grafana_url" {
  value = one(module.grafana[*].url)
}

output "prometheus_jobs" {
  value = module.prometheus.jobs
}
