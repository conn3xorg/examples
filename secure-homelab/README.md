# Secure homelab

The groundwork for any server you'd leave on your home network or the internet: SSH with keys only and stricter settings, kernel hardening, a firewall that denies what you didn't ask for, fail2ban watching SSH, and security updates every day. Run it on a fresh box before you put anything else on it.

It uses five circuits, side by side:

| Circuit | What it does here |
| --- | --- |
| [circuit-baseline](https://github.com/conn3xorg/circuit-baseline) v0.2.0 | Sets the time zone, runs chrony, sets a few network sysctls, and turns off password logins over SSH. Root can still log in with a key. |
| [circuit-hardening](https://github.com/conn3xorg/circuit-hardening) v0.3.0 | Narrows SSH's ciphers, key exchanges and MACs, limits login attempts, turns off agent and X11 forwarding, sets 23 kernel parameters, stops rare filesystems and protocols loading, turns off core dumps, sets `UMASK 027` and removes legacy daemons such as telnet. |
| [circuit-firewall](https://github.com/conn3xorg/circuit-firewall) v0.3.0 | ufw on Debian and Ubuntu, firewalld on the Red Hat family. Incoming traffic is denied except SSH and the ports you list in `allow`. |
| [circuit-fail2ban](https://github.com/conn3xorg/circuit-fail2ban) v0.3.1 | Bans an address for an hour after five failed SSH logins in ten minutes, through nftables. |
| [circuit-auto-updates](https://github.com/conn3xorg/circuit-auto-updates) v0.3.0 | unattended-upgrades on Debian and Ubuntu, dnf-automatic on Rocky Linux and Fedora, installing security updates only. It never reboots on its own. |

Two settings differ from the circuits' defaults, and both are in `main.tf` with a comment. Hardening allows local SSH forwarding, so `ssh -L` tunnels to your services keep working. And it leaves `log_martians` to ufw, which would otherwise set it back on every start.

## Before you start

- Conn3x v0.20.0 or later, [installed](https://docs.conn3x.org/install).
- A Linux server running Rocky Linux, RHEL, AlmaLinux, Fedora, Debian or Ubuntu, with systemd. A spare mini PC, a VM on Proxmox or a cloud VM all work. This README uses `192.168.1.40`.
- SSH access **with a key** that already works, as `root` or as a user with passwordless sudo. Once this applies, the server stops taking passwords.
- On Rocky Linux and AlmaLinux, fail2ban comes from EPEL, which the circuit turns on. On RHEL, turn EPEL on yourself first.

If you've never logged in to the server, do it once so its host key lands in `~/.ssh/known_hosts`:

```sh
ssh root@192.168.1.40 true
```

## Run it

```sh
git clone https://github.com/conn3xorg/examples
cd examples/secure-homelab
```

Write `terraform.tfvars`:

```hcl
# terraform.tfvars
hosts                = { lab1 = "192.168.1.40" }
ssh_private_key_file = "~/.ssh/id_ed25519"

timezone         = "America/Denver"
trusted_networks = ["192.168.1.0/24"]

# Ports your services need, besides SSH.
allow = [
  { port = "443/tcp" },
  { port = "8096/tcp", from = "192.168.1.0/24" },
]
```

`trusted_networks` keeps fail2ban from banning your own machines. If you log in as a regular user with sudo, add `ssh_user = "admin"` and `ssh_become = true`.

The firewall keeps SSH open on the port Conn3x logs in on. If you reach the server through a port forward, say port 2222 on your router to 22 on the server, set `ssh_allow = ["22/tcp"]`, or turning the firewall on cuts SSH.

Then:

```sh
conn3x init
conn3x plan
conn3x apply
```

Plan once more:

```sh
conn3x plan
```

```text
No changes. Your infrastructure matches the configuration.
```

That second plan also proves you can still log in. It connects with the new SSH settings and the firewall in place.

## What the plan looks like

This is from a real `conn3x plan` against an Ubuntu 24.04 test container on `127.0.0.1:2305`, so SSH shows as port 2305. On your server it's your own address and port. Counted by module, the plan's resources are:

| Module | Resources | Of which |
| --- | --- | --- |
| `baseline` | 14 | 5 sysctls, the SSH drop-in, chrony, tzdata and the time zone |
| `hardening` | 48 | 23 sysctls, 13 legacy packages to remove, the SSH drop-in, modprobe, limits, coredump, umask and cron |
| `firewall[0]` | 4 | the ufw package, the SSH rule, default deny, and turning ufw on |
| `fail2ban` | 8 | packages, the jail file, the service and its reload |
| `auto_updates` | 8 | unattended-upgrades, its config, the schedule and two timers |

```text
Plan: 82 to add, 0 to change, 0 to destroy.
```

The SSH drop-in from hardening, with the forwarding change:

```text
  # module.hardening.conn3x_file.hardening__sshd["lab1"] will be created
  + resource "conn3x_file" "hardening__sshd" {
      + content    = <<-EOT
            # Written by Conn3x. Changes here are overwritten on the next apply.
            AllowAgentForwarding no
            AllowTcpForwarding local
            Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
            ClientAliveCountMax 3
            ClientAliveInterval 300
            KbdInteractiveAuthentication no
            KexAlgorithms -ecdh-sha2-*,diffie-hellman-group14-*,diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha1
            LogLevel VERBOSE
            LoginGraceTime 30
            MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
            MaxAuthTries 4
            MaxStartups 10:30:60
            X11Forwarding no
        EOT
      + path       = "/etc/ssh/sshd_config.d/01-conn3x-hardening.conf"
```

And fail2ban's jail, on the port Conn3x logs in on:

```text
  # module.fail2ban.conn3x_file.fail2ban__config["lab1"] will be created
  + resource "conn3x_file" "fail2ban__config" {
      + content    = <<-EOT
            # Written by Conn3x. Changes here are overwritten on the next apply.
            [DEFAULT]
            bantime = 3600
            findtime = 600
            maxretry = 5
            ignoreip = 127.0.0.1/8 ::1
            backend = systemd
            banaction = nftables
            banaction_allports = nftables[type=allports]

            [sshd]
            enabled = true
            port = 2305
            backend = systemd
        EOT
      + path       = "/etc/fail2ban/jail.d/conn3x.local"
```

## What was run, and what wasn't

A container shares its host's kernel and network stack, so it can't change kernel parameters, set the clock or turn on a firewall. The apply here was in a container, with `in_container = true`, which leaves those parts out: the 28 sysctls, the firewall, and chrony setting the clock. Everything else applied, 51 resources in 70 seconds, and the second plan was empty.

The plan above is the full one, with `in_container = false`. The kernel parameters and the firewall weren't applied by this project. Each circuit's README says where they were tested, on droplets with SELinux enforcing among them. Leave `in_container` at `false` on your server.

## What it costs

These circuits add almost nothing to a server's load. On hardware you already have at home, there's nothing to pay. On a cloud VM, the smallest size does, at the prices in the Conn3x cloud tutorials:

- **AWS:** a `t3.micro` (1 GB) is $0.0104 an hour in `us-west-2`, plus $0.005 an hour for its public IPv4 address. See [the AWS tutorial](https://docs.conn3x.org/tutorials/aws).
- **Azure:** the tutorials use `Standard_B2s_v2` at $0.0832 an hour in `westus2`. See [the Azure tutorial](https://docs.conn3x.org/tutorials/azure).
- **Google Cloud:** an `e2-small` (2 GB) is $0.0168 an hour in `us-central1`, plus $0.005 an hour for its address. See [the Google Cloud tutorial](https://docs.conn3x.org/tutorials/google-cloud).
- **DigitalOcean:** an `s-1vcpu-1gb` droplet is $6 a month. See [the DigitalOcean tutorial](https://docs.conn3x.org/tutorials/digitalocean).

## Tear it down

Most steps have `on_remove = "forget"`, so `conn3x destroy` drops them from state and leaves the server as hardened as it was. One is different: the ufw rule that lets SSH in has `on_remove = "delete"`. On Debian and Ubuntu, `destroy` deletes that rule, while ufw stays on and keeps denying everything else.

So on a server you want to keep reaching, look before you destroy:

```sh
conn3x plan -destroy
```

If it deletes the SSH rule, turn the firewall off on the server first, with `sudo ufw disable`, or take `module.firewall` out of state with `conn3x state rm 'module.firewall[0]'` so it's left as it is. Then:

```sh
conn3x destroy
```

On a cloud VM you're finished with, delete the VM at your cloud provider, and that's everything.

## Test it without a server

```sh
conn3x init
conn3x test
```

`tests/setup` starts a throwaway `ghcr.io/conn3xorg/test-ubuntu2404` container. `tests/converge.tftest.hcl` applies this project to it with `in_container = true`, checks the second plan is empty with `idempotent = true`, then removes the container. It needs Podman or Docker. It took about 25 seconds on a Mac with Podman.
