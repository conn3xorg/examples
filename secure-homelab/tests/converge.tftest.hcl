# Starts a container, applies the configuration to it, and checks that a
# second plan is empty. A container can't change kernel parameters, set the
# clock or run a firewall, so in_container leaves those parts out here.
run "host" {
  module {
    source = "./tests/setup"
  }
}

run "converge" {
  variables {
    hosts                = { lab1 = "127.0.0.1" }
    ssh_port             = run.host.port
    ssh_private_key_file = run.host.key
    ssh_known_hosts_file = run.host.known_hosts
    in_container         = true
  }
  idempotent = true
}
