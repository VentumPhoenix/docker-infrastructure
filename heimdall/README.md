# Heimdall

Start page with a tile for every web app. "Enhanced" tiles show live stats of the app (e.g. queue size, free space).

**Upstream:** [linuxserver/Heimdall](https://github.com/linuxserver/Heimdall) · [linuxserver/docker-heimdall](https://github.com/linuxserver/docker-heimdall)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Make sure NPMplus runs with the `authentik` variant (see below).
3. Deploy the stack via Dockhand.
4. Open `https://<APP_DOMAIN>` and add your tiles.

## Notes

- **Login via Authentik:** Heimdall only offers an optional basic auth, so it's protected with `npm.proxy.auth_request: "authentik"`. Without the `authentik` variant of NPMplus, the label is ignored and the page is public.
- **Tiles via public URLs:** enhanced tiles query the apps over `egress` and their public domains. `ALLOW_INTERNAL_REQUESTS=false` keeps Heimdall from querying private addresses in the LAN.
- **Homepage or Heimdall?** Both are start pages. [Homepage](../homepage/) fills itself from labels, Heimdall is maintained by hand in its UI.
