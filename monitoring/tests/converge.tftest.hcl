# Starts a container, applies the configuration to it, and checks that a
# second plan is empty. Grafana won't start in an unprivileged container, so
# in_container leaves it out here.
run "host" {
  module {
    source = "./tests/setup"
  }
}

run "converge" {
  variables {
    hosts                  = { mon1 = "127.0.0.1" }
    ssh_port               = run.host.port
    ssh_private_key_file   = run.host.key
    ssh_known_hosts_file   = run.host.known_hosts
    grafana_admin_password = "test-only-password"
    in_container           = true
  }
  idempotent = true

  assert {
    condition     = output.prometheus_jobs == ["prometheus", "node"]
    error_message = "Prometheus should scrape itself and node_exporter."
  }
}
