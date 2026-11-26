# RDP Gateway

Remote desktop gateway: RDP sessions run over HTTPS through the reverse proxy, so no RDP port is open to the internet. The login goes through Authentik (OIDC).

**Upstream:** [bolkedebruin/rdpgw](https://github.com/bolkedebruin/rdpgw)

## Setup

1. In Authentik, create an OAuth2/OIDC provider + application with the slug `rdpgw` (or set `RDPGW_OIDC_SLUG`). Redirect URI: `https://<APP_DOMAIN>/callback`.
2. Copy `.env.example` to `.env`, fill in the required block and generate **four different** session keys.
3. Put `cert.pem` and `key.pem` into the volume `app-certs`, and `default.rdp` into `app-config`.
4. Deploy the stack via Dockhand.

## Notes

- **Host selection (check):** with `unsigned`, the client passes the target host. Check in the rdpgw docs which hosts this allows, and restrict it with the commented `RDPGW_SERVER__HOSTS` line if needed.
- **Hosts without DNS:** names like `desktop-pc` can be mapped via the commented `extra_hosts` block. These mappings are specific to your network, so they don't belong in the repo. Uncomment and adjust them locally.
- **TLS inside:** RDPGW serves HTTPS itself on port 443 with its own certificate. NPMplus forwards to it with `scheme: https`.
- **No healthcheck yet:** the image has no known health command.
