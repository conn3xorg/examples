# Five circuits that make a fresh server safer to leave on the internet or
# your home network. They run side by side; none depends on another.

locals {
  # The kernel parameters circuit-baseline v0.2.0 sets by default.
  baseline_sysctl = {
    "net.ipv4.tcp_syncookies"                = "1"
    "net.ipv4.conf.all.accept_redirects"     = "0"
    "net.ipv4.conf.default.accept_redirects" = "0"
    "net.ipv4.conf.all.send_redirects"       = "0"
    "net.ipv4.icmp_echo_ignore_broadcasts"   = "1"
  }

  # The kernel parameters circuit-hardening v0.3.0 sets by default. Only a
  # test in a container turns them off, since it can't change them.
  hardening_sysctl_keys = [
    "kernel.kptr_restrict", "kernel.dmesg_restrict", "kernel.yama.ptrace_scope",
    "kernel.randomize_va_space", "dev.tty.ldisc_autoload",
    "fs.protected_hardlinks", "fs.protected_symlinks", "fs.protected_fifos",
    "fs.protected_regular", "fs.suid_dumpable",
    "net.ipv4.conf.all.rp_filter", "net.ipv4.conf.default.rp_filter",
    "net.ipv4.conf.all.accept_source_route", "net.ipv4.conf.default.accept_source_route",
    "net.ipv6.conf.all.accept_source_route", "net.ipv6.conf.default.accept_source_route",
    "net.ipv4.conf.all.secure_redirects", "net.ipv4.conf.default.secure_redirects",
    "net.ipv4.conf.default.send_redirects",
    "net.ipv6.conf.all.accept_redirects", "net.ipv6.conf.default.accept_redirects",
    "net.ipv4.icmp_ignore_bogus_error_responses", "net.ipv4.tcp_rfc1337",
  ]

  hardening_sysctl = merge(
    var.in_container ? { for k in local.hardening_sysctl_keys : k => null } : {},
    {
      # ufw sets log_martians back to 0 each time it starts, so the two
      # would undo each other on every apply. Leave it to ufw.
      "net.ipv4.conf.all.log_martians"     = null
      "net.ipv4.conf.default.log_martians" = null
    },
  )
}

# Time zone, chrony, a few network sysctls, and SSH with keys only.
module "baseline" {
  source = "github.com/conn3xorg/circuit-baseline?ref=v0.2.0"

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  timezone         = var.timezone
  sysctl           = var.in_container ? {} : local.baseline_sysctl
  chrony_set_clock = !var.in_container
}

# Stricter SSH ciphers and limits, kernel hardening, and no legacy daemons.
module "hardening" {
  source = "github.com/conn3xorg/circuit-hardening?ref=v0.3.0"

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  # "local" allows ssh -L tunnels to services on the server, and still
  # refuses -R, so nobody can publish a port through it.
  sshd_settings = { AllowTcpForwarding = "local" }
  sysctl        = local.hardening_sysctl
}

# ufw on Debian and Ubuntu, firewalld on the Red Hat family. Incoming
# traffic is denied except SSH and the ports in var.allow.
module "firewall" {
  source = "github.com/conn3xorg/circuit-firewall?ref=v0.3.0"
  count  = var.in_container ? 0 : 1

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  allow = var.allow
}

# Bans an address after five failed SSH logins in ten minutes, for an hour.
module "fail2ban" {
  source = "github.com/conn3xorg/circuit-fail2ban?ref=v0.3.1"

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  ignoreip = var.trusted_networks
}

# Security updates every day, from the distribution's own repositories.
module "auto_updates" {
  source = "github.com/conn3xorg/circuit-auto-updates?ref=v0.3.0"

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become
}
