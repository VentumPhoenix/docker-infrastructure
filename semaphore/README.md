# Semaphore UI

Web UI for Ansible (and Terraform/OpenTofu, shell scripts): run playbooks with a click, schedule them, and keep a history of every run.

**Upstream:** [semaphoreui/semaphore](https://github.com/semaphoreui/semaphore)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand.
3. Log in at `https://<APP_DOMAIN>` with `SEMAPHORE_ADMIN_USER` / `SEMAPHORE_ADMIN_PASSWORD`.
4. Add a project with its repository, inventory and keys.

## Notes

- **Plain environment variables:** Semaphore can't read secrets from files, so the database password, the first admin password and the encryption key are environment variables (CONVENTIONS § 8 fallback). The admin password is only used on the first start; change it in the UI afterwards.
- **Encryption key:** `SEMAPHORE_ACCESS_KEY_ENCRYPTION` encrypts the stored SSH keys and passwords. If it changes, they can't be decrypted anymore.
- **Internet / LAN:** Semaphore connects to the hosts you manage and clones repositories, so `app` needs `egress`.
- **Variable names:** the database variables (`SEMAPHORE_DB_*`) follow Semaphore's Docker example. If Semaphore doesn't connect to Postgres, compare them with the current Semaphore docs.
- **Login via Authentik (optional):** Semaphore supports OIDC, configured in its `config.json` (volume `app-config`), see the Semaphore docs.
- **Updates:** manual, because updates run database migrations.
