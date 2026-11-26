# NetBird

Self-hosted WireGuard mesh VPN. Peers connect directly to each other, the server only coordinates. Uses the combined server image (management, signal, relay and STUN in one container) plus the dashboard.

**Upstream:** [netbirdio/netbird](https://github.com/netbirdio/netbird) · [netbirdio/dashboard](https://github.com/netbirdio/dashboard)

| Service | Purpose |
|---|---|
| `app` | dashboard (web UI) |
| `server` | combined server: management API, signal, relay, STUN, embedded IdP |

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Open UDP port 3478 in the host firewall.
3. Deploy the stack via Dockhand.
4. Open `https://<APP_DOMAIN>` and create the first user.
5. Optional: add Authentik as an identity provider in the dashboard (Settings → Identity Providers). This needs no change to the compose file.

## Notes

- **Everything in one file:** `config.yaml` is defined inline (`configs:`), and the dashboard settings that used to be in `dashboard.env` are plain environment variables. The stack needs no files on the host, so Dockhand can deploy it as is.
- **Routing:** one domain for everything. NPMplus sends `/` to the dashboard and the API, gRPC and websocket paths to the server (`npm.proxy.advanced.config` on `app`). The server has the unique network alias `netbird-server`, which NPMplus resolves at request time. This way NPMplus also starts while NetBird is down.
- **HTTP/2** must be active on the proxy host, because gRPC needs it.
- **STUN (exception):** UDP 3478 is published directly, because UDP can't go through the reverse proxy.
- **Secrets:** `NETBIRD_AUTH_SECRET` and `NETBIRD_STORE_ENCRYPTION_KEY` end up in the inline `config.yaml` (a file in the container), not in environment variables.

### Migrating from an existing setup

- Copy `server.authSecret` and `server.store.encryptionKey` from your old `config.yaml` into `.env` **unchanged**. A new encryption key can't read the existing database.
- Compare the rest of your old `config.yaml` with the inline one. Add any settings you changed yourself (e.g. a Postgres store or `owner`) to `configs.server-config`.
- Delete the manually created proxy host in NPMplus before the first deploy, otherwise the domain collides.
