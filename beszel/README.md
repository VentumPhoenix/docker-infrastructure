# Beszel

Lightweight server monitoring: CPU, memory, disks, network and containers of every host, with history and alerts.

**Upstream:** [henrygd/beszel](https://github.com/henrygd/beszel)

## Variants

| File | Adds |
|---|---|
| `docker-compose.yml` | base (hub only) |
| `docker-compose.agent.yml` | agent that monitors the host the hub runs on |
| `docker-compose.remote-agent.yml` | **for other hosts:** agent only, with its own read-only socket proxy |

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the base via Dockhand and create the admin account at `https://<APP_DOMAIN>`.
3. For the `agent` variant: in the UI, click "Add system", use `/beszel_socket/beszel.sock` as host, copy key and token into `.env`, then deploy `docker-compose.agent.yml`.

## Notes

- **Agent in the host network:** needed for real network statistics of the host. There is no Docker DNS there, so the agent reaches the socket proxy by its fixed IP (`SOCKET_PROXY_NET_PREFIX`.2).
- The `agent` variant is converted from the earlier commented-out setup and hasn't been tested against the socket proxy yet.

## Remote agent (other hosts)

`docker-compose.remote-agent.yml` runs only the agent, on every other host you want to monitor.

| Service | Purpose |
|---|---|
| `agent` | Beszel agent, in the host network |
| `socket-proxy` | read-only Docker API, only the calls the agent needs, reachable via `127.0.0.1` only |

1. In the Beszel UI, click "Add system", enter the host's address and port `45876`. Copy key and token.
2. On that host, copy this folder, copy `.env.example` to `.env` and fill in the agent blocks (`BESZEL_AGENT_KEY`, `BESZEL_AGENT_TOKEN`, `BESZEL_HUB_URL`, `DOCKER_GID`).
3. Allow port `45876/tcp` in the host firewall, ideally only from the hub's IP.
4. Deploy it via Dockhand (through Hawser on that host) or by hand: `docker compose -f docker-compose.remote-agent.yml up -d`.

- **Own socket proxy:** other hosts don't run the `npmplus` stack, so this file brings its own [socket proxy](https://github.com/wollomatic/socket-proxy). It only allows the read calls the agent makes: container list, stats, inspect, logs, `info`, `version`. Its port is bound to `127.0.0.1`.
- **Key and token** are passed as files (`KEY_FILE`, `TOKEN_FILE`).
- **More disks:** mount a folder of each disk to `/extra-filesystems/<device>` (e.g. `/mnt/disk1/.beszel:/extra-filesystems/sdb1:ro`), a display name can be appended with `__`.
- **S.M.A.R.T. and GPU** need extra devices and capabilities (`SYS_RAWIO`, `SYS_ADMIN`, …) and another image tag. Left out on purpose, see the Beszel docs before enabling them.
