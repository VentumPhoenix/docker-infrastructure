# Dockhand

Web UI that deploys and updates all other stacks of this setup.

**Upstream:** [Finsys/dockhand](https://github.com/Finsys/dockhand) · [Finsys/hawser](https://github.com/Finsys/hawser)

## Files

| File | Runs on | Purpose |
|---|---|---|
| `docker-compose.yml` | this host | Dockhand + Postgres |
| `docker-compose.hawser.yml` | **other hosts** | Hawser agent, so Dockhand can manage that host |

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Put your stack folders below `DOCKHAND_STACKS_DIR` (default `/opt/stacks`).
3. Deploy the stack **by hand** (`docker compose up -d`). Dockhand can't deploy or update itself reliably, so updates are done by hand as well.
4. Open `https://<APP_DOMAIN>` and make sure authentication is enabled.

## Notes

- **Docker socket (exception):** Dockhand is the only service besides `socket-proxy` that mounts `/var/run/docker.sock`, and with write access. It needs that to deploy stacks. Whoever controls Dockhand controls the host, so keep its login strong.
- **No Authentik in front on purpose:** if Authentik breaks, you need Dockhand to fix it. Rely on Dockhand's own login, later additionally restricted to NetBird.
- **Stack folders:** mounted at the same path inside and outside the container. This makes relative bind mounts in deployed stacks (e.g. `./config.yaml`) resolve on the host. If your stacks live in several folders, add one such mount per folder.
- **No healthcheck yet:** Dockhand has no documented health endpoint.

## Hawser (other hosts)

Hawser lets Dockhand manage another Docker host. In edge mode it connects out to Dockhand, so that host needs no open port.

1. In Dockhand, add a new environment of type Hawser (edge). Dockhand shows the server URL and a token.
2. On the other host, copy this folder, copy `.env.example` to `.env` and fill in the block for `docker-compose.hawser.yml`.
3. Put the stack folders for that host below `HAWSER_STACKS_DIR` (default `/opt/stacks`).
4. Deploy it **by hand** there: `docker compose -f docker-compose.hawser.yml up -d`. Dockhand can only reach the host once Hawser runs.

- **Docker socket (exception):** Hawser needs full write access to the Docker API, like Dockhand. Whoever controls Dockhand controls that host too.
- **Only `egress`:** the other host doesn't run the `npmplus` stack. Hawser joins no shared network and opens no port; its health endpoint listens on `127.0.0.1` inside the container.
- **Token** is passed as a file (`TOKEN_FILE`), not as an environment variable.
- **Updates:** by hand, like Dockhand itself.

