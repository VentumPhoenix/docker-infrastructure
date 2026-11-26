# Uptime Kuma

Uptime monitoring with notifications. AutoKuma reads the `kuma.*` labels of all containers through the socket proxy and creates the monitors automatically, sorted into the four groups Infrastructure, Security, Monitoring and Apps.

**Upstream:** [louislam/uptime-kuma](https://github.com/louislam/uptime-kuma) · [BigBoot/AutoKuma](https://github.com/BigBoot/AutoKuma)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand. AutoKuma keeps restarting until step 3 is done, that's expected.
3. Open `https://<APP_DOMAIN>`, create the admin account, and log in with it. Uptime Kuma has only one account, so `KUMA_SERVICE_USER` / `KUMA_SERVICE_PASSWORD` must be exactly this account.

## Notes

- The four Kuma groups are defined once, as labels on the `autokuma` service. Other stacks only reference them via `kuma.<id>.http.parent_name`.
- `app` uses `x-base` instead of `x-hardened`: ping monitors need `NET_RAW`, and hardening hasn't been tested yet.
