# Vaultwarden

Lightweight server for Bitwarden clients (browser extension, desktop, mobile apps): passwords, passkeys, 2FA codes and secure notes, shared with family or team via organizations.

**Upstream:** [dani-garcia/vaultwarden](https://github.com/dani-garcia/vaultwarden)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block. Set the email block too, otherwise invitations don't work.
2. Deploy the stack via Dockhand.
3. Create your account at `https://<APP_DOMAIN>`.
4. Point the Bitwarden apps to `https://<APP_DOMAIN>` (self-hosted server).

## Notes

- **Registration** is open by default: anyone who can reach the domain can create an account. Their vault is end-to-end encrypted and invisible to others, but they use your server. To narrow it down:
  - `VAULTWARDEN_SIGNUPS_DOMAINS`: only these email domains may register.
  - `VAULTWARDEN_SIGNUPS_VERIFY=true`: the email address must be confirmed before the first login (needs the email settings).
  - `VAULTWARDEN_SIGNUPS_ALLOWED=false`: closed, new users only by invitation (organization or admin page).
- **Admin page:** disabled as long as `VAULTWARDEN_ADMIN_TOKEN` is empty. If you enable it, use an Argon2 hash (`/vaultwarden hash`) and keep the single quotes in `.env`, because the hash contains `$`.
- **Port 8080 inside the container:** Vaultwarden listens on 8080 instead of 80, so it runs with all capabilities dropped. NPMplus forwards to 8080.
- **WebSockets** (live sync between clients) run on the normal port. The old `WEBSOCKET_ENABLED` setting isn't needed anymore.
- **Backups:** the vault lives in a SQLite database in the volume `app-data` (`db.sqlite3`). Back it up consistently, e.g. with `sqlite3 db.sqlite3 ".backup backup.sqlite3"` in a UrBackup pre-backup script, together with the `attachments`, `sends` and `rsa_key*` files.
- **Updates:** auto. A single container without dependencies, it runs its small database migrations itself, and security fixes for a password manager should arrive quickly. The safety net is the backup above plus the Uptime Kuma monitor, which reports a failed update.
