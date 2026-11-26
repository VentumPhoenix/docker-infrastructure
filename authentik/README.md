# Authentik

Identity provider of the setup. Apps with OIDC support log in through Authentik. Apps without a login of their own get Authentik in front of them via forward auth (label `npm.proxy.auth_request: "authentik"`, requires the `authentik` variant of NPMplus).

**Upstream:** [goauthentik/authentik](https://github.com/goauthentik/authentik)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand.
3. Open `https://<APP_DOMAIN>/if/flow/initial-setup/` and create the admin account.
4. For forward auth: create a proxy provider + application in Authentik and assign it to the embedded outpost.

## Notes

- **No Redis:** since version 2025.10, Authentik keeps everything in PostgreSQL. `APP_VERSION` must be 2025.10 or newer.
- **Secrets** reach the containers as files (`file:///run/secrets/…`). The optional `EMAIL_PASSWORD` is a plain environment variable, because a Compose secret can't be optional.
- **Docker integration (open):** Authentik can manage outposts as containers itself, but that needs write access to the Docker API. `socket-proxy` only allows reading, so the mount is commented out. The embedded outpost works without it.
- **Updates:** manual. Read the release notes before raising `APP_VERSION`.
