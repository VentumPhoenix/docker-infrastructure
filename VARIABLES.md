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
| `APP_VERSION` | ◐ if used | – | Image tag, only when several services share one image | authentik, nextcloud |
| `TZ` | – | `Europe/Berlin` | Time zone of the containers | every stack except hastebin and netbird |
| `PUID` | – | `1000` | User ID the app runs as (only images that support it) | homepage, paperless |
| `PGID` | – | `1000` | Group ID the app runs as | homepage, paperless |

## Additional domains

Public domains of further services in a stack. Pattern: `<SERVICE>_DOMAIN`, without `https://`.

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `COLLABORA_DOMAIN` | ✅ | – | Domain of the Collabora online office | nextcloud |
| `WHITEBOARD_DOMAIN` | ✅ | – | Domain of the Nextcloud Whiteboard server | nextcloud |

## Shared networks

These must have the **same value in every stack**.

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `NPM_PROXY_NETWORK` | – | `npm-proxy` | Name of the reverse proxy network | every stack |
| `SOCKET_PROXY_NETWORK` | – | `socket-proxy` | Name of the Docker API network | npmplus, homepage, uptime-kuma |
| `SOCKET_PROXY_HOST` | – | `socket-proxy` | Host name under which the socket proxy is reached | homepage, uptime-kuma |
| `SOCKET_PROXY_PORT` | – | `2375` | Port of the socket proxy | homepage, uptime-kuma, beszel, telegraf |

## Database

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `DB_PASSWORD` | ✅ | – | Password of the stack's own database. Generate: `openssl rand -hex 32` | authentik, dockhand, nextcloud, paperless |
| `DB_ROOT_PASSWORD` | ✅ | – | Root password of the database, only for images that need one. Generate: `openssl rand -hex 32` | nextcloud |

DB name and DB user are not variables. They are hard-coded in the compose file (= stack name).

## Email (outgoing, SMTP)

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `EMAIL_HOST` | ◐ if the app should send email | – | SMTP server | authentik, vaultwarden |
| `EMAIL_PORT` | – | `587` | SMTP port. 587 = STARTTLS, which every stack uses | authentik, vaultwarden |
| `EMAIL_USERNAME` | – | – | SMTP login | authentik, vaultwarden |
| `EMAIL_PASSWORD` | – | – | SMTP password | authentik, vaultwarden |
| `EMAIL_FROM` | – | – | Sender address, e.g. `Authentik <auth@example.com>` | authentik, vaultwarden |

## Shared services

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `AUTHENTIK_URL` | ◐ variant `authentik` / OIDC apps | – | Full URL of Authentik including scheme and port, e.g. `https://auth.example.com:443`. Used by NPMplus for forward auth and by apps for OIDC | npmplus, rdpgw |

## Login via Authentik (OIDC)

OIDC client of an app at Authentik. Pattern: `<APP>_OIDC_CLIENT_ID` / `<APP>_OIDC_CLIENT_SECRET`.

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `RDPGW_OIDC_CLIENT_ID` | ✅ | – | Client ID of the Authentik provider | rdpgw |
| `RDPGW_OIDC_CLIENT_SECRET` | ✅ | – | Client secret of the Authentik provider | rdpgw |
| `RDPGW_OIDC_SLUG` | – | `rdpgw` | Slug of the application in Authentik | rdpgw |

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
| `INFLUXDB_URL` | ✅ | – | Public URL of InfluxDB, e.g. `https://influx.example.com` | telegraf |
| `INFLUXDB_TOKEN` | ✅ | – | API token of the client (Telegraf: write, Grafana: read), not the admin token | telegraf |

## Service accounts

Accounts an automation tool uses to log into an app. Pattern: `<APP>_SERVICE_USER` / `<APP>_SERVICE_PASSWORD`.

| Variable | Req. | Default | Description | Used in |
|---|---|---|---|---|
| `NPM_SERVICE_USER` | ✅ | – | Email of the NPMplus account that `npmplus-docker-sync` logs in with. Also becomes the initial admin on first start | npmplus |
| `NPM_SERVICE_PASSWORD` | ✅ | – | Password of that account | npmplus |
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
| `BESZEL_AGENT_KEY` | ◐ `agent`, `remote-agent` | – | Public key of the hub, shown in the Beszel UI when adding a system | beszel |
| `BESZEL_AGENT_TOKEN` | ◐ `agent`, `remote-agent` | – | Registration token from the Beszel UI | beszel |
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
| `HAWSER_SERVER_URL` | ✅ | – | WebSocket URL of Dockhand for this agent (`wss://…`), shown in Dockhand | dockhand (`hawser`) |
| `HAWSER_TOKEN` | ✅ | – | Token of this agent, shown in Dockhand | dockhand (`hawser`) |
| `HAWSER_AGENT_NAME` | – | (empty) | Name of the host in Dockhand | dockhand (`hawser`) |
| `HAWSER_STACKS_DIR` | – | `/opt/stacks` | Folder on the host with the stack folders Dockhand deploys there | dockhand (`hawser`) |
| `BESZEL_HUB_URL` | ✅ | – | URL of the Beszel hub the agent reports to | beszel (`remote-agent`) |
| `BESZEL_AGENT_PORT` | – | `45876` | Port on the host the hub connects to | beszel (`remote-agent`) |
| `BESZEL_SOCKET_PROXY_PORT` | – | `2375` | Localhost port of the agent's own socket proxy | beszel (`remote-agent`) |
| `TELEGRAF_INTERVAL` | – | `30s` | Collection interval | telegraf |
| `TELEGRAF_HOSTNAME` | – | (host name) | Host name in the metrics | telegraf |
| `TELEGRAF_HEALTH_PORT` | – | `8099` | Localhost port of the health endpoint (host network) | telegraf |

## Infrastructure (`npmplus` stack only)

| Variable | Req. | Default | Description |
|---|---|---|---|
| `DOCKER_GID` | ✅ | – | Group ID of the Docker socket on the host: `ls -ln /var/run/docker.sock`. Also used by `beszel/docker-compose.remote-agent.yml`, which brings its own socket proxy |
| `NPM_PROXY_NET_PREFIX` | – | `172.30.0` | First three octets of the `npm-proxy` subnet. Change only if it collides |
| `NPM_PROXY_BRIDGE` | – | `br-npm` | Name of the Linux bridge of `npm-proxy` (used by `firewall`, max. 15 characters) |
| `SOCKET_PROXY_NET_PREFIX` | – | `172.31.0` | First three octets of the `socket-proxy` subnet. Also used by the Beszel `agent` variant and by `telegraf`, which run in the host network and have to reach the socket proxy by IP |
| `SOCKET_PROXY_BRIDGE` | – | `br-sockprx` | Name of the Linux bridge of `socket-proxy` (max. 15 characters) |

---

Variables that were renamed during the switch to these conventions are listed in [MIGRATION.md](MIGRATION.md).
