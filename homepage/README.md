# Homepage

Dashboard of the setup. Services appear automatically: Homepage reads the `homepage.*` labels of all containers through the socket proxy.

**Upstream:** [gethomepage/homepage](https://github.com/gethomepage/homepage)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Make sure NPMplus runs with the `authentik` variant. Homepage has no login of its own (see below).
3. Deploy the stack via Dockhand.
4. Set the group order in `settings.yaml` (volume `app-config`):
   ```yaml
   layout:
     Infrastructure:
     Security:
     Monitoring:
     Apps:
   ```

## Notes

- **Login via Authentik:** Homepage has no login, so it's protected with `npm.proxy.auth_request: "authentik"`. Without the `authentik` variant of NPMplus, the label is ignored and the dashboard is public.
- **Remote hosts:** add the socket proxy of every remote host (stack [remote-host](../remote-host/)) to `configs.app-docker`, e.g.
  ```yaml
  vps1:
    host: 100.64.0.2
    port: 2375
  ```
  Homepage then also shows the labeled containers of that host. It reaches them via `egress` and NetBird.
- `docker.yaml` is defined inline in the compose file and points to the socket proxy. Any changes to it belong in the compose file, not in the volume.
