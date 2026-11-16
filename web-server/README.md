# Single web server

nginx on one Linux server, serving the page in `index.html` on port 80. It's the smallest complete Conn3x project: one circuit, one server, and a second plan that says `No changes.`

It uses [circuit-nginx](https://github.com/conn3xorg/circuit-nginx) v0.3.0, which installs nginx, writes your page and the site config, keeps nginx running and enabled at boot, opens port 80 in firewalld or ufw if either is running, and reloads nginx when its config changes.

## Before you start

- Conn3x v0.20.0 or later, [installed](https://docs.conn3x.org/install).
- A Linux server running Rocky Linux, RHEL, AlmaLinux, Fedora, Debian or Ubuntu, with systemd. Use one you can afford to change, such as a fresh cloud VM. This README uses `203.0.113.10`; put your server's address in its place.
- SSH access with a key, as `root` or as a user with passwordless sudo.
- Nothing else on the server using port 80.

Conn3x always checks host keys, against `~/.ssh/known_hosts` by default. If you've never logged in to the server, do it once now and confirm the fingerprint:

```sh
ssh root@203.0.113.10 true
```

## Run it

This takes about ten minutes, most of it reading the plan.

```sh
git clone https://github.com/conn3xorg/examples
cd examples/web-server
```

Tell it where your server is. Conn3x reads `terraform.tfvars` on every command:

```hcl
# terraform.tfvars
hosts                = { web1 = "203.0.113.10" }
ssh_private_key_file = "~/.ssh/id_ed25519"
```

If you log in as a regular user with sudo, add `ssh_user = "admin"` and `ssh_become = true`.

Then initialize, plan and apply:

```sh
conn3x init
conn3x plan
conn3x apply
```

Type `yes` when `apply` asks. Then look at the page:

```sh
curl http://203.0.113.10/
```

Now the step that matters. Plan again:

```sh
conn3x plan
```

```text
No changes. Your infrastructure matches the configuration.
```

That's the server matching the code. From here, change `index.html` and run `conn3x apply` whenever you like.

## What the plan looks like

This is from a real run, against a Debian 13 test container on `127.0.0.1:2301`. On your server you'll see your own address in the IDs and in each `ssh` block. `nginx__debian_default_site` removes the default site Debian and Ubuntu ship, which also claims port 80.

The first plan creates eight resources:

```text
  # module.web.conn3x_command.nginx__debian_default_site["web1"] will be created
  # module.web.conn3x_command.nginx__firewall_auto["web1/port"] will be created
  # module.web.conn3x_directory.nginx__root["web1"] will be created
  # module.web.conn3x_file.nginx__index["web1"] will be created
  # module.web.conn3x_file.nginx__site["web1"] will be created
  # module.web.conn3x_package.nginx__package["web1"] will be created
  # module.web.conn3x_service.nginx__service["web1"] will be created
  # module.web.conn3x_service_action.nginx__reload["web1"] will be created
```

Each one shows what it'll do. Here's the site config, without its `ssh` block:

```text
  # module.web.conn3x_file.nginx__site["web1"] will be created
  + resource "conn3x_file" "nginx__site" {
      + content    = <<-EOT
            # Managed by circuit-nginx. Changes made here are put back on the next apply.
            server {
                listen 80 default_server;
                listen [::]:80 default_server;
                server_name _;
                root /var/www/html;
                index index.html;
            }
        EOT
      + id         = "127.0.0.1:2301:/etc/nginx/conf.d/circuit-nginx.conf"
      + mode       = "0644"
      + on_remove  = "forget"
      + path       = "/etc/nginx/conf.d/circuit-nginx.conf"
```

```text
Plan: 8 to add, 0 to change, 0 to destroy.
```

The apply took 12 seconds, nearly all of it installing the package:

```text
module.web.conn3x_package.nginx__package["web1"]: Creation complete after 12s
...
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.
```

## What it costs

nginx serving a static page runs happily in 1 GB of memory. At the prices in the Conn3x cloud tutorials:

- **AWS:** a `t3.micro` (1 GB) is $0.0104 an hour in `us-west-2`, plus $0.005 an hour for its public IPv4 address. See [the AWS tutorial](https://docs.conn3x.org/tutorials/aws).
- **Azure:** the tutorials use `Standard_B2s_v2` at $0.0832 an hour in `westus2`, which is more server than this needs. See [the Azure tutorial](https://docs.conn3x.org/tutorials/azure).
- **Google Cloud:** an `e2-small` (2 GB) is $0.0168 an hour in `us-central1`, plus $0.005 an hour for its address. See [the Google Cloud tutorial](https://docs.conn3x.org/tutorials/google-cloud).
- **DigitalOcean:** an `s-1vcpu-1gb` droplet is $6 a month. See [the DigitalOcean tutorial](https://docs.conn3x.org/tutorials/digitalocean).

Conn3x itself costs nothing. A server you already own costs nothing extra.

## Tear it down

```sh
conn3x destroy
```

Every step in this plan that leaves something on the server has `on_remove = "forget"`, so `destroy` drops them from Conn3x's state and leaves nginx on the server as it is. That's on purpose: destroying state should never take a running site down by surprise.

To remove everything, delete the VM at your cloud provider. On a server you're keeping, remove nginx yourself: `sudo apt remove nginx` on Debian and Ubuntu, or `sudo dnf remove nginx` on the Red Hat family, then delete `/etc/nginx/conf.d/circuit-nginx.conf` and `/var/www/html/index.html`.

## Test it without a server

```sh
conn3x init
conn3x test
```

`tests/setup` starts a throwaway `ghcr.io/conn3xorg/test-debian13` container with `conn3x_test_container`. `tests/converge.tftest.hcl` applies this project to it, plans again with `idempotent = true` to check the second plan is empty, then removes the container. It needs Podman or Docker. It took about 7 seconds on a Mac with Podman, once the image was pulled.
