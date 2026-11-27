# 📋 Variable Register

Every variable used in any stack is listed here. **Same purpose → same name**, in every stack.

- Before adding a new variable, check whether one with the same purpose already exists.
- New variables are added here in the same commit.
- Naming patterns and syntax rules: see [CONVENTIONS.md § 7](CONVENTIONS.md#7-environment-variables--env).

**Legend:** ✅ required · ◐ required only in the stated case · – optional, the default applies

---

## General

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `APP_DOMAIN` | ✅ | – | Public domain of the stack's main service, without `https://` | every stack |
| `APP_VERSION` | ◐ if used | – | Image tag, when several services share one image or upgrades must go version by version | authentik, nextcloud, gitlab, wazuh |
| `TZ` | – | `Europe/Berlin` | Time zone of the containers | every stack except hastebin and netbird |
| `PUID` | – | `1000` | User ID the app runs as (only images that support it) | homepage, paperless, heimdall, mealie |
| `PGID` | – | `1000` | Group ID the app runs as | homepage, paperless, heimdall, mealie |

## Additional domains

Public domains of further services in a stack. Pattern: `<SERVICE>_DOMAIN`, without `https://`.

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `COLLABORA_DOMAIN` | ✅ | – | Domain of the Collabora online office | nextcloud |
| `WHITEBOARD_DOMAIN` | ✅ | – | Domain of the Nextcloud Whiteboard server | nextcloud |
| `DIRECTUS_DOMAIN` | ✅ | – | Domain of the Directus CMS | website |
| `PRETIX_DOMAIN` | ◐ variant `pretix` | – | Domain of the booking system and shop | website |

## Shared networks

These must have the **same value in every stack**.

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `NPM_PROXY_NETWORK` | – | `npm-proxy` | Name of the reverse proxy network | every stack |
| `SOCKET_PROXY_NETWORK` | – | `socket-proxy` | Name of the Docker API network | npmplus, homepage, uptime-kuma |
| `SOCKET_PROXY_HOST` | – | `socket-proxy` | Host name under which the socket proxy is reached | homepage, uptime-kuma |
| `SOCKET_PROXY_PORT` | – | `2375` | Port of the socket proxy | homepage, uptime-kuma, beszel, remote-host |

## NetBird (remote hosts)

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `NETBIRD_IP` | ✅ | – | NetBird IP of **this** host. On the central host: where the NPMplus admin API is published for remote syncs | remote-host, npmplus |
| `NETBIRD_CENTRAL_IP` | ✅ | – | NetBird IP of the central host (NPMplus, Dockhand, Beszel, Uptime Kuma) | remote-host |
| `REMOTE_HOST_NAME` | ✅ | – | Short name of a remote host: agent name in Dockhand, group of its proxy hosts in NPMplus | remote-host |
| `REMOTE_EGRESS_NET_PREFIX` | – | `172.28.0` | Subnet of the egress network of the remote-host stack (the socket proxy allows its gateway) | remote-host |
| `COMPOSE_PROFILES` | ✅ | – | Optional parts of the remote-host stack: `hawser`, `beszel` | remote-host |

## Database

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `DB_PASSWORD` | ✅ | – | Password of the stack's own database. Generate: `openssl rand -hex 32` | authentik, dockhand, nextcloud, paperless, mealie, tandoor, semaphore |
| `DB_ROOT_PASSWORD` | ✅ | – | Root password of the database, only for images that need one. Generate: `openssl rand -hex 32` | nextcloud |
| `DIRECTUS_DB_PASSWORD` | ✅ | – | Database password of Directus (stacks with more than one database use `<APP>_DB_PASSWORD`) | website |
| `PRETIX_DB_PASSWORD` | ◐ variant `pretix` | – | Database password of pretix | website |

DB name and DB user are not variables. They are hard-coded in the compose file (= stack name).

## Email (outgoing, SMTP)

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `EMAIL_HOST` | ◐ if the app should send email | – | SMTP server | authentik, vaultwarden, mealie, tandoor, gitlab, website |
| `EMAIL_PORT` | – | `587` | SMTP port. 587 = STARTTLS, which every stack uses | authentik, vaultwarden, mealie, tandoor, gitlab, website |
| `EMAIL_USERNAME` | – | – | SMTP login | authentik, vaultwarden, mealie, tandoor, gitlab, website |
| `EMAIL_PASSWORD` | – | – | SMTP password | authentik, vaultwarden, mealie, tandoor, gitlab, website |
| `EMAIL_FROM` | – | – | Sender address, e.g. `Authentik <auth@example.com>` | authentik, vaultwarden, mealie, tandoor, gitlab, website |

## Shared services

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `AUTHENTIK_URL` | ◐ variant `authentik` / OIDC apps | – | Full URL of Authentik including scheme and port, e.g. `https://auth.example.com:443`. Used by NPMplus for forward auth and by apps for OIDC | npmplus, rdpgw, grafana |

## Login via Authentik (OIDC)

OIDC client of an app at Authentik. Pattern: `<APP>_OIDC_CLIENT_ID` / `<APP>_OIDC_CLIENT_SECRET`.

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `RDPGW_OIDC_CLIENT_ID` | ✅ | – | Client ID of the Authentik provider | rdpgw |
| `RDPGW_OIDC_CLIENT_SECRET` | ✅ | – | Client secret of the Authentik provider | rdpgw |
| `RDPGW_OIDC_SLUG` | – | `rdpgw` | Slug of the application in Authentik | rdpgw |
| `GRAFANA_OIDC_ENABLED` | – | `false` | Enable login via Authentik | grafana |
| `GRAFANA_OIDC_CLIENT_ID` | ◐ if enabled | – | Client ID of the Authentik provider | grafana |
| `GRAFANA_OIDC_CLIENT_SECRET` | ◐ if enabled | – | Client secret of the Authentik provider | grafana |

## Metrics (InfluxDB)

The same names are used by every stack that talks to InfluxDB (influxdb, telegraf, grafana).

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `INFLUXDB_ADMIN_USER` | – | `admin` | Admin user, created on the first start | influxdb |
| `INFLUXDB_ADMIN_PASSWORD` | ✅ | – | Password of the admin user, only used on the first start | influxdb |
| `INFLUXDB_ADMIN_TOKEN` | ✅ | – | Admin API token, only used on the first start. Generate: `openssl rand -hex 32` | influxdb |
| `INFLUXDB_ORG` | – | `homelab` | Organization | influxdb, telegraf |
| `INFLUXDB_BUCKET` | – | `telegraf` | Bucket for the metrics | influxdb, telegraf |
| `INFLUXDB_RETENTION` | – | `30d` | How long metrics are kept, only used on the first start | influxdb |
| `INFLUXDB_URL` | ✅ | – | Public URL of InfluxDB, e.g. `https://influx.example.com` | influxdb (`telegraf`) |
| `INFLUXDB_TOKEN` | ✅ | – | API token of the client (Telegraf: write, Grafana: read), not the admin token | influxdb (`telegraf`) |

## Service accounts

Accounts an automation tool uses to log into an app. Pattern: `<APP>_SERVICE_USER` / `<APP>_SERVICE_PASSWORD`.

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `NPM_SERVICE_USER` | ✅ | – | Email of the NPMplus account that `npmplus-docker-sync` logs in with. Also becomes the initial admin on first start | npmplus, remote-host |
| `NPM_SERVICE_PASSWORD` | ✅ | – | Password of that account | npmplus, remote-host |
| `KUMA_SERVICE_USER` | ✅ | – | Uptime Kuma user that AutoKuma logs in with | uptime-kuma |
| `KUMA_SERVICE_PASSWORD` | ✅ | – | Password of that user | uptime-kuma |

## VPN (Gluetun)

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `VPN_WIREGUARD_PRIVATE_KEY` | ✅ | – | WireGuard private key from the VPN provider | sillytavern |
| `VPN_SERVICE_PROVIDER` | – | `protonvpn` | VPN provider, see the Gluetun docs | sillytavern |
| `VPN_SERVER_COUNTRIES` | – | (any) | Countries of the VPN servers, comma-separated | sillytavern |

## App-specific

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `ACME_EMAIL` | ✅ | – | Contact address for Let's Encrypt (expiry warnings). Not an SMTP setting | npmplus |
| `AUTHENTIK_SECRET_KEY` | ✅ | – | Key for signing cookies and tokens. Never change it after setup. Generate: `openssl rand -base64 60 \| tr -d '\n'` | authentik |
| `CROWDSEC_BOUNCER_KEY` | ◐ variant `crowdsec` | – | Shared key between the NPMplus bouncer and CrowdSec. Generate: `openssl rand -hex 32` | npmplus |
| `CROWDSEC_ENROLL_KEY` | – | – | Connects the instance to the CrowdSec Console | npmplus |
| `CROWDSEC_INSTANCE_NAME` | – | – | Name of the instance in the CrowdSec Console | npmplus |
| `BESZEL_AGENT_KEY` | ◐ variant `agent`, profile `beszel` | – | Public key of the hub, shown in the Beszel UI when adding a system | beszel, remote-host |
| `BESZEL_AGENT_TOKEN` | ◐ variant `agent`, profile `beszel` | – | Registration token from the Beszel UI | beszel, remote-host |
| `DOCKHAND_STACKS_DIR` | – | `/opt/stacks` | Folder on the host with the stack folders Dockhand deploys | dockhand |
| `RDPGW_SESSION_KEY` | ✅ | – | Session key, exactly 32 characters. Generate: `openssl rand -hex 16` | rdpgw |
| `RDPGW_SESSION_ENCRYPTION_KEY` | ✅ | – | Session encryption key, 32 characters, different from the others | rdpgw |
| `RDPGW_PAA_TOKEN_SIGNING_KEY` | ✅ | – | Signing key for gateway tokens, 32 characters, different from the others | rdpgw |
| `RDPGW_PAA_TOKEN_ENCRYPTION_KEY` | ✅ | – | Encryption key for gateway tokens, 32 characters, different from the others | rdpgw |
| `WHITEBOARD_JWT_SECRET` | ✅ | – | Shared secret between Nextcloud and the Whiteboard server. Generate: `openssl rand -hex 32` | nextcloud |
| `PAPERLESS_SECRET_KEY` | ✅ | – | Key for signing sessions and tokens. Generate: `openssl rand -hex 32` | paperless |
| `PAPERLESS_OCR_LANGUAGE` | – | `deu+eng` | OCR languages, joined with `+` | paperless |
| `PAPERLESS_CONSUME_DIR` | – | `app-consume` (volume) | Folder for new documents. A host path (e.g. scanner share) replaces the volume | paperless |
| `VAULTWARDEN_SIGNUPS_ALLOWED` | – | `true` | Allow anyone who can reach the domain to create an account | vaultwarden |
| `VAULTWARDEN_SIGNUPS_DOMAINS` | – | (empty = all) | Only these email domains may register, comma-separated | vaultwarden |
| `VAULTWARDEN_SIGNUPS_VERIFY` | – | `false` | Email address must be confirmed before the first login (needs `EMAIL_*`) | vaultwarden |
| `VAULTWARDEN_ADMIN_TOKEN` | – | (empty = admin page disabled) | Argon2 hash for the admin page (`/vaultwarden hash`). Contains `$`, so single quotes in `.env` | vaultwarden |
| `RCLONE_AUTH_FILE` | – | `/opt/rclone-sftp/auth.json` | Credentials file of the SFTP server on the host | nextcloud |
| `RCLONE_SFTP_PORT` | – | `18022` | Host port of the SFTP server | nextcloud |
| `NETBIRD_AUTH_SECRET` | ✅ | – | Shared secret of the NetBird relay. Generate: `openssl rand -hex 32` | netbird |
| `NETBIRD_STORE_ENCRYPTION_KEY` | ✅ | – | Encryption key of the NetBird database. Generate: `openssl rand -base64 32`. Never change it after setup | netbird |
| `NETBIRD_STUN_PORT` | – | `3478` | Host port (UDP) for STUN | netbird |
| `RCLONE_LOG_LEVEL` | – | `INFO` | Log level of rclone (`DEBUG`, `INFO`, `NOTICE`, `ERROR`) | nextcloud |
| `HAWSER_SERVER_URL` | ◐ profile `hawser` | – | WebSocket URL of Dockhand for this agent (`wss://…`), shown in Dockhand | remote-host |
| `HAWSER_TOKEN` | ◐ profile `hawser` | – | Token of this agent, shown in Dockhand | remote-host |
| `HAWSER_STACKS_DIR` | – | `/opt/stacks` | Folder on the host with the stack folders Dockhand deploys there | remote-host |
| `BESZEL_HUB_URL` | ◐ profile `beszel` | – | URL of the Beszel hub the agent reports to | remote-host |
| `BESZEL_AGENT_PORT` | – | `45876` | Port on the NetBird IP the hub connects to | remote-host |
| `TELEGRAF_INTERVAL` | – | `30s` | Collection interval | influxdb (`telegraf`) |
| `TELEGRAF_HOSTNAME` | – | (host name) | Host name in the metrics | influxdb (`telegraf`) |
| `TELEGRAF_HEALTH_PORT` | – | `8099` | Localhost port of the health endpoint (host network) | influxdb (`telegraf`) |
| `TELEGRAF_SOCKET_PROXY_PORT` | – | `2376` | Localhost port of Telegraf's own socket proxy | influxdb (`telegraf`) |
| `GRAFANA_ADMIN_USER` | – | `admin` | Local admin user | grafana |
| `GRAFANA_ADMIN_PASSWORD` | ✅ | – | Password of the local admin user, only used when the user is created | grafana |
| `MEALIE_ALLOW_SIGNUP` | – | `false` | Allow anyone who can reach the domain to create an account | mealie |
| `TANDOOR_SECRET_KEY` | ✅ | – | Django secret key, at least 50 characters. Generate: `openssl rand -hex 32` | tandoor |
| `TANDOOR_ALLOW_SIGNUP` | – | `0` | Allow anyone who can reach the domain to create an account (`1` = yes) | tandoor |
| `SEMAPHORE_ADMIN_USER` | – | `admin` | First admin, created on the first start | semaphore |
| `SEMAPHORE_ADMIN_EMAIL` | – | `admin@localhost` | Email of the first admin | semaphore |
| `SEMAPHORE_ADMIN_PASSWORD` | ✅ | – | Password of the first admin, only used on the first start | semaphore |
| `SEMAPHORE_ACCESS_KEY_ENCRYPTION` | ✅ | – | Encrypts stored SSH keys and passwords. Never change it. Generate: `head -c32 /dev/urandom \| base64` | semaphore |
| `CODE_SERVER_HASHED_PASSWORD` | ✅ | – | Argon2 hash of the code-server password. Contains `$`, so single quotes in `.env` | code-server |
| `CODE_SERVER_WORKSPACE` | – | `app-workspace` (volume) | Project folder; a host path (owned by UID 1000) replaces the volume | code-server |
| `GITLAB_ROOT_PASSWORD` | ✅ | – | Password of the root user, only used on the first start | gitlab |
| `GITLAB_SSH_PORT` | – | `2222` | Host port for git over SSH | gitlab |
| `WAZUH_INDEXER_PASSWORD` | ✅ | – | Password of the indexer user `admin`, must match its hash in `internal_users.yml` | wazuh |
| `WAZUH_DASHBOARD_PASSWORD` | ✅ | – | Password of the indexer user `kibanaserver`, must match its hash in `internal_users.yml` | wazuh |
| `WAZUH_API_PASSWORD` | ✅ | – | Password of the API user `wazuh-wui`, must match `wazuh.yml`. 8–64 chars, upper/lower case, digit, symbol | wazuh |
| `WAZUH_CONFIG_DIR` | – | `/opt/stacks/wazuh/config` | Upstream config folder (certificates and config files) on the host | wazuh |
| `WAZUH_AGENT_PORT` | – | `1514` | Host port for agent events | wazuh |
| `WAZUH_ENROLLMENT_PORT` | – | `1515` | Host port for agent enrollment | wazuh |
| `WAZUH_INDEXER_HEAP` | – | `1g` | Java heap of the indexer | wazuh |
| `WEB_IMAGE` | ✅ | – | Image of the website, e.g. `ghcr.io/you/website:latest` | website |
| `DIRECTUS_SECRET` | ✅ | – | Directus secret key. Generate: `openssl rand -hex 32` | website |
| `DIRECTUS_ADMIN_EMAIL` | ✅ | – | First Directus admin, only used on the first start | website |
| `DIRECTUS_ADMIN_PASSWORD` | ✅ | – | Password of the first Directus admin, only used on the first start | website |
| `PRETIX_INSTANCE_NAME` | – | `pretix` | Name of the pretix instance in emails and the UI | website |
| `NPM_AUTH_REQUEST_PROVIDERS` | – | `authentik` | Forward-auth providers of the central NPMplus, for remote syncs (`none` without Authentik) | remote-host |

## Infrastructure (`npmplus` and `remote-host`)

| Variable | Req. | Default | Description |
|---|---|---|---|
| `DOCKER_GID` | ✅ | – | Group ID of the Docker socket on the host: `ls -ln /var/run/docker.sock`. Also used by `remote-host` and `influxdb/docker-compose.telegraf.yml`, which bring their own socket proxy |
| `NPM_PROXY_NET_PREFIX` | – | `172.30.0` | First three octets of the `npm-proxy` subnet. Change only if it collides. Also used by `gitlab` (trusted proxy IP). **Required and unique per host** in `remote-host` (e.g. `172.30.1`) |
| `NPM_PROXY_BRIDGE` | – | `br-npm` | Name of the Linux bridge of `npm-proxy` (used by `firewall`, max. 15 characters) |
| `SOCKET_PROXY_NET_PREFIX` | – | `172.31.0` | First three octets of the `socket-proxy` subnet. Also used by the Beszel `agent` variant, which runs in the host network and has to reach the socket proxy by IP |
| `SOCKET_PROXY_BRIDGE` | – | `br-sockprx` | Name of the Linux bridge of `socket-proxy` (max. 15 characters) |

---

Variables that were renamed during the switch to these conventions are listed in [MIGRATION.md](MIGRATION.md).
