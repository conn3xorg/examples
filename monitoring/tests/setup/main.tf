# A throwaway systemd host for conn3x test. It's removed when the test ends.
resource "conn3x_test_container" "web1" {
  image = "ghcr.io/conn3xorg/test-ubuntu2404"
}

output "port" { value = conn3x_test_container.web1.port }
output "key" { value = conn3x_test_container.web1.private_key_file }
output "known_hosts" { value = conn3x_test_container.web1.known_hosts_file }
