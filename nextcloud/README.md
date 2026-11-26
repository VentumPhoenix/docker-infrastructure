# Nextcloud

Files, calendar and contacts, with online office (Collabora), a collaborative whiteboard, virus scanning (ClamAV) and SFTP access (rclone).

**Upstream:** [nextcloud/docker](https://github.com/nextcloud/docker) · [CollaboraOnline/online](https://github.com/CollaboraOnline/online) · [nextcloud/whiteboard](https://github.com/nextcloud/whiteboard) · [Cisco-Talos/clamav](https://github.com/Cisco-Talos/clamav) · [gera2ld/rclone-server](https://github.com/gera2ld/rclone-server)

| Service | Purpose |
|---|---|
| `app` | Nextcloud (Apache) |
| `cron` | background jobs, same image and volumes as `app` |
| `collabora` | online office, on its own domain |
| `whiteboard` | whiteboard server, on its own domain |
| `rclone-sftp` | SFTP access to the files, on a host port |
| `mariadb` | database |
| `redis` | cache and file locking |
| `clamav` | virus scanner for the Nextcloud app "Antivirus for files" |

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Create the credentials file for rclone at `RCLONE_AUTH_FILE` (default `/opt/rclone-sftp/auth.json`). Point its remotes to `http://app/remote.php/dav/…`, not to the public domain.
3. Deploy the stack via Dockhand and finish the installation wizard at `https://<APP_DOMAIN>`.
4. Nextcloud apps:
   - **Nextcloud Office:** Nextcloud and Collabora talk to each other internally, only the browser uses the public domain. Set it once in the console of `app`:
     ```bash
     php occ config:system:set trusted_domains 1 --value=app
     php occ config:app:set richdocuments wopi_url --value="http://collabora:9980"
     php occ config:app:set richdocuments public_wopi_url --value="https://<COLLABORA_DOMAIN>"
     php occ config:app:set richdocuments wopi_callback_url --value="http://app"
     php occ richdocuments:activate-config
     ```
   - **Whiteboard:** server URL = `https://<WHITEBOARD_DOMAIN>`, JWT secret = `WHITEBOARD_JWT_SECRET`.
   - **Antivirus for files:** mode "ClamAV daemon (socket)" → host `clamav`, port `3310`.

## Notes

- **Updates:** manual. Nextcloud can only skip one major version at a time, so `APP_VERSION` is raised step by step (e.g. 31 → 32 → 33).
- **Collabora (exception):** needs `MKNOD`, `SYS_ADMIN`, unconfined seccomp/AppArmor and file capabilities to build its document jails. That's why it runs without `no-new-privileges`.
- **SFTP (exception):** the only published port of this stack, because SFTP can't go through the reverse proxy. A published port doesn't work on an `internal` network, so `rclone-sftp` also joins `egress`.
- **Internal paths instead of the public domain:** Collabora and rclone reach Nextcloud via `http://app`, and Nextcloud reaches Collabora via `http://collabora:9980`. That's why Collabora needs no internet at all. Requests from these services use `app` as host name, so it is added to `trusted_domains`.
- **Whiteboard:** has no internet access. If the recording feature needs to load the board from Nextcloud, it may need `egress` (not tested).
- **No healthcheck for `app` yet:** `status.php` only answers for trusted domains, the right test is still to be determined.
