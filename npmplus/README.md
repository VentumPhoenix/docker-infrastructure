# NPMplus

The entry point of the whole setup: reverse proxy with automatic certificates, plus everything that keeps the other stacks isolated. It creates the shared networks `npm-proxy` and `socket-proxy`, so it must be deployed first.

**Upstream:** [ZoeyVid/NPMplus](https://github.com/ZoeyVid/NPMplus)

| Service | Purpose |
|---|---|
| `app` | NPMplus: reverse proxy, certificates, admin UI |
| `socket-proxy` | filtered, read-only Docker socket for other stacks |
| `docker-sync` | [npmplus-docker-sync](https://github.com/VentumPhoenix/npmplus-docker-sync): creates proxy hosts from container labels |
| `firewall` | iptables rules: only NPMplus may open connections to apps, clients only reach the socket proxy |
| `crowdsec-init` | *(variant crowdsec)* one-shot job that writes the bouncer config |
| `crowdsec` | *(variant crowdsec)* log analysis, WAF (AppSec), community blocklist |

## Variants

| File | Adds |
|---|---|
| `docker-compose.yml` | base |
| `docker-compose.authentik.yml` | forward auth via Authentik (`npm.proxy.auth_request` label on apps) |
| `docker-compose.crowdsec.yml` | CrowdSec with the bouncer built into NPMplus |
| `docker-compose.authentik-crowdsec.yml` | both |

## Setup

1. Copy `.env.example` to `.env` and fill in the required block, plus the block of your variant.
2. Deploy the stack **by hand** (`docker compose -f <file> up -d`). It has to exist before Dockhand, because it creates the networks Dockhand joins. Later updates can go through Dockhand.
3. Log into the admin UI at `https://<APP_DOMAIN>` with `NPM_SERVICE_USER` / `NPM_SERVICE_PASSWORD`.
4. Check the firewall: the healthcheck of `firewall` must be healthy (`docker inspect --format '{{.State.Health.Status}}' <container>`).

## Notes

- **Fixed IPs:** NPMplus (`.2`), docker-sync (`.3`) and CrowdSec (`.4`) have fixed addresses in `npm-proxy`, because the firewall rules rely on them. Dynamic addresses come from the upper half of the subnet (`.128/25`).
- **Socket proxy:** only read access. `containers/<name>/json` also returns other containers' environment variables, so only trusted services join `socket-proxy`.
- **Updates:** manual. Switch off auto-update for this stack in Dockhand.

### Migrating from an existing network

If your apps still sit in an older proxy network (e.g. `npm-frontend`), NPMplus can temporarily join both. Add this to the `app` service and the `networks` block, and remove it again once every app has moved to `npm-proxy`:

```yaml
services:
  app:
    networks:
      npm-proxy:
        ipv4_address: ${NPM_PROXY_NET_PREFIX:-172.30.0}.2
      npm-legacy: {}   # temporary, remove after the migration

networks:
  npm-legacy:          # temporary, remove after the migration
    name: npm-frontend
    external: true
```
