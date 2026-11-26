# SillyTavern

Chat frontend for LLMs. Outgoing requests to cloud APIs go through a VPN (Gluetun), so the providers don't see the home IP.

**Upstream:** [SillyTavern/SillyTavern](https://github.com/SillyTavern/SillyTavern) · [qdm12/gluetun](https://github.com/qdm12/gluetun)

| Service | Purpose |
|---|---|
| `app` | SillyTavern |
| `vpn` | Gluetun: WireGuard tunnel + HTTP proxy on `vpn:8888` |

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Make sure NPMplus runs with the `authentik` variant (see below).
3. Deploy the stack via Dockhand.
4. In SillyTavern's `config.yaml` (volume `app-config`), set the request proxy to `http://vpn:8888`.

## Notes

- **Login via Authentik:** the UI holds your API keys, so it's protected with `npm.proxy.auth_request: "authentik"`. Without the `authentik` variant of NPMplus, the label is ignored.
- **Streaming:** `npm.proxy.advanced.config` disables buffering and raises timeouts, so long streamed answers don't get cut off.
- **LLM server without DNS:** use the commented `extra_hosts` block. The mapping is specific to your network, so adjust it locally.
- Gluetun reads the WireGuard key from `/run/secrets/wireguard_private_key` and ships its own healthcheck.
