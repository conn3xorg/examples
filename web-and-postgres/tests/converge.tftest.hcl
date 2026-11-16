# Starts a container, applies the configuration to it, and checks that a
# second plan is empty.
run "host" {
  module {
    source = "./tests/setup"
  }
}

run "converge" {
  variables {
    hosts                = { app1 = "127.0.0.1" }
    ssh_port             = run.host.port
    ssh_private_key_file = run.host.key
    ssh_known_hosts_file = run.host.known_hosts
    db_password          = "test-only-password"
  }
  idempotent = true

  assert {
    condition     = output.postgres_services["app1"] == "postgresql-18"
    error_message = "PostgreSQL 18 should run as postgresql-18 on Rocky Linux."
  }
}
