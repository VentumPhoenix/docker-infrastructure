# Dockhand

Web UI that deploys and updates all other stacks of this setup.

**Upstream:** [Finsys/dockhand](https://github.com/Finsys/dockhand)

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
- **Other hosts:** to manage another Docker host with Dockhand, deploy the [remote-host](../remote-host/) stack there. It brings the Hawser agent.
