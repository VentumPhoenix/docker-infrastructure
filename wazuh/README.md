# Wazuh

Security monitoring (SIEM/XDR) for your hosts: agents report logs, file changes, vulnerabilities and configuration problems, the dashboard shows alerts and compliance.

**Upstream:** [wazuh/wazuh-docker](https://github.com/wazuh/wazuh-docker) · [Wazuh Docker docs](https://documentation.wazuh.com/current/deployment-options/docker/wazuh-container.html)

| Service | Purpose |
|---|---|
| `app` | dashboard (web UI) |
| `manager` | receives agent data, analysis, API |
| `indexer` | stores events and alerts (OpenSearch) |
| `certs` | one-shot job (`--profile setup`), generates the certificates |

## Setup

This stack **can't be deployed through Dockhand as a single file**: Wazuh needs its certificates and several config files from the upstream repository. Do steps 1–4 by hand on the host, after that Dockhand can deploy and restart it.

1. Host setting, needed by the indexer:
   ```bash
   echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-wazuh-max-map-count.conf
   sudo sysctl --system
   ```
2. Get the config folder of the same version as `APP_VERSION`:
   ```bash
   git clone https://github.com/wazuh/wazuh-docker.git -b v4.14.11 /tmp/wazuh-docker
   sudo cp -r /tmp/wazuh-docker/single-node/config /opt/stacks/wazuh/config
   ```
3. Copy `.env.example` to `.env`. Set the three passwords to the upstream defaults for now (`SecretPassword`, `kibanaserver`, `MyS3cr37P450r.*-`).
4. Generate the certificates: `docker compose --profile setup run --rm certs`.
5. Deploy the stack (via Dockhand or `docker compose up -d`) and open `https://<APP_DOMAIN>`.
6. **Change all three passwords right away**, see below.
7. Open the agent ports `1514/tcp` and `1515/tcp` in the host firewall for your hosts, and install agents pointing to this host.

### Changing the passwords

The passwords exist twice: as hashes or values in the config folder, and in `.env`. Both must match.

1. `docker compose down`
2. Create a hash: `docker run --rm -ti wazuh/wazuh-indexer:<APP_VERSION> bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh`
3. Put it as `hash:` of the user (`admin`, `kibanaserver`) into `wazuh_indexer/internal_users.yml`, and the new plain password into `.env`.
4. For the API user, put the new password into `wazuh_dashboard/wazuh.yml` and `WAZUH_API_PASSWORD`.
5. `docker compose up -d`, then apply the indexer users with `securityadmin.sh` inside the indexer container, as described in the [Wazuh docs](https://documentation.wazuh.com/current/deployment-options/docker/wazuh-container.html).

## Notes

- **Config folder (exception):** certificates, `opensearch.yml`, `internal_users.yml`, `opensearch_dashboards.yml`, `wazuh.yml` and `ossec.conf` are bind-mounted from `WAZUH_CONFIG_DIR`. Inline configs aren't possible here: the certificates are generated, and the user hashes change with every password change.
- **Names:** the services are called `app`, `manager` and `indexer`, but also answer to `wazuh.dashboard`, `wazuh.manager` and `wazuh.indexer` in `internal`, because the certificates and config files use those names.
- **Only the agent ports are published.** The API (55000) and the indexer (9200) stay in `internal`, only the dashboard reaches them.
- **Passwords as environment variables:** the Wazuh images only read them from the environment (CONVENTIONS § 8 fallback).
- **Dashboard over HTTPS:** it serves HTTPS with its own certificate, so NPMplus forwards with `scheme: https`.
- **Healthchecks** use `curl` and `wazuh-control`. They follow the newer upstream compose, but haven't been tested against 4.14.11.
- **Resources:** plan at least 4–6 GB RAM for the whole stack. The indexer heap is set with `WAZUH_INDEXER_HEAP`.
- **Updates:** manual. All three images and the config folder must be on the same version.
