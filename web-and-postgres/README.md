# Web server and PostgreSQL

nginx and PostgreSQL 18 on the same Linux server, with a database and a login role for your app. PostgreSQL listens on localhost only, so your app on the server can reach it and the internet can't.

It uses two circuits:

| Circuit | What it does here |
| --- | --- |
| [circuit-nginx](https://github.com/conn3xorg/circuit-nginx) v0.3.0 | Installs nginx, serves `index.html` on port 80, and opens the port in firewalld or ufw if either is running. |
| [circuit-postgres](https://github.com/conn3xorg/circuit-postgres) v0.3.0 | Adds the PostgreSQL project's own repository, installs PostgreSQL 18, creates the `app` role with your password and the `app` database it owns. |

## Before you start

- Conn3x v0.20.0 or later, [installed](https://docs.conn3x.org/install).
- A Linux server running Rocky Linux, RHEL, AlmaLinux, Fedora, Debian or Ubuntu, with systemd. Use one you can afford to change, such as a fresh cloud VM. This README uses `203.0.113.10`; put your server's address in its place.
- SSH access with a key, as `root` or as a user with passwordless sudo.
- Outbound HTTPS from the server to `apt.postgresql.org` or `download.postgresql.org`.

If you've never logged in to the server, do it once so its host key lands in `~/.ssh/known_hosts`:

```sh
ssh root@203.0.113.10 true
```

## Run it

```sh
git clone https://github.com/conn3xorg/examples
cd examples/web-and-postgres
```

Write `terraform.tfvars`:

```hcl
# terraform.tfvars
hosts                = { app1 = "203.0.113.10" }
ssh_private_key_file = "~/.ssh/id_ed25519"
```

If you log in as a regular user with sudo, add `ssh_user = "admin"` and `ssh_become = true`.

The database password doesn't go in that file. `db_password` is ephemeral, so Conn3x never writes it to state or a plan. Give it through the environment instead:

```sh
export TF_VAR_db_password='pick-a-long-one'
```

Then:

```sh
conn3x init
conn3x plan
conn3x apply
```

Every later plan needs the password too, since Conn3x checks the file on the server against it. Keep it in the environment, then plan once more:

```sh
conn3x plan
```

```text
No changes. Your infrastructure matches the configuration.
```

Your app connects to `postgresql://app:PASSWORD@127.0.0.1:5432/app`. From the server itself you can try it with `psql -h 127.0.0.1 -U app app`.

## What the plan looks like

This is from a real run, against a Rocky Linux 10 test container on `127.0.0.1:2302`. On Debian or Ubuntu, a few resource names and paths change: the repository is `apt.postgresql.org` and the config lives in `/etc/postgresql/18/main`.

```text
  # module.postgres.conn3x_command.postgres__check["app1"] will be created
  # module.postgres.conn3x_command.postgres__database["app1/app"] will be created
  # module.postgres.conn3x_command.postgres__initdb["app1"] will be created
  # module.postgres.conn3x_command.postgres__restart["app1"] will be created
  # module.postgres.conn3x_command.postgres__role["app1/app"] will be created
  # module.postgres.conn3x_command.postgres__set_password["app1/app"] will be created
  # module.postgres.conn3x_directory.postgres__conf_dir["app1"] will be created
  # module.postgres.conn3x_directory.postgres__password_dir["app1"] will be created
  # module.postgres.conn3x_file.postgres__config["app1"] will be created
  # module.postgres.conn3x_file.postgres__hba["app1"] will be created
  # module.postgres.conn3x_file.postgres__password["app1/app"] will be created
  # module.postgres.conn3x_line.postgres__include_dir["app1"] will be created
  # module.postgres.conn3x_package.postgres_el__server["app1"] will be created
  # module.postgres.conn3x_repository.postgres_el__repo["app1"] will be created
  # module.postgres.conn3x_service.postgres__running["app1"] will be created
  # module.postgres.conn3x_service_action.postgres__reload["app1"] will be created
  # module.web.conn3x_command.nginx__debian_default_site["app1"] will be created
  # module.web.conn3x_command.nginx__firewall_auto["app1/port"] will be created
  # module.web.conn3x_directory.nginx__root["app1"] will be created
  # module.web.conn3x_file.nginx__index["app1"] will be created
  # module.web.conn3x_file.nginx__site["app1"] will be created
  # module.web.conn3x_package.nginx__package["app1"] will be created
  # module.web.conn3x_service.nginx__service["app1"] will be created
  # module.web.conn3x_service_action.nginx__reload["app1"] will be created
```

`pg_hba.conf` allows local logins and passwords over loopback, nothing else. The first rule is the one the circuit needs to manage roles:

```text
  # module.postgres.conn3x_file.postgres__hba["app1"] will be created
  + resource "conn3x_file" "postgres__hba" {
      + content    = <<-EOT
            # Managed by Conn3x.
            local all postgres peer
            local all all peer
            host all all 127.0.0.1/32 scram-sha-256
            host all all ::1/128 scram-sha-256
        EOT
      + path       = "/var/lib/pgsql/18/data/pg_hba.conf"
```

The password file shows only an HMAC. The password itself is never in the plan:

```text
  # module.postgres.conn3x_file.postgres__password["app1/app"] will be created
  + resource "conn3x_file" "postgres__password" {
      + content_hmac = "hmac-sha256:07fb521f:5bf211cecff9472854609312d1e5a73e55e3a4080ac4a747ccebdceee0e91cc7"
      + content_wo   = (write-only attribute)
      + mode         = "0600"
      + path         = "/etc/conn3x/postgres/app"
```

```text
Plan: 24 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + postgres_config_dirs = {
      + app1 = "/var/lib/pgsql/18/data"
    }
  + postgres_services    = {
      + app1 = "postgresql-18"
    }
```

The apply took 32 seconds. The PostgreSQL package was the slow part, at 15 seconds, then 9 for `initdb`.

## Want the database on its own server?

Give the two modules different hosts. On the database module, set `listen_addresses` to the database server's private address and add an `hba` rule for your web servers, as in the [circuit-postgres usage](https://github.com/conn3xorg/circuit-postgres/tree/v0.3.0#usage). Then open port 5432 to the web servers only, with [circuit-firewall](https://github.com/conn3xorg/circuit-firewall). This project doesn't test that layout.

## What it costs

A small app and PostgreSQL fit in 1 to 2 GB of memory. At the prices in the Conn3x cloud tutorials:

- **AWS:** a `t3.micro` (1 GB) is $0.0104 an hour in `us-west-2`, plus $0.005 an hour for its public IPv4 address. See [the AWS tutorial](https://docs.conn3x.org/tutorials/aws).
- **Azure:** the tutorials use `Standard_B2s_v2` at $0.0832 an hour in `westus2`. See [the Azure tutorial](https://docs.conn3x.org/tutorials/azure).
- **Google Cloud:** an `e2-small` (2 GB) is $0.0168 an hour in `us-central1`, plus $0.005 an hour for its address. See [the Google Cloud tutorial](https://docs.conn3x.org/tutorials/google-cloud).
- **DigitalOcean:** an `s-1vcpu-1gb` droplet is $6 a month. See [the DigitalOcean tutorial](https://docs.conn3x.org/tutorials/digitalocean).

## Tear it down

```sh
conn3x destroy
```

Every step in this plan that leaves something on the server has `on_remove = "forget"`, so `destroy` drops them from state and leaves nginx, PostgreSQL and your data on the server. Nobody loses a database to a stray `destroy`.

To remove everything, delete the VM at your cloud provider. On a server you're keeping, drop the database and role in `psql` first if you want them gone, then remove the packages: `nginx` and `postgresql-18` on Debian and Ubuntu, or `nginx` and `postgresql18-server` on the Red Hat family.

## Test it without a server

```sh
conn3x init
conn3x test
```

`tests/setup` starts a throwaway `ghcr.io/conn3xorg/test-rocky10` container. `tests/converge.tftest.hcl` applies this project to it with a test-only password, checks the second plan is empty with `idempotent = true`, checks PostgreSQL runs as `postgresql-18`, then removes the container. It needs Podman or Docker. It took about 16 seconds on a Mac with Podman, once the image was pulled.
