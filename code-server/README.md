# code-server

VS Code in the browser: edit code, use the terminal and extensions from anywhere.

**Upstream:** [coder/code-server](https://github.com/coder/code-server)

## Setup

1. Create the Argon2 hash of your password: `echo -n 'your-password' | npx argon2-cli -e`.
2. Copy `.env.example` to `.env`, fill in the required block, and keep the **single quotes** around the hash.
3. Make sure NPMplus runs with the `authentik` variant (see below).
4. Deploy the stack via Dockhand.

## Notes

- **Two logins on purpose:** the terminal in code-server is a shell on the server. That's why Authentik sits in front (`npm.proxy.auth_request: "authentik"`) and code-server keeps its own password.
- **Hash in single quotes:** the Argon2 hash contains `$`. Without single quotes in `.env`, Compose reads the parts after `$` as variables.
- **No sudo:** the image allows passwordless `sudo`, but `no-new-privileges` blocks it. Install tools in your home folder or build your own image.
- **Your files:** `/home/coder` (settings, extensions) is the volume `app-home`. The project folder is the volume `app-workspace`, or a host folder via `CODE_SERVER_WORKSPACE`, which must belong to UID 1000.
- **Original image** (`codercom/code-server`) instead of the linuxserver image: it runs as a fixed non-root user and has its login on by default.
