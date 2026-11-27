# Website

Template for a website with a headless CMS: the site itself (e.g. Astro with server-side rendering) reads its content from Directus, editors work in Directus' admin UI. With the `pretix` variant, bookings, tickets and a shop are added.

**Upstream:** [directus/directus](https://github.com/directus/directus) · [pretix/pretix](https://github.com/pretix/pretix) · [withastro/astro](https://github.com/withastro/astro)

| Service | Purpose |
|---|---|
| `app` | the website (your image, port 4321) |
| `directus` | headless CMS at `DIRECTUS_DOMAIN` |
| `directus-postgres`, `directus-redis` | database and cache of Directus |
| `pretix` | *(variant pretix)* bookings and shop at `PRETIX_DOMAIN` |
| `pretix-cron` | *(variant pretix)* periodic tasks every 2 minutes |
| `pretix-postgres`, `pretix-redis` | *(variant pretix)* database, sessions and task queue |

## Variants

| File | Adds |
|---|---|
| `docker-compose.yml` | base: website + Directus |
| `docker-compose.pretix.yml` | pretix for bookings, tickets and a shop |

## Setup

1. Build an image of your website (e.g. with a GitHub Action to `ghcr.io`) and set it as `WEB_IMAGE`. It should listen on port 4321 and read the CMS from `DIRECTUS_URL`.
2. Copy `.env.example` to `.env` and fill in the required block (plus the `pretix` block for the variant).
3. Deploy the stack via Dockhand.
4. Log in to Directus at `https://<DIRECTUS_DOMAIN>` with `DIRECTUS_ADMIN_EMAIL` / `DIRECTUS_ADMIN_PASSWORD`, and create the content model.
5. Variant pretix: log in at `https://<PRETIX_DOMAIN>/control/` as `admin@localhost` / `admin` and **change the password right away**.

## Notes

- **One template, one site:** copy the folder once per website (e.g. `website-club`), then the containers, volumes and proxy hosts get their own names.
- **Image instead of `build:`:** Dockhand deploys images, so the website is built elsewhere. For a local build, replace `image: ${WEB_IMAGE}` with `build: ./web`.
- **CMS internally:** the website reads Directus via `http://directus:8055` over `internal`, never via the public domain. Directus only allows CORS requests from the website's domain.
- **Secrets as files:** Directus reads `SECRET_FILE`, `ADMIN_PASSWORD_FILE` and `DB_PASSWORD_FILE`; pretix reads the database password via its `FILE__` prefix.
- **No Docker socket for pretix:** the periodic `pretix cron` runs in `pretix-cron`, a second container with the same image, instead of being triggered through the Docker socket (e.g. with Ofelia). It writes a timestamp after every run, and its healthcheck checks that the last run is less than 10 minutes ago.
- **No internet for the CMS:** Directus and the website have no `egress`. Add it if you use Directus flows or webhooks that call external services.
- **Updates:** manual, because Directus and pretix run database migrations.
