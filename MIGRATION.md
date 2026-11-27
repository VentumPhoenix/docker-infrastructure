# 🔁 Migration to the conventions

What changes when switching an existing deployment to the stacks as they are described in [CONVENTIONS.md](CONVENTIONS.md). This file is removed once the migration is complete.

> ⚠️ **Volume names changed.** Deploying a converted stack creates **new, empty volumes**. The old volumes stay untouched, but the app starts without its data. Copy the data first (see [Volumes](#volumes)).

---

## Requirements

- **Docker Engine 28.0** and **Docker Compose v2.33.1** or newer on the host (and in Dockhand), because of `gw_priority` on the `egress` network. Check with `docker version` and `docker compose version`. See [README](README.md#requirements).

## Order

The new firewall of `npmplus` blocks the internet in `npm-proxy`. Only the new stack files route outbound traffic through `egress`, so **the app stacks go first and `npmplus` goes last**. Your current `npmplus` already creates the network `npm-proxy`, so the new app stacks can join it right away.

1. **Every app stack, one at a time:** update `.env` → copy volumes → deploy the new file → check. Apps in the old network `npm-frontend` stay reachable, because your current `npmplus` is still attached to it (`npm-legacy`).
2. **`npmplus` last:** update `.env` → copy the volume `npm-data` → deploy the new file. As long as any app still runs with its old file, add the temporary `npm-legacy` network (see [npmplus/README.md](npmplus/README.md#migrating-from-an-existing-network)).
3. **Check the blocks:** the healthcheck of `firewall` must be healthy. Apps with `egress` (e.g. Paperless mail fetching, Uptime Kuma) must still reach the internet, apps without it (e.g. Hastebin) must not. Services that NPMplus proxies to on the host via `host.docker.internal` must still work.
4. **Finally** remove `npm-legacy` from `npmplus` and delete the old network `npm-frontend`.

## Variables

Update the names in your `.env` files. Values stay the same.

| Old | New | Stack |
|---|---|---|
| `AUTHENTIK_VERSION` | `APP_VERSION` | authentik |
| `POSTGES_PASSWORD` | `DB_PASSWORD` | authentik |
| `NPM_NETWORK` | `NPM_PROXY_NETWORK` | homepage |
| `KUMA_USERNAME` | `KUMA_SERVICE_USER` | uptime-kuma |
| `KUMA_PASSWORD` | `KUMA_SERVICE_PASSWORD` | uptime-kuma |
| `NPM_SERVICE_USER_EMAIL` | `NPM_SERVICE_USER` | npmplus |
| `NPM_SERVICE_USER_PASSWORD` | `NPM_SERVICE_PASSWORD` | npmplus |
| `NPM_NET_PREFIX` | `NPM_PROXY_NET_PREFIX` | npmplus |
| `NPM_BRIDGE` | `NPM_PROXY_BRIDGE` | npmplus |
| `SOCKPRX_NET_PREFIX` | `SOCKET_PROXY_NET_PREFIX` | npmplus |
| `SOCKPRX_BRIDGE` | `SOCKET_PROXY_BRIDGE` | npmplus |
| `MYSQL_PASSWORD` | `DB_PASSWORD` | nextcloud |
| `MYSQL_ROOT_PASSWORD` | `DB_ROOT_PASSWORD` | nextcloud |
| `APP_URL` | `APP_DOMAIN` | nextcloud |
| `JWT_SECRET_KEY` | `WHITEBOARD_JWT_SECRET` | nextcloud |
| `PROTON_WG_KEY` | `VPN_WIREGUARD_PRIVATE_KEY` | sillytavern |
| `NPM_PROXY_DOMAIN` | `APP_DOMAIN` | rdpgw |
| `RDPGW_OPEN_ID_CLIENT_SECRET` | `RDPGW_OIDC_CLIENT_SECRET` | rdpgw |
| `NPM_PROXY_PORT`, `NPM_PROXY_SCHEME` | removed (fixed in the compose file) | rdpgw |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM` | `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_USERNAME`, `EMAIL_PASSWORD`, `EMAIL_FROM` | vaultwarden |
| `ADMIN_TOKEN` | `VAULTWARDEN_ADMIN_TOKEN` | vaultwarden |
| `SIGNUPS_ALLOWED` | `VAULTWARDEN_SIGNUPS_ALLOWED` (default `true`, as before) | vaultwarden |
| `SMTP_SSL`, `WEBSOCKET_ENABLED` | removed (`SMTP_SECURITY: starttls` fixed, WebSockets run on the normal port) | vaultwarden |

**New variables for values that used to be hard-coded:**

| Stack | New variables | Old value |
|---|---|---|
| rdpgw | `AUTHENTIK_URL`, `RDPGW_OIDC_CLIENT_ID` | Authentik URL and client ID in the file |
| rdpgw | `RDPGW_SESSION_KEY`, `RDPGW_SESSION_ENCRYPTION_KEY`, `RDPGW_PAA_TOKEN_SIGNING_KEY`, `RDPGW_PAA_TOKEN_ENCRYPTION_KEY` | four identical keys in the file. **Generate four new, different keys.** |
| nextcloud | `APP_VERSION` | `nextcloud:latest`. Set it to the major version currently running |
| nextcloud | `COLLABORA_DOMAIN`, `WHITEBOARD_DOMAIN` | domains in the file / set by hand in NPM |
| sillytavern | `APP_DOMAIN` | domain in the file |
| dockhand | `DB_PASSWORD` | password in the file |

## Volumes

| Stack | Old volume | New volume |
|---|---|---|
| npmplus | `npm-data` | `app-data` |
| authentik | `database` | `postgres-data` |
| authentik | `data` | `app-data` |
| authentik | `custom-templates` | `app-templates` |
| authentik | `certs` | `worker-certs` |
| beszel | `data` | `app-data` |
| hastebin | `data` | `redis-data` |
| homepage | `config` | `app-config` |
| uptime-kuma | `data` | `app-data` |
| dockhand | `postgres_data` | `postgres-data` |
| dockhand | `dockhand_data` | `app-data` |
| rdpgw | `certs` | `app-certs` |
| rdpgw | `data` | `app-data` |
| rdpgw | `default-rdp` | `app-config` |
| sillytavern | `config` | `app-config` |
| sillytavern | `data` | `app-data` |
| sillytavern | `plugins` | `app-plugins` |
| sillytavern | `extensions` | `app-extensions` |
| nextcloud | `db` | `mariadb-data` |
| nextcloud | `redis` | `redis-data` |
| nextcloud | `main` | `app-html` |
| nextcloud | `data` | `app-data` ⚠️ contains all user files, copying can take long |
| nextcloud | `virus_db` | `clamav-data` (can also start empty, it downloads again) |
| nextcloud | `rclone_cache` | `rclone-sftp-cache` (can start empty) |
| netbird | `netbird_data` | `server-data` |
| vaultwarden | `data` | `app-data` ⚠️ contains the whole vault. Stop the old container before copying |

`crowdsec-config`, `crowdsec-data` (npmplus) and `autokuma-data` (uptime-kuma) keep their names.

Docker prefixes volumes with the project name: `<project>_<volume>`. Check the real names with `docker volume ls` first, because Dockhand may use a different project name than the folder name.

**Copying, per stack:**

```sh
# 1. Stop the old stack (volumes are kept)
docker compose -p <project> down

# 2. Create the new stack without starting it (creates the new, empty volumes)
docker compose -p <project> -f docker-compose.yml create

# 3. Copy every volume from the table
docker run --rm -v <project>_<old>:/from:ro -v <project>_<new>:/to alpine \
  sh -c 'cp -a /from/. /to/'

# 4. Start
docker compose -p <project> -f docker-compose.yml up -d
```

Delete the old volumes only once the stack runs correctly: `docker volume rm <project>_<old>`.

## Other changes

| Stack | Change |
|---|---|
| all | No `container_name` anymore. Containers are now called `<project>-<service>-1`. Anything that relied on the old names (bookmarks in Portainer/Dockhand, scripts) must be updated. |
| all | Main service renamed to `app` (e.g. `nginx-proxy-manager` / `npmplus` → `app`, Authentik `server` → `app`, Homepage `homepage` → `app`). |
| npmplus | `npmplus-docker-sync` → `docker-sync`, `npm-firewall` → `firewall`, `npmplus-init` → `crowdsec-init`. |
| authentik | **Redis removed** (no longer needed since 2025.10). The old `redis` container and its data are no longer used. |
| authentik | Docker socket mount of the worker is commented out (see [authentik/README.md](authentik/README.md)). |
| authentik, homepage, dockhand, rdpgw, sillytavern, nextcloud | Network `npm-frontend` → `npm-proxy` (the other stacks already used `npm-proxy`). |
| dockhand | The individual `/opt/…` mounts are replaced by one `DOCKHAND_STACKS_DIR` (default `/opt/stacks`). Move the stack folders there, or add one mount per folder. |
| nextcloud | Nextcloud, Collabora and Whiteboard now get their proxy hosts from labels. **Delete the manually created proxy hosts in NPMplus first**, otherwise the domains collide. |
| nextcloud | Collabora and rclone now reach Nextcloud internally (`http://app`). Run the `occ` commands from [nextcloud/README.md](nextcloud/README.md#setup) and point the rclone remotes in `auth.json` to `http://app/remote.php/dav/…`. |
| nextcloud | `redis:latest` → `redis:8-alpine`, `restart: always` → `unless-stopped`, rclone log level `DEBUG` → `INFO`. |
| sillytavern | The hand-written Authentik config in `npm.proxy.advanced.config` is replaced by `npm.proxy.auth_request: "authentik"`. `npm.proxy.domain` → `npm.proxy.domains`. Service `gluetun` → `vpn`, so the request proxy in SillyTavern's `config.yaml` becomes `http://vpn:8888`. |
| netbird | `config.yaml` and `dashboard.env` are now inline in the compose file. Copy `authSecret` and `store.encryptionKey` from the old `config.yaml` into `.env` **unchanged**, and compare the rest (see [netbird/README.md](netbird/README.md#migrating-from-an-existing-setup)). |
| netbird | `netbird-dashboard` → `app`, `netbird-server` → `server` (reachable for NPMplus under the alias `netbird-server`). The proxy host now comes from labels: **delete the manual proxy host in NPMplus first.** |
| vaultwarden | Was deployed via Portainer in the network `nginx-proxy-manager_default`. Now Dockhand + `npm-proxy`, proxy host from labels: **delete the old proxy host in NPMplus first.** The volume name depends on the old Portainer stack name, check it with `docker volume ls`. |
| rdpgw, sillytavern | Network-specific `extra_hosts` are commented out in the repo. Uncomment and adjust them locally. |
| hastebin, uptime-kuma, authentik | Stack network `internal` is now `internal: true` (no internet access). Services that need the internet are in `egress`. |
