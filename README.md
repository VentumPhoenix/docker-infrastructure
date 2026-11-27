# 🐳 docker-infrastructure

Docker Compose stacks for a self-hosted homelab, built around one idea: **zero trust that stays readable.** Nothing talks to anything unless the compose file explicitly allows it, and every stack is built the same way.

The repository is public to back up and version the configuration, and as inspiration for others in the self-hosting community.

## Stacks

| Stack | Group | What it does | Variants |
|---|---|---|---|
| [npmplus](npmplus/) | Infrastructure | Reverse proxy, certificates, Docker label sync, socket proxy, firewall. **Deploy first.** | `authentik`, `crowdsec`, `authentik-crowdsec` |
| [dockhand](dockhand/) | Infrastructure | Deploys and updates all other stacks. Hawser agent for other hosts included | `hawser` (other hosts) |
| [netbird](netbird/) | Infrastructure | Self-hosted WireGuard mesh VPN | – |
| [rdpgw](rdpgw/) | Infrastructure | Remote desktop gateway (RDP over HTTPS), login via Authentik | – |
| [semaphore](semaphore/) | Infrastructure | Web UI for Ansible, Terraform/OpenTofu and scripts | – |
| [authentik](authentik/) | Security | Single sign-on (OIDC) and forward auth | – |
| [vaultwarden](vaultwarden/) | Security | Bitwarden-compatible password manager | – |
| [wazuh](wazuh/) | Security | Security monitoring (SIEM/XDR) with agents | – |
| [uptime-kuma](uptime-kuma/) | Monitoring | Uptime monitoring, monitors created from labels (AutoKuma) | – |
| [beszel](beszel/) | Monitoring | Server and container monitoring | `agent`, `remote-agent` (other hosts) |
| [homepage](homepage/) | Monitoring | Dashboard, filled from labels | – |
| [influxdb](influxdb/) | Monitoring | Time series database for metrics | – |
| [telegraf](telegraf/) | Monitoring | Collects host and container metrics into InfluxDB | – |
| [grafana](grafana/) | Monitoring | Dashboards for metrics (InfluxDB) | – |
| [heimdall](heimdall/) | Monitoring | Start page with tiles for all web apps | – |
| [nextcloud](nextcloud/) | Apps | Files, office (Collabora), whiteboard, virus scan, SFTP | – |
| [paperless](paperless/) | Apps | Document management with OCR and full-text search | `tika` |
| [sillytavern](sillytavern/) | Apps | LLM chat frontend, API requests through a VPN | – |
| [hastebin](hastebin/) | Apps | Pastebin for code snippets | – |
| [mealie](mealie/) | Apps | Recipe manager with meal planner and shopping lists | – |
| [tandoor](tandoor/) | Apps | Recipe manager with meal planning and nutrition data | – |
| [code-server](code-server/) | Apps | VS Code in the browser, behind Authentik | – |
| [gitlab](gitlab/) | Apps | Git hosting with merge requests, issues and CI/CD | – |

Every stack folder contains a `docker-compose.yml`, a `.env.example` and a `README.md`.

## How it fits together

```
Internet ──80/443──▶ NPMplus ──npm-proxy──▶ app of each stack ──internal──▶ its database
                        ▲                         │
                        │ labels                  └──egress──▶ internet (only if needed)
               npmplus-docker-sync
                        │
              socket-proxy (read-only Docker API) ◀── AutoKuma, Homepage
```

- **Only NPMplus publishes ports.** Apps join the shared network `npm-proxy`, where only NPMplus may open connections to them. Apps can't reach each other.
- **Labels instead of clicking.** Each app carries labels for three tools:
  - `npm.proxy.*`: [npmplus-docker-sync](https://github.com/VentumPhoenix/npmplus-docker-sync) creates the proxy host and certificate.
  - `kuma.*`: AutoKuma creates the uptime monitor.
  - `homepage.*`: Homepage adds the dashboard tile.
- **Login everywhere.** Apps without a login of their own get Authentik in front of them with a single label: `npm.proxy.auth_request: "authentik"`.
- **No direct Docker socket.** Everything that needs the Docker API goes through a read-only socket proxy.
- **Secrets as files.** Passwords reach the containers via `/run/secrets/…`, not as environment variables.

The full rule set is in **[CONVENTIONS.md](CONVENTIONS.md)**. Every variable is listed in **[VARIABLES.md](VARIABLES.md)**.

## Requirements

| Component | Minimum | Why |
|---|---|---|
| Docker Engine | **28.0** | `gw_priority` on the `egress` network (default route for apps, because `npm-proxy` has no internet) |
| Docker Compose | **v2.33.1** (`docker compose`, not the old `docker-compose`) | `gw_priority` in compose files |
| Host | Linux with iptables (nft or legacy) | the `firewall` of the `npmplus` stack manages `DOCKER-USER` and `INPUT` |

Check with `docker version` and `docker compose version`. Dockhand runs Compose itself, so its bundled Compose must meet the same minimum.

## Tools this setup relies on

- **[Dockhand](https://github.com/Finsys/dockhand):** deploys and updates the stacks. Every stack is a single compose file, so it can be deployed through Dockhand as is.
- **[NPMplus](https://github.com/ZoeyVid/NPMplus):** reverse proxy with automatic certificates, HTTP/3 and a built-in CrowdSec bouncer.
- **[npmplus-docker-sync](https://github.com/VentumPhoenix/npmplus-docker-sync):** creates NPMplus proxy hosts from container labels.

## Getting started

1. Deploy [npmplus](npmplus/) **by hand**. It creates the shared networks that every other stack joins.
2. Deploy [dockhand](dockhand/) **by hand**:
   ```bash
   cp .env.example .env   # fill in the REQUIRED block
   docker compose up -d
   ```
3. Deploy every other stack **through Dockhand**, with its variables from `.env.example`.
4. The stack's `README.md` lists any first-time steps.

Each `docker-compose.yml` lists its required variables at the top (`x-required`). Compose refuses to start and names the missing variable if one isn't set.

## License

[MIT](LICENSE)

---
*Happy self-hosting!* 🚀
