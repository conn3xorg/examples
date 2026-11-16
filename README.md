# Conn3x examples

Five complete [Conn3x](https://conn3x.org) projects you can point at a server of your own and apply in about ten minutes. Each one uses published circuits pinned to a release, takes its servers as a variable, and comes with the plan it printed on a real run, what it costs on a small cloud VM, and how to tear it down.

| Project | What you get |
| --- | --- |
| [web-server](web-server) | nginx serving your page on port 80. The smallest complete project: one circuit, one server. |
| [web-and-postgres](web-and-postgres) | nginx and PostgreSQL 18 on one server, with a database and a login role for your app. |
| [monitoring](monitoring) | Prometheus, Grafana and node_exporter from their official releases, without Docker. |
| [private-ai-box](private-ai-box) | Ollama with a small chat model and an embedding model, and Qdrant, reachable only through SSH. |
| [secure-homelab](secure-homelab) | SSH with keys only, kernel hardening, a firewall, fail2ban and daily security updates. |

New to Conn3x? Start with web-server. When its second `conn3x plan` says `No changes.`, you've done the loop every other project uses.

## What you need

- Conn3x v0.20.0 or later. See [Install Conn3x](https://docs.conn3x.org/install).
- A Linux server you can log in to over SSH with a key: Rocky Linux, RHEL, AlmaLinux, Fedora, Debian or Ubuntu, with systemd. A fresh cloud VM or a spare box at home both work.

Each project's README walks you through the run.

## Run the tests

Every project has a test that needs no server at all. It starts a throwaway systemd container with Podman or Docker, applies the project to it, checks that a second plan is empty, and removes the container:

```sh
cd web-server
conn3x init
conn3x test
```

```text
tests/converge.tftest.hcl... pass
  run "host"... pass
  run "converge"... pass

Success! 2 passed, 0 failed.
```

CI runs the same `conn3x init` and `conn3x test` for all five, on every pull request and once a week. A container can't do everything a server can, so two tests leave a part out with `in_container = true`: monitoring skips Grafana, and secure-homelab skips the kernel parameters and the firewall. Their READMEs say what was run by hand instead. See [Test a circuit](https://docs.conn3x.org/guides/test-a-circuit) for how the tests work.

If a test is killed halfway, `podman ps --filter label=io.conn3x.test-container=true` finds the container it left.

## Contributing

Pull requests are welcome. Sign off each commit with `git commit -s`. See [CONTRIBUTING.md](https://github.com/conn3xorg/.github/blob/main/CONTRIBUTING.md).

## License

[MPL-2.0](LICENSE)
