# Hawser

Agent for Dockhand: it runs on another Docker host and lets Dockhand manage that host's containers and stacks. In edge mode, Hawser connects out to Dockhand, so the host needs no open port.

**Upstream:** [Finsys/hawser](https://github.com/Finsys/hawser)

## Setup

1. In Dockhand, add a new environment of type Hawser (edge). Dockhand shows the server URL and a token.
2. On the remote host, copy `.env.example` to `.env` and fill in both values.
3. Put the stack folders for this host below `HAWSER_STACKS_DIR` (default `/opt/stacks`).
4. Deploy the stack **by hand** (`docker compose up -d`). Dockhand can only reach the host once Hawser runs.

## Notes

- **Runs on remote hosts:** this stack doesn't need the `npmplus` stack and joins no shared network. It only has `egress` for the outbound WebSocket.
- **Docker socket (exception):** Hawser needs full write access to the Docker API, like Dockhand itself. Whoever controls Dockhand controls this host too.
- **No inbound port:** the health endpoint listens on `127.0.0.1` inside the container only.
- **Token** is passed as a file (`TOKEN_FILE`), not as an environment variable.
- **Updates:** by hand, like Dockhand. Dockhand deploys through Hawser, so it can't reliably update Hawser itself.
