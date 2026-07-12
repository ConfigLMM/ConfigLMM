# ConfigLMM — Large Configuration Management Manager

![Yo Dawg I Heard you like config so I put a config in your Config](/Images/configINconfig.png)

Describe **what you want** your systems to look like. *ConfigLMM* makes it happen.

No vendor lock-in. No writing hundreds of lines of Puppet/Kubernetes/Terraform for every little thing.
Just intention-based configuration — you say *what*, ConfigLMM figures out *how*.

> This project is in active development. See [Vision](docs/VISION.md) for the full picture of where it's heading.

## Currently Implemented

Run `configlmm types` to see everything available. The main supported categories:

**Linux** — openSUSE, Debian, Proxmox VE; users, SSH, networking, sysctl, systemd, WireGuard, fstab

**DNS** — PowerDNS, PorkbunDNS, TonicDNS, GoDaddy

**Web / Proxy** — Nginx, NginxProxy, PHP-FPM, Let's Encrypt

**Databases** — PostgreSQL (with replication), MariaDB, Cassandra, ClickHouse, InfluxDB, Valkey

**Auth / Identity** — Authentik (with Outpost), SSH config

**Mail** — Postfix, Dovecot, Rspamd, Roundcube

**Self-hosted Apps** — Nextcloud, GitLab, Gollum, Vaultwarden, Discourse, Matrix, Mastodon, Jellyfin,
Grafana, Netdata, Odoo, ERPNext, BookStack, Wiki.js, Authentik, Peppermint, Jackett, qBittorrent,
Sunshine, IPFS, InfluxDB, Umami, SearXNG, Homepage, Lobsters, Answer, OpenVidu, and more

**AI / LLM** — Ollama, llama.cpp, vLLM, Perplexica, LibreTranslate

**Observability** — SigNoz, OpenTelemetry Collector, Netdata, Grafana

**Platforms** — libvirt (KVM/QEMU), Proxmox (VM & LXC), GitHub, PXE boot (BIOS & UEFI)

**Other** — Podman, RVM, ZooKeeper, Solr, ClickHouse, YaCy

See [`Examples/Implemented.mm.yaml`](/Examples/Implemented.mm.yaml) for full working examples of each.

## Installation

You need Ruby and RubyGems. Then:

```
$ gem install ConfigLMM
```

If that doesn't work (e.g. Ruby is too old), use the bootstrap script — it will install [RVM](https://rvm.io/) automatically.
You can [review the script](https://raw.githubusercontent.com/ConfigLMM/ConfigLMM/master/bootstrap.sh) before running it:

```
$ curl -sS https://raw.githubusercontent.com/ConfigLMM/ConfigLMM/master/bootstrap.sh | sh
```

## Usage

Create a YAML config file describing what you want, e.g.:

```yaml
Wiki:
    Type: Gollum
    Domain: wiki.example.to
    CertName: Gollum
    Resources:
        NS:
            Type: TonicDNS
            Domain: example.to
            Nameservers:
                ns.example.to: 192.168.5.5
        DNS:
            Type: PowerDNS
            DNS:
                example.to:
                    wiki: CNAME=@ # `@` means point it to the domain root
                    '@': A=@me   # `@me` means use current external IP
```

Then deploy it:

```
$ configlmm deploy config.mm.yaml
Deploying...
Deploying NS: TonicDNS
Tonic - Successful DNS Change
Deploying DNS: PowerDNS
Deploying Wiki: Gollum
Deploy successful!
```

### Available Commands

```
$ configlmm help
Commands:
  configlmm backup [CONFIGS_LIMIT...]  # Backup deployed things
  configlmm build [CONFIGS...]         # Build configuration in deployable form
  configlmm cleanup [CONFIGS...]       # Cleanup/delete unused things in deployed infrastructure
  configlmm deploy [CONFIGS...]        # Deploy configuration
  configlmm diff [CONFIGS...]          # Show changes that will be applied with next deploy
  configlmm help [COMMAND]             # Describe available commands or one specific command
  configlmm list [CONFIGS...]          # List things
  configlmm refresh [CONFIGS...]       # Update local state to match deployed things
  configlmm test [CONFIGS...]          # Test whether deployed things work as expected
  configlmm types                      # List available types/plugins
  configlmm update [CONFIGS_LIMIT...]  # Update deployed things
  configlmm validate [CONFIGS...]      # Check whether the configuration is valid
  configlmm version                    # Show program's version

Options:
      [--level=LEVEL]                    # Logging level (debug, info, warn, error) — default: info
  -n, [--dry], [--no-dry], [--skip-dry]  # Only show actions without performing them

Configs options:
  [--locations=LOCATIONS]  # Filter by config file locations
  [--things=THINGS]        # Filter on which things to work on
```

## Learn More

| Document | Description |
|---|---|
| [Vision](docs/VISION.md) | The full project vision, long-term goals, and philosophy |
| [FAQ](docs/FAQ.md) | Frequently asked questions |
| [Contributing](CONTRIBUTING.md) | How to contribute, implement plugins, and set up for development |
| [Changelog](CHANGELOG.md) | What has been implemented in each release |

