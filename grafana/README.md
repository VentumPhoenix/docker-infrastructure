# Grafana

Dashboards for metrics: together with [Telegraf](../influxdb/#telegraf-every-host) and [InfluxDB](../influxdb/), it shows how hosts and containers are doing over time.

**Upstream:** [grafana/grafana](https://github.com/grafana/grafana)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand.
3. Log in at `https://<APP_DOMAIN>` as `admin` with `GRAFANA_ADMIN_PASSWORD`.
4. Add InfluxDB as a data source: query language Flux, URL `https://<influx domain>`, organization, and a token with **read** access to the bucket.

## Notes

- **No telemetry:** usage statistics, update checks and the news feed are off.
- **Registration closed:** only the admin or Authentik can create users.
- **Login via Authentik (optional):** create an OAuth2/OIDC provider in Authentik with the redirect URI `https://<APP_DOMAIN>/login/generic_oauth`, then set `GRAFANA_OIDC_ENABLED=true`, `AUTHENTIK_URL`, the client ID and secret. Roles come from Authentik groups: "Grafana Admins" → Admin, "Grafana Editors" → Editor, everyone else Viewer.
- **Data sources via their public URL:** `npm-proxy` doesn't let stacks talk to each other, so Grafana reaches InfluxDB over `egress` and the public domain, with a token.
- **Admin password** is passed as a file (`GF_SECURITY_ADMIN_PASSWORD__FILE`). It only applies when the admin user is created; later changes are made in the UI.
