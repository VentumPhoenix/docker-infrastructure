# GitLab CE

Git hosting with merge requests, issues, wiki, CI/CD and container registry, all in one omnibus container.

**Upstream:** [gitlab-org/omnibus-gitlab](https://gitlab.com/gitlab-org/omnibus-gitlab) · [GitLab Docker docs](https://docs.gitlab.com/install/docker/)

## Setup

1. Copy `.env.example` to `.env` and fill in the required block. Pick `APP_VERSION` from the [image tags](https://hub.docker.com/r/gitlab/gitlab-ce/tags).
2. Open the SSH port (`GITLAB_SSH_PORT`, default 2222) in the host firewall.
3. Deploy the stack via Dockhand. The first start takes several minutes.
4. Log in at `https://<APP_DOMAIN>` as `root` with `GITLAB_ROOT_PASSWORD`. Disable open registration in the admin area if you don't want it.

## Notes

- **Configuration as a file:** the whole `gitlab.rb` part is defined inline (`configs:`) and loaded via `GITLAB_OMNIBUS_CONFIG: from_file(...)`. Passwords (SMTP, root) never appear as environment variables. Add more GitLab settings in `configs.app-config`.
- **Root password** comes from a Compose secret and is only used on the first start.
- **No single quotes** in the email values: they end up in Ruby strings.
- **SSH (exception):** git over SSH can't go through the reverse proxy, so its port is published. The clone URLs use `GITLAB_SSH_PORT`.
- **Resources:** GitLab is heavy. The official baseline is 16 GB RAM for the host, 8 GB at minimum. `mem_limit` is 8 GB, the bundled Prometheus is off to save memory.
- **Updates:** manual. GitLab must be upgraded along its [upgrade path](https://docs.gitlab.com/update/upgrade_paths/), stopping at every required version. Back up first.
- **Newer GitLab versions** move some nginx settings to `gitlab_rails['nginx'][...]`. If GitLab warns about the `nginx[...]` keys after an upgrade, move them accordingly.
