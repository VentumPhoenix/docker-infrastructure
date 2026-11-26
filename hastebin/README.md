# Hastebin

Simple pastebin for sharing code snippets via short links. Pastes are stored in Redis.

**Upstream:** [toptal/haste-server](https://github.com/toptal/haste-server)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand.

## Notes

- **No login:** anyone who can reach the domain can create pastes. If that's not wanted, put Authentik in front of it with `npm.proxy.auth_request: "authentik"`. Keep in mind that shared links then require a login as well.
