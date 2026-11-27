# InfluxDB

Time series database for metrics. [Telegraf](../telegraf/) writes host and container metrics into it, [Grafana](../grafana/) turns them into dashboards.

**Upstream:** [influxdata/influxdb](https://github.com/influxdata/influxdb) · [influxdata/influxdata-docker](https://github.com/influxdata/influxdata-docker)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand. The first start creates the admin user, organization, bucket and admin token.
3. Log in at `https://<APP_DOMAIN>` and create two API tokens with as little access as possible:
   - for Telegraf: write access to the bucket → `INFLUXDB_TOKEN` in the telegraf stack
   - for Grafana: read access to the bucket → used in Grafana's data source

## Notes

- **Version 2:** the established combination with Telegraf and Grafana. InfluxDB 3 Core exists as well, but uses a different API and setup.
- **Init values only count once:** `INFLUXDB_ADMIN_*`, `INFLUXDB_ORG`, `INFLUXDB_BUCKET` and `INFLUXDB_RETENTION` are only used when the database is created. Later changes are made in the UI.
- **Access from other stacks** goes through the public URL with a token. `npm-proxy` doesn't let stacks talk to each other directly, and Telegraf on other hosts needs the public URL anyway.
- **No internet:** InfluxDB needs none, telemetry is off (`INFLUXD_REPORTING_DISABLED`).
- **Admin token:** the token from `.env` has full access. Use it only for administration, not in Telegraf or Grafana.
