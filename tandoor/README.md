# Tandoor Recipes

Recipe manager with meal planning, shopping lists, nutrition data and recipe import from websites.

**Upstream:** [TandoorRecipes/recipes](https://github.com/TandoorRecipes/recipes)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand. The first start takes a while (migrations, static files).
3. Open `https://<APP_DOMAIN>` and create the first user, which becomes the admin.

## Notes

- **Bundled nginx:** since Tandoor 2, the container serves static and media files itself on port 80. No extra nginx is needed. `ALLAUTH_TRUSTED_PROXY_COUNT=2` accounts for that nginx plus NPMplus.
- **Secret key and database password** are passed as files (`SECRET_KEY_FILE`, `POSTGRES_PASSWORD_FILE`).
- **Registration closed** by default (`TANDOOR_ALLOW_SIGNUP=0`): new users are invited.
- **Healthcheck:** Django only answers for `ALLOWED_HOSTS`, so the check sends the public domain as `Host`.
- **Mealie or Tandoor?** Both are recipe managers. Run the one you prefer, they don't depend on each other.
- **Updates:** manual, because updates run database migrations.
