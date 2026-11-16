# Monitoring stack

Prometheus, Grafana and node_exporter on one Linux server, so you can see its CPU, memory, disk and network on a dashboard. No Docker: each one comes from its project's official release or package repository and runs as its own systemd service.

It uses three circuits:

| Circuit | What it does here |
| --- | --- |
| [circuit-node-exporter](https://github.com/conn3xorg/circuit-node-exporter) v0.1.5 | Installs node_exporter 1.12.1 from the official release, checked against its SHA-256, as its own system user, on port 9100. |
| [circuit-prometheus](https://github.com/conn3xorg/circuit-prometheus) v0.1.2 | Installs Prometheus 3.15.1 from the official release on `127.0.0.1:9090`, scraping itself and node_exporter every 15 seconds and keeping 15 days of samples. |
| [circuit-grafana](https://github.com/conn3xorg/circuit-grafana) v0.2.0 | Installs Grafana OSS 13.3.0 from Grafana Labs' repository on `127.0.0.1:3000`, sets the admin password, and provisions Prometheus as the default data source. |

Prometheus and Grafana listen on loopback only. Grafana's login is plain HTTP and Prometheus has none, so you reach both through an SSH tunnel. node_exporter listens on every address, which lets a Prometheus elsewhere scrape it later. Keep port 9100 closed to the internet with your cloud firewall or [circuit-firewall](https://github.com/conn3xorg/circuit-firewall).

## Before you start

- Conn3x v0.20.0 or later, [installed](https://docs.conn3x.org/install).
- A Linux server running Rocky Linux, RHEL, AlmaLinux, Fedora, Debian or Ubuntu, with systemd. circuit-grafana was tested on servers with 1 GB of memory. This README uses `203.0.113.30`.
- SSH access with a key, as `root` or as a user with passwordless sudo.
- Outbound HTTPS from the server to `github.com` and to `apt.grafana.com` or `rpm.grafana.com`.
- On Rocky Linux, AlmaLinux and RHEL cloud images, check that Cockpit isn't holding port 9090: `systemctl disable --now cockpit.socket` frees it.

If you've never logged in to the server, do it once so its host key lands in `~/.ssh/known_hosts`:

```sh
ssh root@203.0.113.30 true
```

## Run it

```sh
git clone https://github.com/conn3xorg/examples
cd examples/monitoring
```

Write `terraform.tfvars`:

```hcl
# terraform.tfvars
hosts                = { mon1 = "203.0.113.30" }
ssh_private_key_file = "~/.ssh/id_ed25519"
```

If you log in as a regular user with sudo, add `ssh_user = "admin"` and `ssh_become = true`.

Grafana's admin password is ephemeral, so it never lands in state or a plan. Put it in the environment. It needs 8 characters or more, with no quotes, backslashes or spaces:

```sh
export TF_VAR_grafana_admin_password='pick-a-long-one'
```

Then:

```sh
conn3x init
conn3x plan
conn3x apply
```

Keep the password in the environment for later plans, and plan once more:

```sh
conn3x plan
```

```text
No changes. Your infrastructure matches the configuration.
```

## Look at it

Open a tunnel to Grafana:

```sh
ssh -N -L 3000:127.0.0.1:3000 root@203.0.113.30
```

Then browse to <http://localhost:3000> and sign in as `admin` with your password. Prometheus is already the default data source. For a host dashboard, go to **Dashboards**, **New**, **Import**, and enter ID `1860`, the community's Node Exporter Full.

Changing `TF_VAR_grafana_admin_password` and applying again resets the password in Grafana.

## What the plan looks like

This is from a real run, against an Ubuntu 24.04 test container on `127.0.0.1:2303`. On your server you'll see your own address in the IDs.

```text
  # module.grafana[0].conn3x_command.grafana__admin["mon1"] will be created
  # module.grafana[0].conn3x_command.grafana__ready["mon1"] will be created
  # module.grafana[0].conn3x_command.grafana__restart["mon1"] will be created
  # module.grafana[0].conn3x_directory.grafana__dashboards_dir["mon1"] will be created
  # module.grafana[0].conn3x_directory.grafana__password_dir["mon1"] will be created
  # module.grafana[0].conn3x_file.grafana__admin_password["mon1"] will be created
  # module.grafana[0].conn3x_file.grafana__config["mon1"] will be created
  # module.grafana[0].conn3x_file.grafana__dashboard_provider["mon1"] will be created
  # module.grafana[0].conn3x_file.grafana__datasources["mon1"] will be created
  # module.grafana[0].conn3x_package.grafana__curl["mon1"] will be created
  # module.grafana[0].conn3x_package.grafana__package["mon1"] will be created
  # module.grafana[0].conn3x_repository.grafana__repo["mon1"] will be created
  # module.grafana[0].conn3x_service.grafana__running["mon1"] will be created
  # module.node_exporter.conn3x_archive.node_exporter__unpack["mon1"] will be created
  # module.node_exporter.conn3x_download.node_exporter__download["mon1"] will be created
  ...
  # module.node_exporter.conn3x_service.node_exporter__running["mon1"] will be created
  # module.node_exporter.conn3x_user.node_exporter__user["mon1"] will be created
  # module.prometheus.data.conn3x_host.facts["mon1"] will be read during apply
  # (depends on a resource or a module with changes pending)
  # module.prometheus.conn3x_archive.prometheus__unpack["mon1"] will be created
  # module.prometheus.conn3x_command.prometheus__config["mon1"] will be created
  # module.prometheus.conn3x_command.prometheus__ready["mon1"] will be created
  ...
  # module.prometheus.conn3x_service.prometheus__running["mon1"] will be created
  # module.prometheus.conn3x_user.prometheus__user["mon1"] will be created
```

Prometheus waits for node_exporter, through `depends_on`, so it reads the server's facts during the apply rather than the plan. That's the "read during apply" line.

```text
Plan: 38 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + grafana_url     = "http://127.0.0.1:3000"
  + prometheus_jobs = [
      + "prometheus",
      + "node",
    ]
```

The apply took about a minute. The Grafana package was most of it, at 52 seconds. After it, Grafana accepted `admin` with the configured password and refused a wrong one, Prometheus reported both targets up, and a query through Grafana's data source returned `up{job="node"} = 1`.

## What it costs

All three fit in a 1 to 2 GB VM. At the prices in the Conn3x cloud tutorials:

- **AWS:** a `t3.micro` (1 GB) is $0.0104 an hour in `us-west-2`, plus $0.005 an hour for its public IPv4 address. See [the AWS tutorial](https://docs.conn3x.org/tutorials/aws).
- **Azure:** the tutorials use `Standard_B2s_v2` at $0.0832 an hour in `westus2`. See [the Azure tutorial](https://docs.conn3x.org/tutorials/azure).
- **Google Cloud:** an `e2-small` (2 GB) is $0.0168 an hour in `us-central1`, plus $0.005 an hour for its address. See [the Google Cloud tutorial](https://docs.conn3x.org/tutorials/google-cloud).
- **DigitalOcean:** an `s-1vcpu-1gb` droplet is $6 a month. See [the DigitalOcean tutorial](https://docs.conn3x.org/tutorials/digitalocean).

Prometheus's disk use grows with the number of targets and the 15 days it keeps.

## Tear it down

```sh
conn3x destroy
```

Every step in this plan that leaves something on the server has `on_remove = "forget"`, so `destroy` drops them from state and leaves all three services running on the server with their data.

To remove everything, delete the VM at your cloud provider. On a server you're keeping, stop and disable `grafana-server`, `prometheus` and `node_exporter` with `systemctl`, remove the `grafana` package, and delete `/opt/prometheus`, `/opt/node_exporter`, `/etc/prometheus` and `/var/lib/prometheus`.

## Test it without a server

```sh
conn3x init
conn3x test
```

`tests/setup` starts a throwaway `ghcr.io/conn3xorg/test-ubuntu2404` container. `tests/converge.tftest.hcl` applies this project to it, checks the second plan is empty with `idempotent = true` and that Prometheus has the `prometheus` and `node` jobs, then removes the container. It needs Podman or Docker. It took about 15 seconds on a Mac with Podman.

The test leaves Grafana out. It sets `in_container = true`, because Grafana's systemd unit sandboxes itself in ways an unprivileged container can't set up, so it never starts there. The plan and checks above, Grafana included, are from a run by hand in a privileged Podman container.
