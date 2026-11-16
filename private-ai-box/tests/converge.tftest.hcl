# Starts a container, applies the configuration to it, and checks that a
# second plan is empty. It pulls the same two models a real run does.
run "host" {
  module {
    source = "./tests/setup"
  }
}

run "converge" {
  variables {
    hosts                = { ai1 = "127.0.0.1" }
    ssh_port             = run.host.port
    ssh_private_key_file = run.host.key
    ssh_known_hosts_file = run.host.known_hosts
    qdrant_api_key       = "test-only-key-0123456789"
  }
  idempotent = true

  assert {
    condition     = output.ollama_api_urls["ai1"] == "http://127.0.0.1:11434"
    error_message = "Ollama should listen on loopback only."
  }
}
