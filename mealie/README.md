# Mealie

Recipe manager: imports recipes from any website, plans meals and builds shopping lists, shared with your household.

**Upstream:** [mealie-recipes/mealie](https://github.com/mealie-recipes/mealie)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block.
2. Deploy the stack via Dockhand.
3. Log in at `https://<APP_DOMAIN>` with Mealie's default admin account (see the Mealie docs) and **change its email and password right away**.
4. Invite the other members of your household from the admin settings.

## Notes

- **Registration closed** by default (`MEALIE_ALLOW_SIGNUP=false`): new users are invited.
- **Database password** is passed as a file (`POSTGRES_PASSWORD_FILE`), Mealie reads it itself.
- **Internet:** recipe import fetches the recipe's website, so `app` needs `egress`.
- **Login via Authentik (optional):** Mealie supports OIDC (`OIDC_*` variables, see the Mealie docs). It's not configured here, because Mealie has its own login.
- **Updates:** manual, because updates run database migrations.
