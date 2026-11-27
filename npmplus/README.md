# NPMplus

The entry point of the whole setup: reverse proxy with automatic certificates, plus everything that keeps the other stacks isolated. It creates the shared networks `npm-proxy` and `socket-proxy`, so it must be deployed first.

**Upstream:** [ZoeyVid/NPMplus](https://github.com/ZoeyVid/NPMplus)

| Service | Purpose |
|---|---|
| `app` | NPMplus: reverse proxy, certificates, admin UI |
| `socket-proxy` | filtered, read-only Docker socket for other stacks |
| `docker-sync` | [npmplus-docker-sync](https://github.com/VentumPhoenix/npmplus-docker-sync): creates proxy hosts from container labels |
| `firewall` | iptables rules: only NPMplus may open connections to apps, `npm-proxy` has neither internet nor access to the host, clients only reach the socket proxy |
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
- **No internet in `npm-proxy`:** the firewall drops all outbound traffic from `npm-proxy`, except from NPMplus (`.2`, certificates) and CrowdSec (`.4`, blocklist). Apps that need the internet join their stack's `egress` network with `gw_priority: 1`. This needs **Docker Engine 28.0** and **Docker Compose v2.33.1** or newer.
- **No access to the host from the shared networks:** containers in `npm-proxy` and `socket-proxy` can't reach the host itself (e.g. SSH or other services on the host's bridge IP). Only NPMplus may, so `host.docker.internal` keeps working. Replies to connections the host opens (e.g. the Beszel agent asking the socket proxy) are allowed. The stack networks `internal` and `egress` are not affected, so Uptime Kuma or Beszel can still check the host via `egress`.
- **Rule order:** the firewall inserts each rule at the top of its chain (`DOCKER-USER` for forwarded traffic, `INPUT` for traffic to the host), so per chain the first line of its rule list ends up last. Each `DROP` must stay above its `ACCEPT`s in the list.
- **When the firewall stops,** it removes its rules. NPMplus then can't reach the apps anymore (Docker's ICC block stays), so the setup doesn't silently run unprotected. The healthcheck of `firewall` and its Uptime Kuma monitor show it.
- **Socket proxy:** only read access. `containers/<name>/json` also returns other containers' environment variables, so only trusted services join `socket-proxy`.
- **Updates:** manual. Switch off auto-update for this stack in Dockhand.

### Remote hosts

Other Docker hosts join through the [remote-host](../remote-host/) stack. Their syncs talk to the NPMplus admin API via NetBird: enable the commented port `"${NETBIRD_IP}:81:81"` in the compose file and set `NETBIRD_IP` to this host's NetBird IP. The port is then only reachable inside NetBird, restrict it further with a NetBird policy.

### Migrating from nginx-proxy-manager

[`migrate-from-npm.sh`](migrate-from-npm.sh) switches a running [nginx-proxy-manager](https://github.com/NginxProxyManager/nginx-proxy-manager) (jc21) over to this stack. It follows the [upstream migration steps](https://github.com/ZoeyVid/NPMplus#migration-from-upstreamvanilla-nginx-proxy-manager) and solves the part that makes it tricky: the apps still sit in the old NPM's network, which can't simply be removed while they're attached.

```sh
cd npmplus
cp .env.example .env                            # fill in, as for a fresh install
./migrate-from-npm.sh check -f <variant file>   # changes nothing, lists what needs attention
./migrate-from-npm.sh migrate -f <variant file> # websites are offline for 1–3 minutes
```

`migrate` does:

1. **Checks** Docker/Compose versions, the CPU (NPMplus needs x86-64-v2 or arm64), the database (only SQLite can be migrated), subnet collisions, and reads the old proxy hosts and certificates.
2. **Backs up** `/data` and `/etc/letsencrypt` to `.migration/backup/` (git-ignored, contains private keys).
3. **Stops** the old NPM. It is only stopped, its data stays untouched, so `rollback` always works.
4. **Copies** the data into new volumes and starts NPMplus once with the old certificates mounted (NPMplus moves them into `/data`), then again normally.
5. **Joins NPMplus to the old networks**, so every existing proxy host keeps working, even ones that forward to IPs.

Then move one app after another into `npm-proxy` (the stacks of this repo already do that). When none is left in the old network:

```sh
./migrate-from-npm.sh finish     # removes the old container, its networks and leftovers
```

Something wrong? `./migrate-from-npm.sh rollback` stops NPMplus and starts the old NPM with its unchanged data.

Things to know:

- **If the old network is already called `npm-proxy`**, the script rebuilds it with the settings of this stack and reconnects every container with its aliases. In the rebuilt network containers can't reach each other, have no internet and get new IPs. `check` lists the affected containers. An app that talks to its database through that network breaks until it has its own `internal` network.
- **The service user:** `INITIAL_ADMIN_*` only applies to a fresh install. If `NPM_SERVICE_USER` doesn't exist in the old database, create it in the UI afterwards with `NPM_SERVICE_PASSWORD`. `docker-sync` stays unhealthy until then. `check` tells you.
- **Collisions with labels:** a manual proxy host for `APP_DOMAIN` (or for an app that now gets its host from labels) must be deleted, otherwise the sync can't create its own.
- **Certificates** with the DNS providers NPMplus replaced or dropped (he, dnspod, online, powerdns, digitalocean, beget, route53) don't renew and must be created again. `check` lists them.
- **The old networks are joined at runtime.** That survives restarts, but not a recreate of the container (e.g. an update). For longer transitions add them to the compose file as described below.
- Going back from NPMplus to nginx-proxy-manager **after** `finish` is not possible (upstream), only through the backup.

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
