# Telegraf

Collects metrics of the host (CPU, memory, disks, network, processes) and of all containers, and writes them to [InfluxDB](../influxdb/). [Grafana](../grafana/) shows them.

**Upstream:** [influxdata/telegraf](https://github.com/influxdata/telegraf) · [influxdata/influxdata-docker](https://github.com/influxdata/influxdata-docker)

## Setup

1. In InfluxDB, create an API token with write access to the bucket.
2. Copy `.env.example` to `.env` and fill in the required block.
3. Deploy the stack via Dockhand.

## Notes

- **Host network:** needed for the real network statistics of the host. Telegraf reaches the socket proxy of the `npmplus` stack by its fixed IP (`SOCKET_PROXY_NET_PREFIX`.2), because there is no Docker DNS in the host network.
- **Host filesystem (exception):** `/` is mounted read-only to `/hostfs`, so Telegraf reads the host's `/proc`, `/sys` and disks instead of the container's.
- **Token as a file:** the `secretstores.docker` plugin reads it from `/run/secrets/influxdb_token`. It never appears as an environment variable.
- **Config in the compose file:** `telegraf.conf` is defined inline (`configs:`). Add more inputs there.
- **Healthcheck:** `outputs.health` answers on `127.0.0.1:8099` (`TELEGRAF_HEALTH_PORT`) of the host. Change the port if it's taken.
- **Other hosts:** this stack relies on the socket proxy of the `npmplus` stack. On other hosts, remove `[[inputs.docker]]` or add a socket proxy like in [beszel-agent](../beszel-agent/).
