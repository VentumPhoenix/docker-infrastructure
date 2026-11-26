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
2. Create the credentials file for rclone at `RCLONE_AUTH_FILE` (default `/opt/rclone-sftp/auth.json`).
3. Deploy the stack via Dockhand and finish the installation wizard at `https://<APP_DOMAIN>`.
4. Nextcloud apps:
   - **Nextcloud Office:** URL of the Collabora server = `https://<COLLABORA_DOMAIN>`.
   - **Whiteboard:** server URL = `https://<WHITEBOARD_DOMAIN>`, JWT secret = `WHITEBOARD_JWT_SECRET`.
   - **Antivirus for files:** mode "ClamAV daemon (socket)" → host `clamav`, port `3310`.

## Notes

- **Updates:** manual. Nextcloud can only skip one major version at a time, so `APP_VERSION` is raised step by step (e.g. 31 → 32 → 33).
- **Collabora (exception):** needs `MKNOD`, `SYS_ADMIN`, unconfined seccomp/AppArmor and file capabilities to build its document jails. That's why it runs without `no-new-privileges`.
- **SFTP (exception):** the only published port of this stack, because SFTP can't go through the reverse proxy.
- **No healthcheck for `app` yet:** `status.php` only answers for trusted domains, the right test is still to be determined.
