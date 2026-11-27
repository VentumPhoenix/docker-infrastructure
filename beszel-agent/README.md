# Beszel agent

Collects CPU, memory, disk, network and container metrics of one host and reports them to a Beszel hub. Deploy this stack on every host you want to monitor. For the host the hub itself runs on, use the `agent` variant of the [beszel](../beszel/) stack instead.

**Upstream:** [henrygd/beszel](https://github.com/henrygd/beszel)

| Service | Purpose |
|---|---|
| `app` | Beszel agent, in the host network |
| `socket-proxy` | read-only Docker API, only the calls the agent needs, reachable via `127.0.0.1` only |

## Setup

1. In the Beszel UI, click "Add system", enter this host's address and port `45876`. Copy key and token.
2. Copy `.env.example` to `.env` and fill in the required block.
3. Allow port `45876/tcp` in the host firewall, ideally only from the hub's IP.
4. Deploy the stack via Dockhand (through Hawser on this host) or by hand.

## Notes

- **Own socket proxy:** remote hosts don't run the `npmplus` stack, so this stack brings its own [socket proxy](https://github.com/wollomatic/socket-proxy). It only allows the read calls the agent makes: container list, stats, inspect, logs, `info`, `version`. Its port is bound to `127.0.0.1`, so only processes on the host itself can reach it.
- **Host network:** needed for the real network statistics of the host. That's also why the agent reaches the proxy via `127.0.0.1`.
- **Key and token** are passed as files (`KEY_FILE`, `TOKEN_FILE`).
- **More disks:** mount a folder of each disk to `/extra-filesystems/<device>` (e.g. `/mnt/disk1/.beszel:/extra-filesystems/sdb1:ro`). A display name can be appended with `__`, e.g. `sdb1__Media`.
- **S.M.A.R.T. and GPU** need extra devices and capabilities (`SYS_RAWIO`, `SYS_ADMIN`, …) and a different image tag. They're left out on purpose, see the Beszel docs before enabling them.
