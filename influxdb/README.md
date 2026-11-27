# InfluxDB

Time series database for metrics. Telegraf (included here) writes host and container metrics into it, [Grafana](../grafana/) turns them into dashboards.

**Upstream:** [influxdata/influxdb](https://github.com/influxdata/influxdb) · [influxdata/telegraf](https://github.com/influxdata/telegraf) · [influxdata/influxdata-docker](https://github.com/influxdata/influxdata-docker)

## Files

| File | Runs on | Purpose |
|---|---|---|
| `docker-compose.yml` | this host | InfluxDB |
| `docker-compose.telegraf.yml` | **every host to monitor** (also this one) | Telegraf + its own read-only socket proxy |

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand. The first start creates the admin user, organization, bucket and admin token.
3. Log in at `https://<APP_DOMAIN>` and create two API tokens with as little access as possible:
   - for Telegraf: write access to the bucket → `INFLUXDB_TOKEN` for `docker-compose.telegraf.yml`
   - for Grafana: read access to the bucket → used in Grafana's data source

## Notes

- **Version 2:** the established combination with Telegraf and Grafana. InfluxDB 3 Core exists as well, but uses a different API and setup.
- **Init values only count once:** `INFLUXDB_ADMIN_*`, `INFLUXDB_ORG`, `INFLUXDB_BUCKET` and `INFLUXDB_RETENTION` are only used when the database is created. Later changes are made in the UI.
- **Access from other stacks** goes through the public URL with a token. `npm-proxy` doesn't let stacks talk to each other directly, and Telegraf on other hosts needs the public URL anyway.
- **No internet:** InfluxDB needs none, telemetry is off (`INFLUXD_REPORTING_DISABLED`).
- **Admin token:** the token from `.env` has full access. Use it only for administration, not in Telegraf or Grafana.

## Telegraf (every host)

`docker-compose.telegraf.yml` collects metrics of the host it runs on (CPU, memory, disks, network, processes) and of its containers, and writes them to InfluxDB via its public URL.

| Service | Purpose |
|---|---|
| `telegraf` | Telegraf, in the host network |
| `socket-proxy` | read-only Docker API, only the calls the docker input needs, reachable via `127.0.0.1` only |

1. In InfluxDB, create an API token with write access to the bucket.
2. On the host to monitor, copy this folder, copy `.env.example` to `.env` and fill in the Telegraf block (`INFLUXDB_URL`, `INFLUXDB_TOKEN`, `DOCKER_GID`).
3. Deploy it via Dockhand (through Hawser on other hosts) or by hand: `docker compose -f docker-compose.telegraf.yml up -d`.

- **Host network:** needed for the real network statistics of the host. That's why Telegraf reaches its socket proxy via `127.0.0.1`.
- **Own socket proxy:** it works the same on every host, with or without the `npmplus` stack. It only allows container list, inspect, stats, `info` and `version`.
- **Host filesystem (exception):** `/` is mounted read-only to `/hostfs`, so Telegraf reads the host's `/proc`, `/sys` and disks instead of the container's.
- **Token as a file:** the `secretstores.docker` plugin reads it from `/run/secrets/influxdb_token`.
- **Config in the compose file:** `telegraf.conf` is defined inline (`configs:`). Add more inputs there.
- **Ports on the host (localhost only):** health endpoint `TELEGRAF_HEALTH_PORT` (8099), socket proxy `TELEGRAF_SOCKET_PROXY_PORT` (2376). Change them if they're taken.
