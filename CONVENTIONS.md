# 📐 Stack Conventions

This document defines how every stack in this repository is built. Goal: if you know one stack, you know them all. The same things have the same names, sit in the same place and use the same defaults.

> **TL;DR**
> - One folder per stack containing `docker-compose.yml` and `.env.example`
> - No `container_name`, the main service is called `app`
> - **Zero trust:** nothing talks to anything unless a network explicitly allows it, and that includes the internet
> - Every web UI requires a login: the app's own login, or Authentik in front of it (one label)
> - The base file is the secure minimum. Features that change the stack itself (CrowdSec …) are variant files
> - Every service uses exactly one anchor: `x-hardened`, or `x-base` if the image needs capabilities
> - No published ports. Services are reachable only through NPMplus (network `npm-proxy`)
> - No direct Docker socket, only through `socket-proxy`
> - Both proxy network names can be changed via variables (defaults `npm-proxy` / `socket-proxy`)
> - Required variables are listed in `x-required`, optional ones use `${VAR:-default}`
> - In `.env.example`, required variables come first and optional ones below them
> - Fixed key order (see [§ 5](#5-key-order))

---

## Contents

1. [Security model (zero trust)](#1-security-model-zero-trust)
2. [Folders & files](#2-folders--files)
3. [Compose file layout](#3-compose-file-layout)
4. [Naming](#4-naming)
5. [Key order](#5-key-order)
6. [Defaults (anchors)](#6-defaults-anchors)
7. [Environment variables & `.env`](#7-environment-variables--env)
8. [Secrets](#8-secrets)
9. [Images & versions](#9-images--versions)
10. [Networks](#10-networks)
11. [Volumes](#11-volumes)
12. [Healthchecks & dependencies](#12-healthchecks--dependencies)
13. [Hardening & resources](#13-hardening--resources)
14. [Labels (NPM, Kuma, Homepage)](#14-labels-npm-kuma-homepage)
15. [Formatting & comments](#15-formatting--comments)
16. [Template](#16-template)
17. [Checklist for new stacks](#17-checklist-for-new-stacks)

---

## 1. Security model (zero trust)

**Principle: deny by default, allow explicitly, and make every allowance visible in the compose file.**

A container is trusted neither because it runs on the same host nor because it sits in the same network. Every connection it needs must be granted explicitly. To keep this manageable, there is exactly **one mechanism per kind of access**, and you can read it straight off the compose file:

| Access | Default | Granted by | Visible in compose as |
|---|---|---|---|
| Internet → service | ❌ denied | NPMplus only (80/443) | network `npm-proxy` + `npm.proxy.*` labels |
| Person → web UI | ❌ login required | the app's own login, otherwise Authentik | label `npm.proxy.auth_request` (§ 14) |
| Service ↔ service (shared networks) | ❌ denied | not possible (ICC off + `firewall` of the `npmplus` stack) | – |
| Service ↔ service (same stack) | ✅ within the stack | stack network `internal` | `networks: [internal]` |
| Service → internet / LAN | ❌ denied | stack network `egress` | `egress:` with `gw_priority: 1` |
| Service → Docker API | ❌ denied | `socket-proxy`, read-only, allowlist | network `socket-proxy` |
| Service → secrets | only its own | Compose `secrets:` | `secrets: [...]` |
| Service → host (shared networks) | ❌ denied | not possible from `npm-proxy` / `socket-proxy` (only NPMplus for `host.docker.internal`) | – |
| Container → host / kernel | minimal | `x-hardened` (or `x-base`), limits | anchors, `cap_add` |

This results in a simple rule for reviews: **every network, every `cap_add` and every secret a service has is a permission.** If you can't explain why a service needs it, remove it.

The layers in detail:

1. **Ingress:** Only NPMplus publishes ports. Apps sit in `npm-proxy`, where only NPMplus may initiate connections to them. Apps can only reply.
2. **Lateral movement:** `npm-proxy` and `socket-proxy` have inter-container communication disabled. A compromised app cannot reach other apps, only its own stack (via `internal`). It can't reach the host itself through these networks either (SSH, other services on the host), only NPMplus may, for `host.docker.internal`.
3. **Egress:** No network provides internet access by default. `internal` networks have none (`internal: true`), and the `firewall` of the `npmplus` stack blocks all outbound traffic from `npm-proxy` (except NPMplus itself for certificates and CrowdSec for its blocklist). A service that needs outbound access (fetching mail, app store, VPN tunnel, LAN hosts) gets the stack network `egress`, with `gw_priority: 1` so its default route goes through `egress` and not through `npm-proxy`.
   > NPMplus only handles **inbound** traffic. It is not a forward proxy, so outbound connections never go through it. Services of the same stack talk to each other via `internal`, never via their public domain.
   >
   > `gw_priority` needs **Docker Engine 28.0** and **Docker Compose v2.33.1** or newer (see [README](README.md#requirements)). Don't use compose features that need newer versions without updating the requirements table.
4. **Docker API:** Only through `socket-proxy` with a minimal read-only allowlist. Only trusted services join that network.
5. **Container:** No new privileges, all capabilities dropped where possible, read-only root filesystem where possible, memory and PID limits on every service.
6. **Secrets:** Passed as files (`/run/secrets/…`), not as environment variables. Environment variables of every container can be read through the Docker API (`containers/<id>/json`), and thus by every service in `socket-proxy`.
7. **Identity:** No web UI is reachable without a login. If an app has its own login, that's enough. If it has none and its content is worth protecting, Authentik goes in front of it via forward auth (label `npm.proxy.auth_request: "authentik"`). Where an app supports OIDC, OIDC via Authentik is preferred over forward auth.

---

## 2. Folders & files

```
<stack>/
├── docker-compose.yml            # required
├── docker-compose.<variant>.yml  # optional, e.g. docker-compose.crowdsec.yml
├── .env.example                  # required as soon as the stack uses variables
├── .env                          # local only, NEVER commit (.gitignore)
└── README.md                     # required, see "Stack README" below
```

- **Folder name = stack name = Compose project name.** It is lowercase kebab-case and named after the product: `uptime-kuma`, `npmplus`, `authentik`.
- The file is called `docker-compose.yml`, not `compose.yaml`. That is what Dockhand and the other stacks expect.
- Only `.env.example` goes into Git. Real `.env` files are listed in `.gitignore`.

### Deployment via Dockhand

**Every stack can be deployed through Dockhand as is**: one compose file, no files next to it that the stack needs at runtime (config files are inlined, see "Config files" below), and variables from `.env` or Dockhand's environment editor.

If a stack can't be deployed through Dockhand, or only with restrictions, its `README.md` says so under "Setup". Today that applies to:

| Stack | Why |
|---|---|
| `npmplus` | must exist **before** Dockhand (it creates the networks Dockhand joins). First deploy by hand, updates via Dockhand afterwards. |
| `dockhand` | can't deploy or update itself reliably. Always deployed and updated by hand. |

### Variants

Every stack can come in several variants. They follow a fixed pattern:

- **`docker-compose.yml` is always the base:** the most secure minimal setup that works on its own. Its only requirement is the `npmplus` stack.
- **Each variant adds exactly one optional feature** on top of the base and is named after that feature: `docker-compose.<feature>.yml`.
- **Combinations** join the features alphabetically with `-`: `docker-compose.authentik-crowdsec.yml`.
- Variants are **complete, standalone files**, not override files, because Dockhand always deploys exactly one file.
- Everything a variant adds or changes compared to the base is marked with `# <Feature>:`, e.g. `# Authentik: …`. Everything else is identical to the base, character for character.
- There is **one `.env.example` per stack** for all variants. Variables that only a variant needs get their own block per feature, right after the required block (`REQUIRED FOR VARIANT crowdsec`).
- If a stack has variants, its `README.md` lists them in a short table (file, what it adds).

**A variant only exists if the feature changes the stack itself:** additional services, volumes, networks or required variables. If a feature is just a label or an environment variable that does no harm when unused, it goes into the base file with a comment instead of becoming a variant.

Standard features:

| Feature | Variant name | What it adds |
|---|---|---|
| CrowdSec | `crowdsec` | `npmplus` stack: log analysis + blocklist + WAF (CrowdSec container, init job) |
| Authentik | `authentik` | `npmplus` stack: `AUTH_REQUEST_AUTHENTIK_UPSTREAM`, so NPMplus can do forward auth |
| Agent | `agent` | `beszel` stack: monitoring agent for the local host |
| Tika | `tika` | `paperless` stack: Office documents and emails via Tika + Gotenberg |

New features get a short, lowercase name and are added to this table.

**Authentik in front of an app is not a variant**, just the label `npm.proxy.auth_request: "authentik"` in the base file (see § 14). If NPMplus runs without the `authentik` variant, `npmplus-docker-sync` ignores the label without errors.

> ⚠️ Ignoring the label means the app is then reachable **without** a login. That's why an app with no login of its own states in its header comment that it requires the `authentik` variant of NPMplus.

### Stack README

Every stack has a `README.md` with this structure. Sections that would be empty are left out, except the first two.

```markdown
# <Display Name>

One or two sentences: what the service does and why it's in this setup.

**Upstream:** [owner/repo](https://github.com/owner/repo) · [owner/other-repo](https://github.com/owner/other-repo)

## Variants

| File | Adds |
|---|---|
| `docker-compose.yml` | base |
| `docker-compose.<feature>.yml` | … |

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand (or say here why that's not possible).
3. First-time steps in the UI, if any (e.g. create the service user).

## Notes

Anything special: known limitations, why something deviates from the conventions.
```

The **Upstream** line links the original repository of every image the stack uses, so readers can find the official docs and report issues there.

### Config files

Small configuration files are **inlined** in the compose file via top-level `configs:` with `content:`, not placed as separate files on the host. That way a stack stays one file that Dockhand can deploy as is.

```yaml
services:
  app:
    configs:
      - source: app-docker
        target: /app/config/docker.yaml

configs:
  app-docker:
    content: |
      my-docker:
        host: ${SOCKET_PROXY_HOST:-socket-proxy}
        port: ${SOCKET_PROXY_PORT:-2375}
```

Config names follow the pattern `<service>-<purpose>`, just like volumes.

---

## 3. Compose file layout

The top-level blocks always appear in this order:

```yaml
# 1. Header comment
# 2. x-required       (list of all required variables)
# 3. x-anchors        (x-base, x-hardened)
# 4. services         (main service first, then workers, then databases/caches)
# 5. configs          (if any)
# 6. secrets          (if any)
# 7. volumes
# 8. networks
```

**Header comment** (required, exactly these 4 lines):

```yaml
# Hastebin – pastebin for code snippets
# Upstream: https://github.com/toptal/haste-server
# Requires: network npm-proxy (stack npmplus)
# Updates: auto
```

`Updates:` is either `auto` (Dockhand may update automatically) or `manual – <reason>` (see § 9).

**Service order:** `app` → other parts of the application (`worker`, `scheduler` …) → databases / caches (`postgres`, `redis` …) → helper containers.

The top-level blocks `configs` … `networks` follow the same order as the keys inside a service.

---

## 4. Naming

### Containers

**No `container_name`.** Compose assigns names itself using the pattern `<stack>-<service>-<n>`, e.g. `hastebin-app-1`.

Why:
- There are no name collisions between stacks.
- The name tells you immediately which stack a container belongs to.
- Stacks can run in parallel or multiple times (test instance, second host).

> Exception only if an external tool strictly requires a fixed container name. The reason is then stated in a comment.

### Services

| Role | Name | Example |
|---|---|---|
| Main application (web UI / API) | `app` | `app` |
| Other parts of the same application | by function | `worker`, `scheduler`, `agent` |
| Databases, caches, queues | by technology | `postgres`, `mariadb`, `redis` |
| Infrastructure addressed **across stacks** | unique & descriptive | `socket-proxy` |

**Important:** A service name is also a DNS name in every network the service is attached to. Since every stack has an `app`, the name `app` is **ambiguous** in the shared network `npm-proxy`. Therefore:
- Within a stack (network `internal`), services are addressed by name: `postgres`, `redis`, `app`.
- Across stacks, only services with a unique name are addressed by name, e.g. `socket-proxy`. An `app` is never addressed across stacks by its service name.
- If NPMplus has to address a service by name (e.g. in `npm.proxy.advanced.config`), the service gets a **unique network alias** `<stack>-<service>` in `npm-proxy`:
  ```yaml
      networks:
        npm-proxy:
          aliases:
            - netbird-server
  ```
  In the nginx config, the name is then resolved at request time (`resolver 127.0.0.11` + `set $$upstream …`). This way NPMplus still starts when the service is down.

### Why `app` and not the product name?

The container name already contains the stack: `nextcloud-app-1`, `nextcloud-collabora-1`. A service named after the product would only repeat it (`nextcloud-nextcloud-1`). With `app`, the same place has the same name in every stack (`depends_on: app`, `http://app:3001`, labels on `app`), and you can see at a glance which container is the main service and which ones belong to it.

### Networks, volumes, secrets

| Kind | Pattern | Examples |
|---|---|---|
| Networks | fixed set, see § 10 | `npm-proxy`, `socket-proxy`, `internal`, `egress` |
| Volumes | `<service>-<purpose>` | `app-data`, `postgres-data` |
| Secrets | `<purpose>` in snake_case | `db_password`, `secret_key` |

---

## 5. Key order

Inside a service, keys always appear in this order. Keys that aren't needed are simply left out.

```yaml
  app:
    <<: *hardened               # 1. anchor (or *base)

    image:                       # 2. what runs
    user:
    group_add:
    entrypoint:
    command:

    depends_on:                  # 3. when it starts

    environment:                 # 4. configuration
    configs:
    secrets:

    volumes:                     # 5. data
    devices:

    ports:                       # 6. network
    extra_hosts:
    networks:                    #    or network_mode

    healthcheck:                 # 7. health

    cap_add:                     # 8. hardening & resources
    read_only:
    tmpfs:
    pids_limit:
    mem_limit:
    shm_size:
    stop_grace_period:

    labels:                      # 9. integration (always last)
```

In the actual file there are **no blank lines** between the groups. The blank lines above are only for readability. Services are separated by exactly one blank line.

`restart`, `security_opt`, `cap_drop` and `logging` do **not** appear in the service, because they come from the anchors (see § 6).

---

## 6. Defaults (anchors)

Every compose file contains these two anchors, **verbatim**:

```yaml
x-base: &base
  restart: unless-stopped
  security_opt:
    - no-new-privileges:true
  logging:
    driver: json-file
    options: { max-size: "10m", max-file: "3" }

x-hardened: &hardened
  <<: *base
  cap_drop:
    - ALL
```

| Anchor | Contents | Used by |
|---|---|---|
| `x-base` | restart policy, `no-new-privileges`, log rotation (3 × 10 MB) | services whose image needs capabilities |
| `x-hardened` | everything from `x-base` **plus** all Linux capabilities dropped | **normal case**, every service whose image runs with it |

`x-hardened` contains `x-base`, so every service uses **exactly one** anchor:

```yaml
services:
  app:
    <<: *hardened   # normal case
  postgres:
    <<: *base       # image needs capabilities (see below)
```

**Notes:**
- `<<` merges keys **shallowly**. If a service sets `security_opt` or `logging` itself, that replaces the anchor's value completely, so `no-new-privileges:true` must be repeated.
- `restart` is always `unless-stopped`, never `always`. A container you stopped on purpose stays stopped after a reboot.
- **Overriding** an anchor value is allowed with a comment. Typical case: one-shot jobs (init containers) get `restart: "no"` and are started via `depends_on: … condition: service_completed_successfully`.
- If an image needs capabilities, `*hardened` plus a targeted `cap_add` is preferred over `*base`. Example from NPMplus: `cap_add: [NET_BIND_SERVICE, SETGID]`. The missing capability shows up in the log.
- Official database images (`postgres`, `redis`, `mariadb`) switch users and change file ownership on startup. They usually need `CHOWN`, `SETUID`, `SETGID` (sometimes more). If finding the minimal set is too fiddly, `*base` is acceptable for databases, because they sit only in `internal` anyway.
- `read_only: true` is deliberately **not** part of `x-hardened`, because most apps need to write somewhere. It is set per service wherever the image tolerates it (typically Go binaries, sidecars, init jobs). Writable paths are provided via `tmpfs` if needed.

---

## 7. Environment variables & `.env`

### What goes into `.env`?

`.env` contains **only what the operator has to adjust**:
- domains
- secrets (passwords, keys, tokens)
- versions shared by several services
- environment-specific values (time zone, UID/GID, network names and prefixes)

**Hard-coded in the compose file** are internal, non-secret values: DB name, DB user, internal host names (`postgres`, `redis`), internal ports, and feature flags that are always the same for this stack.

### Required vs. optional

All **required** variables are listed once at the top of the file in `x-required`. Compose aborts with a clear error if one of them is missing. At the same time, the list documents at a glance what has to be set.

```yaml
x-required:
  - ${APP_DOMAIN:?}
  - ${DB_PASSWORD:?}
```

| Case | Syntax | Example |
|---|---|---|
| Required | listed in `x-required`, then used as `${VAR}` | `${APP_DOMAIN}` |
| Optional with default | `${VAR:-default}` | `${TZ:-Europe/Berlin}` |
| Optional, empty allowed | `${VAR:-}` | `${EMAIL_FROM:-}` |
| ❌ forbidden | `${VAR}` without an `x-required` entry | a missing value only causes a warning and silently ends up empty |

- The order in `x-required` is the same as in the required block of `.env.example`.
- **Secrets never get a default.** Not `${EMAIL_PASSWORD:-admin}`, but either required or `${EMAIL_PASSWORD:-}`.
- Variables that are evaluated **inside the container** (e.g. in a healthcheck) are escaped with `$$`: `$${POSTGRES_USER}`.

### `environment` is always a map

```yaml
# ✅ correct
environment:
  TZ: ${TZ:-Europe/Berlin}
  DB_HOST: postgres

# ❌ wrong (list syntax)
environment:
  - TZ=Europe/Berlin
```

Groups inside `environment` are separated by a short comment (`# Database`, `# Email`).

### Variable register

**Every variable of every stack is listed in [VARIABLES.md](VARIABLES.md)**, with its default, a short description and the stacks that use it. The register is the single source for variable names.

- **Same purpose → same name**, in every stack. If two stacks send email, both use `EMAIL_HOST`, `EMAIL_PORT` …, never `SMTP_HOST` in one and `MAIL_SERVER` in the other.
- Before adding a new variable, check the register. If a variable with the same purpose exists, reuse it.
- A new variable is added to the register in the same commit.

### Naming patterns

| Pattern | Used for | Examples |
|---|---|---|
| `APP_<PURPOSE>` | the stack's main service, in every stack | `APP_DOMAIN`, `APP_VERSION` |
| `DB_<PURPOSE>` | the stack's own database | `DB_PASSWORD` |
| `EMAIL_<PURPOSE>` | outgoing email (SMTP) | `EMAIL_HOST`, `EMAIL_FROM` |
| `<NETWORK>_<PURPOSE>` | shared networks, named after the network | `NPM_PROXY_NETWORK`, `SOCKET_PROXY_HOST` |
| `<APP>_SERVICE_USER` / `<APP>_SERVICE_PASSWORD` | account an automation tool uses to log into an app | `NPM_SERVICE_USER`, `KUMA_SERVICE_USER` |
| `<APP>_URL` | full URL of a shared service that other stacks talk to | `AUTHENTIK_URL` |
| `<SERVICE>_DOMAIN` | public domain of an additional service in the stack (the main one is `APP_DOMAIN`) | `COLLABORA_DOMAIN`, `WHITEBOARD_DOMAIN` |
| `<APP>_OIDC_CLIENT_ID` / `<APP>_OIDC_CLIENT_SECRET` | OIDC client of an app at Authentik | `RDPGW_OIDC_CLIENT_ID` |
| `DB_ROOT_PASSWORD` | root/admin password of the stack's database, if the image needs one | MariaDB |
| `VPN_<PURPOSE>` | VPN tunnel of a stack (Gluetun) | `VPN_WIREGUARD_PRIVATE_KEY` |
| `<APP>_<PURPOSE>` | everything specific to one app | `AUTHENTIK_SECRET_KEY`, `CROWDSEC_BOUNCER_KEY` |

All variable names are in UPPERCASE with `_`. `<APP>` is the stack name without hyphens (`uptime-kuma` → `KUMA`, short forms are fine if unambiguous).

### `.env.example` layout

The file has two blocks: **first everything that is required, then everything that is optional.** If you only fill in the top block, you get a working stack.

1. **Required:** active lines, with a placeholder or empty.
2. **Optional:** commented out, with the default as value. You can see right away what applies if you don't set anything. To change a value, remove the `#` and adjust it.

Within each block the order is: general → network → database → email → app-specific. Every variable has a comment above it, and secrets say how to generate them.

```dotenv
# ════════════════════════════════════════════════════════════
#  REQUIRED – the stack won't start without these
# ════════════════════════════════════════════════════════════

# Public domain (without https://)
APP_DOMAIN=app.example.com

# Database password – generate: openssl rand -hex 32
DB_PASSWORD=

# ════════════════════════════════════════════════════════════
#  OPTIONAL – commented out = default is active
# ════════════════════════════════════════════════════════════

# Time zone
#TZ=Europe/Berlin

# Name of the reverse proxy network (must match the npmplus stack)
#NPM_PROXY_NETWORK=npm-proxy
```

---

## 8. Secrets

Secrets are handed to containers **as files**, not as environment variables. The value still comes from `.env`, so nothing changes for the operator.

```yaml
services:
  postgres:
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    environment: DB_PASSWORD   # value is taken from .env
```

- Inside the container the secret is available at `/run/secrets/<name>`.
- Most images support this via a `*_FILE` variable (`POSTGRES_PASSWORD_FILE`, `MYSQL_PASSWORD_FILE` …) or a `file://` value (Authentik).
- **Fallback:** If an image only accepts plain environment variables, the secret is passed as an environment variable and a comment states why.
- **Optional secrets** (e.g. `EMAIL_PASSWORD`, which may be empty) are passed as environment variables with `${VAR:-}`. A Compose secret can't be optional.
- `compose config` does **not** check whether the variable behind `secrets.<name>.environment` is set. That's why every secret variable must be listed in `x-required`.
- A service only gets the secrets it actually needs.

---

## 9. Images & versions

| Kind | Rule | Example |
|---|---|---|
| Databases | **always pin the major version** (major upgrades need a migration) | `postgres:17-alpine`, `redis:8-alpine` |
| Applications | major tag if available, otherwise `latest` | `louislam/uptime-kuma:2` |
| Own / beta images | exact version | `ghcr.io/ventumphoenix/npmplus-docker-sync:1.0.0-beta.9` |
| Several services, same image | tag via `${APP_VERSION}` (required) | Authentik `server` + `worker` |

- Docker Hub images are written in short form (`postgres:17-alpine`), all others with registry (`ghcr.io/…`).
- The `-alpine` variant is preferred where available.

### Update policy

Updates are handled by Dockhand. Whether a stack may update automatically is decided **per stack** and recorded in the header comment (`# Updates: auto` or `# Updates: manual – <reason>`, § 3).

| `manual` if … | Examples |
|---|---|
| the stack is critical infrastructure and everything else depends on it | NPMplus, socket proxy, Authentik |
| updates run database or data migrations | Authentik, apps with breaking releases |
| the project often ships breaking changes or has no stable tags | beta images, young projects |

Everything else is `auto`. The tag must match the policy:
- `auto`: a moving tag (major tag or `latest`), so Dockhand finds updates.
- `manual`: preferably a tag that only changes when you change it in the file (exact version, or `${APP_VERSION}`). If the project publishes no usable version tags, `latest` is acceptable. Auto-update must then be switched off for this stack in Dockhand.
- Database images are always pinned to their major version, even in `auto` stacks. A major upgrade of a database is never automatic.

---

## 10. Networks

There are exactly four kinds of networks. Each one stands for one permission (see § 1).

| Network | Type | Permission | Who joins |
|---|---|---|---|
| `npm-proxy` | external, created by stack `npmplus` | reachable by NPMplus | **only** the service NPMplus serves (usually `app`) |
| `socket-proxy` | external, created by stack `npmplus` | read access to the Docker API | **only** services that need the Docker API |
| `internal` | per stack, `internal: true` | talk to other services in the same stack | every service that talks to other stack services |
| `egress` | per stack, ICC off | outbound internet access | **only** services that need to reach the internet |

### Proxy networks: fixed key, variable name

The **key** in the compose file is always `npm-proxy` or `socket-proxy`. Services join the network under that key. The **actual network name** on the host comes from a variable with a default. That way the networks can be renamed without touching a single compose file.

| Variable | Default |
|---|---|
| `NPM_PROXY_NETWORK` | `npm-proxy` |
| `SOCKET_PROXY_NETWORK` | `socket-proxy` |

In **every app stack**:

```yaml
networks:
  npm-proxy:
    name: ${NPM_PROXY_NETWORK:-npm-proxy}
    external: true
  socket-proxy:       # only if needed
    name: ${SOCKET_PROXY_NETWORK:-socket-proxy}
    external: true
  internal:
    internal: true
  egress:             # only if needed
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
```

In the **`npmplus` stack**, which creates the networks, the same name is used:

```yaml
networks:
  npm-proxy:
    name: ${NPM_PROXY_NETWORK:-npm-proxy}
    driver: bridge
    # …
  socket-proxy:
    name: ${SOCKET_PROXY_NETWORK:-socket-proxy}
    driver: bridge
    internal: true
    # …
```

`npmplus-docker-sync` gets the name from the same variable: `NPM_NETWORK: ${NPM_PROXY_NETWORK:-npm-proxy}`.

> If you change a name, set it the same way in **every** stack: in the `npmplus` stack and in every app stack's `.env`.

### Rules

- **No `ports:`** except in the `npmplus` stack (80/443). All services are reachable only through the reverse proxy. A port is only allowed for protocols that can't go through an HTTP reverse proxy (e.g. SFTP, STUN/UDP). It is then marked as an exception in a comment, made configurable via a variable, and bound to a specific IP if possible.
- Databases and caches join **only** `internal`, never `npm-proxy` or `egress`.
- `npm-proxy` and `socket-proxy` have inter-container communication disabled (`enable_icc: false` + `firewall`). Apps cannot reach each other there, and `npm-proxy` has no internet access.
- `internal` is always `internal: true`. It provides no internet access. A stack with only one service doesn't need `internal`.
- **`egress` only when it's really needed**, and with a comment saying what for. Before adding it, check whether the connection can stay inside the stack instead (e.g. Nextcloud ↔ Collabora via `http://collabora:9980` and `http://app`). If a feature that needs the internet is optional, ask whether it's used.
- `egress` has ICC disabled. It only provides internet access, not a second path between the stack's services.
- Every service in `egress` uses map syntax with `gw_priority: 1`, so its default route goes through `egress`:
  ```yaml
      networks:
        npm-proxy:
        internal:
        egress:   # fetching documents from mail accounts (IMAP)
          gw_priority: 1   # default route via egress, npm-proxy has no internet
  ```
- A **published port** needs a network that isn't `internal`. If a service only has `internal` but publishes a port (e.g. SFTP), it joins `egress` for that, with a comment.
- `internal` and `egress` get no `name:`. Compose turns them into `<stack>_internal` / `<stack>_egress` automatically.
- Fixed IPs (`ipv4_address`) exist only in the `npmplus` stack, because the firewall rules rely on them. To keep them from colliding with dynamic addresses, the network splits its subnet: fixed IPs in the lower half (`.2`–`.127`), dynamic ones via `ip_range` in the upper half (`.128/25`).
- Networks that only exist temporarily for a migration (e.g. `npm-legacy` → old `npm-frontend`) are marked with a comment and removed once the migration is done.

### Docker socket

**`/var/run/docker.sock` is never mounted directly**, except in `socket-proxy` itself and in **Dockhand**. Dockhand deploys stacks and needs write access, which the socket proxy deliberately doesn't allow. No other service gets this exception. Anything that needs the Docker API (AutoKuma, Homepage, Beszel agent …) joins the `socket-proxy` network and uses:

```yaml
DOCKER_HOST: tcp://${SOCKET_PROXY_HOST:-socket-proxy}:${SOCKET_PROXY_PORT:-2375}
```

If an app expects host and port separately (e.g. Homepage's `docker.yaml`), the same two variables are used.

The socket proxy allows read access only. Caution: `containers/<name>/json` also returns the environment variables of other containers. That's why secrets go into files (§ 8) and only trusted services join this network.

---

## 11. Volumes

- **Named Docker volumes** are used, not bind mounts. Exceptions are host paths that are strictly required (e.g. the Docker socket in `socket-proxy`, the stack folders in Dockhand, a credentials file that must stay outside the repo). An exception is marked in a comment, and its host path is configurable via a variable with a sensible default.
- The naming pattern is `<service>-<purpose>`:

| Example | Meaning |
|---|---|
| `app-data` | application data |
| `app-config` | application configuration |
| `postgres-data` | database files |
| `redis-data` | Redis persistence |

- **Volume or host path, chosen by the operator:** if some users need a host folder (e.g. a scanner share) and others don't, the mount uses a variable whose default is the named volume: `${PAPERLESS_CONSUME_DIR:-app-consume}:/usr/src/paperless/consume`. Without the variable it's the volume, with a path it's a bind mount.
- **Every service has its own volumes.** Two services share a volume only if they deliberately access the same data (e.g. `server` and `worker` in Authentik). That is then commented.
- Compose prefixes the stack name automatically (`hastebin_redis-data`), so volumes get no `name:`.
- If a service only needs part of a volume, use `subpath` + `read_only` instead of the whole volume (example: CrowdSec only reads `nginx/logs` from `npm-data`).

### Backups

Backups are handled outside the stacks, by UrBackup on the host. Because of the naming rules, every volume has a predictable path:

```
/var/lib/docker/volumes/<stack>_<service>-<purpose>/_data
e.g. /var/lib/docker/volumes/authentik_postgres-data/_data
```

- No stack contains its own backup container.
- **Databases:** A file copy of a running database is not reliably consistent. Database volumes are therefore backed up via a dump (e.g. `pg_dump` in a UrBackup pre-backup script), not only as raw files. If a stack needs something special for this, its `README.md` says so.

---

## 12. Healthchecks & dependencies

**Every container has a healthcheck in the compose file**, even if the image already ships one. That way the status is visible in Dockhand, `docker ps` and Uptime Kuma, and `depends_on: service_healthy` works everywhere. If the image has its own healthcheck, the same command is used and marked with `# same as the image's own healthcheck`.

The only exception are one-shot jobs (`restart: "no"`, e.g. `crowdsec-init`). They run once and exit, so there's nothing to check.

If the image has no suitable tool, use the first option that works:

1. the app's own health command or endpoint (`ak healthcheck`, `/beszel health`, `/health`)
2. `curl` / `wget` against a local URL
3. `bash` + `/dev/tcp` if there is no HTTP client (send a request, check the answer)
4. a process check (`pgrep`) as a last resort, with a comment

Default values:

```yaml
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
```

- `test` in exec form (`["CMD", …]`). `CMD-SHELL` only if shell features (pipes, variables) are needed.
- Always `127.0.0.1` instead of `localhost` (avoids IPv6 surprises), and never the public domain.
- A health command of the image itself is preferred over generic checks (`/beszel health`, `healthcheck.sh` …).
- Deviating from the defaults is fine, e.g. a longer `start_period` for slow-starting services.

Common tests:

| Service | `test` |
|---|---|
| Postgres | `["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]` |
| Redis | `["CMD", "redis-cli", "ping"]` |
| MariaDB | `["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]` |

**`depends_on` always with a condition:**

```yaml
    depends_on:
      postgres:
        condition: service_healthy
```

Use `service_started` only if the target has no healthcheck.

---

## 13. Hardening & resources

In addition to the anchors:

- **Every service has `pids_limit` and `mem_limit`.** Guideline values:

| Kind | `mem_limit` | `pids_limit` |
|---|---|---|
| Small sidecar (socket proxy, firewall) | `64m` | `50` |
| Helper service (sync, AutoKuma) | `256m` | `100` |
| Regular application | `256m`–`512m` | `200` |
| Database | `512m` | `200` |
| Reverse proxy (NPMplus) | `512m` | `2048` |

- Run as non-root (`user:`) wherever the image supports it.
- `cap_add` only selectively and with a comment saying what the capability is needed for.
- `user: root`, `privileged: true` and `network_mode: host` only with a reason in a comment.
- No secrets in plain text in the compose file. They always live in `.env` (and reach the container via § 8).

---

## 14. Labels (NPM, Kuma, Homepage)

Labels go **only on the service that is served** (usually `app`). They always come last in the service, in this order, and always as a map:

```yaml
    labels:
      # Reverse proxy (npmplus-docker-sync)
      npm.proxy.domains: ${APP_DOMAIN}
      npm.proxy.port: "8080"
      npm.proxy.scheme: "http"
      # Monitoring (AutoKuma)
      kuma.<stack>.http.name: "Display Name"
      kuma.<stack>.http.url: "https://${APP_DOMAIN}"
      kuma.<stack>.http.parent_name: "apps"
      # Dashboard (Homepage)
      homepage.group: "Apps"
      homepage.name: "Display Name"
      homepage.icon: "<stack>"
      homepage.href: "https://${APP_DOMAIN}"
      homepage.description: "Short description"
```

| Label | Rule |
|---|---|
| `npm.proxy.*` | `domains`, `port`, `scheme` are **always** set, even if `scheme` matches the default |
| `npm.proxy.port` | **internal** container port, as a string |
| `npm.proxy.auth_request` | `"authentik"` if the app has no login of its own and is worth protecting, always with a comment above it (see below). Comes right after `scheme`. |
| `npm.proxy.advanced.config` | only for nginx settings the other labels can't express (timeouts, buffering, body size), with a comment saying why. Never for forward auth, that's what `auth_request` is for. `$` must be written as `$$`. |
| Additional services | if a stack serves more than one domain (e.g. Collabora next to Nextcloud), every served service gets its own `npm.proxy.*` and `kuma.*` labels. `homepage.*` only on the main service. |
| `kuma.<id>.…` | `<id>` = stack/folder name (`kuma.uptime-kuma…`, `kuma.npmplus…`) |
| `kuma.<id>.http.url` | health endpoint if available (`/api/health`), otherwise the start page |
| `kuma.<id>.http.parent_name` | ID of the Kuma group, matching `homepage.group` (see below) |
| `homepage.group` | one of the four fixed groups (see below) |
| `homepage.icon` | name from [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons), usually = stack name |
| `homepage.href` | **always** set |
| `homepage.description` | 1–3 words |

All label values are in double quotes. Exception: plain variables like `${APP_DOMAIN}`.

### Authentik in front of an app

```yaml
    labels:
      # Reverse proxy (npmplus-docker-sync)
      npm.proxy.domains: ${APP_DOMAIN}
      npm.proxy.port: "3000"
      npm.proxy.scheme: "http"
      # Authentik forward auth: app has no login of its own
      npm.proxy.auth_request: "authentik"
```

The header comment of such a stack then says:

```yaml
# Requires: network npm-proxy (stack npmplus, variant authentik)
```

### Groups

There are exactly **four groups**. They are identical in Homepage and Uptime Kuma, so a service shows up in the same place in both.

| Homepage (`homepage.group`) | Kuma (`parent_name`) | Contains | Examples |
|---|---|---|---|
| `Infrastructure` | `infrastructure` | what everything else runs on: proxy, network, deployment | NPMplus, NetBird, Dockhand |
| `Security` | `security` | login, protection, secrets | Authentik, CrowdSec |
| `Monitoring` | `monitoring` | watching the infrastructure | Uptime Kuma, Beszel |
| `Apps` | `apps` | everything you actually use | Hastebin |

- The Kuma groups are defined **once**, as labels on the `autokuma` service in the `uptime-kuma` stack:
  ```yaml
      labels:
        kuma.infrastructure.group.name: "Infrastructure"
        kuma.security.group.name: "Security"
        kuma.monitoring.group.name: "Monitoring"
        kuma.apps.group.name: "Apps"
  ```
- The order of the groups on the Homepage dashboard is set in Homepage's `settings.yaml`: Infrastructure → Security → Monitoring → Apps.
- A new group is only added if one of the four really doesn't fit. The maximum is four.

---

## 15. Formatting & comments

- **Everything is in English:** comments, labels, descriptions, `.env.example`, READMEs.
- Indentation: **2 spaces**. Lists are indented under their key:
  ```yaml
  volumes:
    - app-data:/data      # ✅
  volumes:
  - app-data:/data        # ❌
  ```
- Strings in **double** quotes (`"80:80"`, `"http"`). Port mappings are always quoted.
- Short option maps may be inline: `options: { max-size: "10m", max-file: "3" }`.
- Comments are short and explain the *why*, not the *what*.
- **No change markers** like `# NEW:` or `# 1. image changed`. That's what Git commits are for. In variant files, differences from the base may be marked, e.g. `# CrowdSec: …`.
- Commented-out code is allowed only for **documented optional features** and starts with `# Optional: …`. Dead code gets deleted.
- No trailing whitespace, and the file ends with a newline.

---

## 16. Template

### `docker-compose.yml`

```yaml
# Example – short description of the service
# Upstream: https://github.com/example/example
# Requires: network npm-proxy (stack npmplus)
# Updates: auto

x-required:
  - ${APP_DOMAIN:?}
  - ${DB_PASSWORD:?}

x-base: &base
  restart: unless-stopped
  security_opt:
    - no-new-privileges:true
  logging:
    driver: json-file
    options: { max-size: "10m", max-file: "3" }

x-hardened: &hardened
  <<: *base
  cap_drop:
    - ALL

services:
  app:
    <<: *hardened
    image: ghcr.io/example/example:1
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      TZ: ${TZ:-Europe/Berlin}
      APP_URL: "https://${APP_DOMAIN}"
      # Database
      DB_HOST: postgres
      DB_NAME: example
      DB_USER: example
      DB_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - app-data:/data
    networks:
      npm-proxy:
      internal:
      egress:   # sends notification emails
        gw_priority: 1   # default route via egress, npm-proxy has no internet
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    pids_limit: 200
    mem_limit: 256m
    labels:
      # Reverse proxy (npmplus-docker-sync)
      npm.proxy.domains: ${APP_DOMAIN}
      npm.proxy.port: "8080"
      npm.proxy.scheme: "http"
      # Monitoring (AutoKuma)
      kuma.example.http.name: "Example"
      kuma.example.http.url: "https://${APP_DOMAIN}/health"
      kuma.example.http.parent_name: "apps"
      # Dashboard (Homepage)
      homepage.group: "Apps"
      homepage.name: "Example"
      homepage.icon: "example"
      homepage.href: "https://${APP_DOMAIN}"
      homepage.description: "Example service"

  postgres:
    # Image switches users on startup, so no *hardened
    <<: *base
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: example
      POSTGRES_USER: example
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    pids_limit: 200
    mem_limit: 512m

secrets:
  db_password:
    environment: DB_PASSWORD

volumes:
  app-data:
  postgres-data:

networks:
  npm-proxy:
    name: ${NPM_PROXY_NETWORK:-npm-proxy}
    external: true
  internal:
    internal: true
  egress:
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
```

### `.env.example`

```dotenv
# ════════════════════════════════════════════════════════════
#  REQUIRED – the stack won't start without these
# ════════════════════════════════════════════════════════════

# Public domain (without https://)
APP_DOMAIN=example.example.com

# Database password – generate: openssl rand -hex 32
DB_PASSWORD=

# ════════════════════════════════════════════════════════════
#  OPTIONAL – commented out = default is active
# ════════════════════════════════════════════════════════════

# Time zone
#TZ=Europe/Berlin

# Name of the reverse proxy network (must match the npmplus stack)
#NPM_PROXY_NETWORK=npm-proxy
```

---

## 17. Checklist for new stacks

- [ ] Folder name in kebab-case = product name
- [ ] `docker-compose.yml` with header comment (description, upstream, requirements, update policy)
- [ ] Base file is the secure minimum, optional features are variant files
- [ ] Web UI has its own login, or `npm.proxy.auth_request: "authentik"` with comment
- [ ] Small config files inlined via `configs: content:`
- [ ] All required variables listed in `x-required`
- [ ] Anchors `x-base` / `x-hardened` copied verbatim, every service uses exactly one
- [ ] No `container_name`, main service is called `app`
- [ ] Key order according to § 5
- [ ] `environment` as a map, no `${VAR}` without an `x-required` entry, secrets without defaults
- [ ] Secrets passed as files (`secrets:` + `*_FILE`) where the image supports it
- [ ] DB images with pinned major version
- [ ] No `ports:`, only `app` in `npm-proxy`, DBs only in `internal`
- [ ] Proxy networks with `name: ${NPM_PROXY_NETWORK:-npm-proxy}` / `${SOCKET_PROXY_NETWORK:-socket-proxy}`
- [ ] `internal` with `internal: true`, `egress` only where really needed (internal URLs checked first), with a reason and `gw_priority: 1`
- [ ] No direct Docker socket
- [ ] Volumes named `<service>-<purpose>`
- [ ] Every container with an explicit healthcheck (except one-shot jobs), `pids_limit`, `mem_limit`
- [ ] Deployable via Dockhand as is, or the README says why not
- [ ] `depends_on` with `condition: service_healthy`
- [ ] Labels complete (npm → kuma → homepage), same group in Kuma and Homepage
- [ ] `.env.example` present: required first, optional below (commented out with default)
- [ ] Every variable is in [VARIABLES.md](VARIABLES.md), existing names reused for the same purpose
- [ ] `README.md` following the stack README template
- [ ] Everything in English
- [ ] `docker compose config` runs without errors and warnings
