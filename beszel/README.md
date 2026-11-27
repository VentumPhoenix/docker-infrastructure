# Beszel

Lightweight server monitoring: CPU, memory, disks, network and containers of every host, with history and alerts.

**Upstream:** [henrygd/beszel](https://github.com/henrygd/beszel)

## Variants

| File | Adds |
|---|---|
| `docker-compose.yml` | base (hub only) |
| `docker-compose.agent.yml` | agent that monitors the host the hub runs on |

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the base via Dockhand and create the admin account at `https://<APP_DOMAIN>`.
3. For the `agent` variant: in the UI, click "Add system", use `/beszel_socket/beszel.sock` as host, copy key and token into `.env`, then deploy `docker-compose.agent.yml`.

## Notes

- **Agent in the host network:** needed for real network statistics of the host. There is no Docker DNS there, so the agent reaches the socket proxy by its fixed IP (`SOCKET_PROXY_NET_PREFIX`.2).
- The `agent` variant is converted from the earlier commented-out setup and hasn't been tested against the socket proxy yet.
- **Other hosts:** the agent for other hosts is part of the [remote-host](../remote-host/) stack (profile `beszel`).
