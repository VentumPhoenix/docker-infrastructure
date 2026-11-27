# Remote host

Connects another Docker host to the central infrastructure. The host only needs to be in NetBird. After that, everything is managed from the central host: Dockhand deploys stacks, Beszel monitors it, the central NPMplus serves its apps, Uptime Kuma and Homepage pick up their labels. **App stacks run on it unchanged**, with the same files as on the central host.

**Upstream:** [Finsys/hawser](https://github.com/Finsys/hawser) · [henrygd/beszel](https://github.com/henrygd/beszel) · [VentumPhoenix/npmplus-docker-sync](https://github.com/VentumPhoenix/npmplus-docker-sync) · [wollomatic/socket-proxy](https://github.com/wollomatic/socket-proxy)

| Service | Profile | Purpose |
|---|---|---|
| `socket-proxy` | always | read-only Docker API: locally for the sync and the Beszel agent, via NetBird for AutoKuma and Homepage of the central host |
| `firewall` | always | iptables rules: only the central host reaches the apps, apps have no internet and no access to this host |
| `hawser` | `hawser` | Dockhand agent (edge mode, no inbound port) |
| `beszel-agent` | `beszel` | Beszel agent, listens on the NetBird IP only |
| `npmplus-sync` | always | creates proxy hosts for the apps of this host in the central NPMplus; also keeps `npm-proxy` in existence |

## How it fits together

```
Central host (NetBird 100.64.0.1)                Remote host (NetBird 100.64.0.2)
┌──────────────────────────────────┐             ┌─────────────────────────────────────┐
│ NPMplus ── forwards to ──────────┼── NetBird ─▶│ npm-proxy 172.30.1.0/24 ── app       │
│   ▲ admin API :81 on 100.64.0.1 ◀┼─────────────┼── npmplus-sync                      │
│ Dockhand ◀── WebSocket ──────────┼─────────────┼── hawser                            │
│ Beszel hub ── :45876 ────────────┼────────────▶│ beszel-agent                        │
│ AutoKuma, Homepage ── :2375 ─────┼────────────▶│ socket-proxy (read-only)            │
└──────────────────────────────────┘             └─────────────────────────────────────┘
```

- **Same networks as the central host:** this stack creates `npm-proxy` and `socket-proxy` on the remote host too, so app stacks deploy here unchanged. Only `npm-proxy` gets its own subnet per host (`NPM_PROXY_NET_PREFIX`).
- **The central NPMplus reaches the apps directly** via their IP in this host's `npm-proxy`, routed through NetBird. The sync works exactly as on the central host (`NPM_NETWORK=npm-proxy`), and apps don't publish any ports.
- **Zero trust:** NetBird only routes the subnet to the central host (policy), and the firewall here only accepts the central host's NetBird IP. Apps can't reach each other, the internet or this host, the same as on the central host.

## Setup

### On the central host (once)

1. **NPMplus admin API via NetBird:** in `npmplus/docker-compose.yml`, enable the commented port `"${NETBIRD_IP}:81:81"` and set `NETBIRD_IP` (the central host's NetBird IP) in its `.env`. The remote syncs talk to NPMplus there.
2. **Uptime Kuma:** add the remote socket proxy to `KUMA_REMOTE_DOCKER_HOSTS`, e.g. `;tcp://100.64.0.2:2375` (see `uptime-kuma/.env.example`).
3. **Homepage:** add the remote host to `configs.app-docker` in `homepage/docker-compose.yml`:
   ```yaml
   vps1:
     host: 100.64.0.2
     port: 2375
   ```

### In NetBird (once per remote host)

1. Create a **Network** with the remote host as **routing peer** and the resource `172.30.1.0/24` (its `NPM_PROXY_NET_PREFIX`).
2. Add an **access policy**: only the central host's group may reach this resource.
3. Turn **Masquerade off** for the routing peer, so the firewall here sees the central host's NetBird IP as the source.
4. Policies between the two hosts: central → remote `2375/tcp` (socket proxy) and `45876/tcp` (Beszel); remote → central `81/tcp` (NPMplus API) and `443/tcp` (Dockhand WebSocket via its domain).

### On the remote host

1. Make sure NetBird starts **before** Docker (the ports are bound to the NetBird IP), e.g. `systemctl edit docker` → `[Unit] After=netbird.service`.
2. Copy this folder, copy `.env.example` to `.env`, fill in the required block and the blocks of your profiles.
3. In Dockhand, add the host as a Hawser (edge) environment, and in Beszel, add a system with `NETBIRD_IP` and port `45876`.
4. Deploy **by hand**: `docker compose up -d`. From then on, Dockhand manages the host through Hawser.
5. Deploy app stacks via Dockhand as usual. Their proxy hosts appear in the central NPMplus in the group `REMOTE_HOST_NAME`.

## Notes

- **Profiles:** `COMPOSE_PROFILES` in `.env` chooses the optional parts (`hawser`, `beszel`). `socket-proxy`, `firewall` and `npmplus-sync` always run: the sync is what makes the apps of this host reachable, and Compose only creates `npm-proxy` because the sync joins it.
- **Docker 28+:** `npm-proxy` uses `gateway_mode_ipv4: nat-unprotected`, which allows direct routing to the apps. Without it, Docker blocks routed access to unpublished ports. The firewall limits it to the central host.
- **Shared NPMplus:** the sync only touches its own proxy hosts (`SYNC_INSTANCE_ID`), never deletes orphans and never adopts hand-made hosts.
- **Socket proxy via NetBird:** AutoKuma and Homepage of the central host read the labels of this host through it. It's read-only, but `containers/<name>/json` also returns environment variables, the same as on the central host.
- **Secrets as files:** Hawser token, Beszel key/token and the NPMplus password reach the containers via `/run/secrets`.
- **Not tested yet:** the routed path (central NPMplus → NetBird → `npm-proxy` here) relies on Docker 28's `nat-unprotected` mode and NetBird's routing without masquerade. Check it on the first host: `curl http://<app container IP>:<port>` from the central host must answer, from any other host it must not.
- **Updates:** by hand, like Dockhand itself.
