# Paperless-ngx

Document management: scanned or uploaded documents are OCR'd, tagged automatically and become full-text searchable.

**Upstream:** [paperless-ngx/paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) · [gotenberg/gotenberg](https://github.com/gotenberg/gotenberg) · [apache/tika-docker](https://github.com/apache/tika-docker)

| Service | Purpose |
|---|---|
| `app` | Paperless-ngx (web UI, OCR, background tasks) |
| `postgres` | database |
| `redis` | task queue |
| `gotenberg` | *(variant tika)* converts Office documents and emails to PDF |
| `tika` | *(variant tika)* extracts text from Office documents |

## Variants

| File | Adds |
|---|---|
| `docker-compose.yml` | base (PDFs and images) |
| `docker-compose.tika.yml` | Office documents (Word, Excel, …) and emails via Tika + Gotenberg |

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand.
3. Create the admin account in the console of `app` (Dockhand console or `docker compose exec app`):
   ```bash
   python3 manage.py createsuperuser
   ```
4. Log in at `https://<APP_DOMAIN>`.

## Notes

- **Scanner share:** new documents are picked up from the consume folder. By default, that's the Docker volume `app-consume`. For a scanner or SMB share, set `PAPERLESS_CONSUME_DIR` to a host path. The files there should belong to `PUID`/`PGID`.
- **OCR languages:** German, English, French, Italian and Spanish are included in the image. Other languages are downloaded at every start (`PAPERLESS_OCR_LANGUAGES`, needs internet), so they're deliberately not configured here.
- **Gotenberg without internet:** it only sits in `internal`, JavaScript is off and only local files are allowed. A document can't make it load anything from outside.
- **Login via Authentik (optional):** Paperless supports OIDC via django-allauth. It has its own login, so Authentik isn't required.
- **Postgres 18:** the volume is mounted at `/var/lib/postgresql` (new layout of version 18), unlike the other stacks that still run 16.
- **Updates:** manual, because updates run database migrations. Switch off auto-update for this stack in Dockhand and read the release notes before a major version jump.
