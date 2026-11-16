# Private AI box

Your own language models on a Linux server, where nobody else sees the prompts. Ollama serves a small chat model and an embedding model, and Qdrant stores vectors for search. Both listen on `127.0.0.1` only, so you reach them through an SSH tunnel and the internet doesn't reach them at all.

Why so careful? Ollama's API has no login. Anyone who can reach port 11434 can run your models, pull new ones onto your disk and delete the ones you have.

It uses two circuits:

| Circuit | What it does here |
| --- | --- |
| [circuit-ollama](https://github.com/conn3xorg/circuit-ollama) v0.1.4 | Installs Ollama 0.40.13 from the official release, checked against its SHA-256, and pulls `qwen2.5:0.5b` and `nomic-embed-text`. |
| [circuit-qdrant](https://github.com/conn3xorg/circuit-qdrant) v0.1.2 | Installs Qdrant 1.20.0 from the official release, with an API key every request must send and telemetry off. |

For a full walk-through that also creates the server on AWS, hardens it and asks the models questions about your own notes, see the [Private AI box tutorial](https://docs.conn3x.org/tutorials/private-ai-box).

## Before you start

- Conn3x v0.20.0 or later, [installed](https://docs.conn3x.org/install).
- A Linux server running Rocky Linux, RHEL, AlmaLinux, Fedora, Debian or Ubuntu, with systemd, on x86_64 or aarch64. Give it 4 GB of memory and at least 6 GB of free disk. Ollama's release is 1.5 GB to download and 3.7 GB unpacked, and the two models take about 650 MB. This README uses `203.0.113.20`.
- SSH access with a key, as `root` or as a user with passwordless sudo.
- Outbound HTTPS from the server to `github.com` and `ollama.com`.

No GPU needed. These two models run on the CPU.

If you've never logged in to the server, do it once so its host key lands in `~/.ssh/known_hosts`:

```sh
ssh root@203.0.113.20 true
```

## Run it

```sh
git clone https://github.com/conn3xorg/examples
cd examples/private-ai-box
```

Write `terraform.tfvars`:

```hcl
# terraform.tfvars
hosts                = { ai1 = "203.0.113.20" }
ssh_private_key_file = "~/.ssh/id_ed25519"
```

If you log in as a regular user with sudo, add `ssh_user = "admin"` and `ssh_become = true`. To pull other models, set `models`, such as `models = ["llama3.2:3b"]`, and give the server the memory they need: an 8B model wants about 8 GB.

Qdrant's key goes in the environment, not the file. It needs at least 16 characters:

```sh
export TF_VAR_qdrant_api_key="$(openssl rand -hex 24)"
```

Keep that value: every later plan needs the same one, and so does every request you send Qdrant. Then:

```sh
conn3x init
conn3x plan
conn3x apply
```

Plan once more and it's clean:

```sh
conn3x plan
```

```text
No changes. Your infrastructure matches the configuration.
```

## Talk to it

Open a tunnel in one terminal. It forwards both ports from your machine to the server's loopback:

```sh
ssh -N -L 11434:127.0.0.1:11434 -L 6333:127.0.0.1:6333 root@203.0.113.20
```

In another, ask the chat model something:

```sh
curl -s localhost:11434/api/generate \
  -d '{"model": "qwen2.5:0.5b", "prompt": "Name three uses for a homelab.", "stream": false}'
```

And check Qdrant answers with your key. Without the `api-key` header it answers `401`:

```sh
curl -s -H "api-key: $TF_VAR_qdrant_api_key" localhost:6333/collections
```

## What the plan looks like

This is from a real run, against a Debian 13 test container on `127.0.0.1:2304`. On your server you'll see your own address in the IDs.

```text
  # module.ollama.conn3x_archive.ollama__unpack["ai1"] will be created
  # module.ollama.conn3x_command.models__pull["ai1/nomic-embed-text"] will be created
  # module.ollama.conn3x_command.models__pull["ai1/qwen2.5:0.5b"] will be created
  # module.ollama.conn3x_directory.ollama__directories["ai1//opt/ollama"] will be created
  ...
  # module.ollama.conn3x_download.ollama__download["ai1"] will be created
  # module.ollama.conn3x_file.ollama__environment["ai1"] will be created
  # module.ollama.conn3x_file.ollama__unit["ai1"] will be created
  # module.ollama.conn3x_group.ollama__group["ai1"] will be created
  # module.ollama.conn3x_link.ollama__link["ai1"] will be created
  # module.ollama.conn3x_package.ollama__tools["ai1/curl"] will be created
  # module.ollama.conn3x_package.ollama__tools["ai1/tar"] will be created
  # module.ollama.conn3x_package.ollama__tools["ai1/zstd"] will be created
  # module.ollama.conn3x_service.ollama__running["ai1"] will be created
  # module.ollama.conn3x_service_action.ollama__restart["ai1"] will be created
  # module.ollama.conn3x_user.ollama__user["ai1"] will be created
  # module.ollama.conn3x_wait_for.models__api["ai1"] will be created
  # module.qdrant.conn3x_archive.qdrant__unpack["ai1"] will be created
  # module.qdrant.conn3x_command.qdrant__ready["ai1"] will be created
  ...
  # module.qdrant.conn3x_service.qdrant__running["ai1"] will be created
  # module.qdrant.conn3x_service_action.qdrant__restart["ai1"] will be created
  # module.qdrant.conn3x_user.qdrant__user["ai1"] will be created
```

Each model is a command that only runs when `ollama list` doesn't have it yet. That's why the second plan is empty:

```text
  # module.ollama.conn3x_command.models__pull["ai1/qwen2.5:0.5b"] will be created
  + resource "conn3x_command" "models__pull" {
      + command   = "OLLAMA_HOST='127.0.0.1:11434' ollama pull 'qwen2.5:0.5b'"
      + unless    = "OLLAMA_HOST='127.0.0.1:11434' ollama list | awk 'NR > 1 { print $1 }' | grep -qxF 'qwen2.5:0.5b'"
```

```text
Plan: 37 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + ollama_api_urls = {
      + ai1 = "http://127.0.0.1:11434"
    }
```

The Qdrant key isn't anywhere in the plan. The apply took just over two minutes. Unpacking Ollama took 21 seconds, and the two models 13 and 14.

## What it costs

Both models run on the CPU in 4 GB of memory. At the prices in the Conn3x tutorials:

- **AWS:** a `t3.medium` (4 GB) is $0.0416 an hour in `us-west-2`, plus $0.005 an hour for its public IPv4 address and about $1.60 a month for a 20 GB gp3 disk. Left running for a month, that's about $36. See [the Private AI box tutorial](https://docs.conn3x.org/tutorials/private-ai-box).
- **Azure:** a `Standard_B2s_v2` is $0.0832 an hour in `westus2`. See [the Azure tutorial](https://docs.conn3x.org/tutorials/azure).
- **Google Cloud:** use a VM with 4 GB of memory. The Conn3x docs don't quote a price for one.
- **DigitalOcean:** an `s-2vcpu-4gb` droplet is $0.0357 an hour. See [the Private AI box tutorial](https://docs.conn3x.org/tutorials/private-ai-box).

A spare machine at home with 4 GB of memory costs only its power.

## Tear it down

```sh
conn3x destroy
```

Every step in this plan that leaves something on the server has `on_remove = "forget"`, so `destroy` drops them from state and leaves Ollama, its models and Qdrant's data on the server.

To remove everything, delete the VM at your cloud provider. On a server you're keeping, stop and disable `ollama` and `qdrant` with `systemctl`, then delete `/opt/ollama`, `/opt/qdrant`, `/var/lib/qdrant` and the models in `/usr/share/ollama`, the `ollama` user's home directory.

## Test it without a server

```sh
conn3x init
conn3x test
```

`tests/setup` starts a throwaway `ghcr.io/conn3xorg/test-debian13` container. `tests/converge.tftest.hcl` applies this project to it with a test-only Qdrant key, pulls the same two models a real run does, checks the second plan is empty with `idempotent = true` and that Ollama listens on loopback, then removes the container. It needs Podman or Docker and downloads a little over 2 GB. It took about 2 minutes on a Mac with Podman.
