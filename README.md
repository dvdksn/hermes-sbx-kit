# Hermes Agent kit for Docker Sandboxes

Personal Docker Sandboxes kit for
[Hermes Agent](https://github.com/NousResearch/hermes-agent).

It extends Docker's built-in `shell` kit so provider credentials follow the
same host-side proxy injection path as a plain shell sandbox. Hermes itself is
pre-installed in `docker.io/davidkarlsson416/hermes-agent-image:latest`, which
avoids reinstalling it whenever a sandbox is created.

> The published image currently contains only `linux/arm64`. Use the included
> GitHub Actions workflow to publish both ARM64 and AMD64 after configuring the
> required Docker Hub repository secrets.

## Configure provider credentials

Configure whichever providers you use on the host, supplying an **API key** for
each service:

```console
sbx secret set anthropic
sbx secret set openai
sbx secret set openrouter
```

Do not use the host-side OAuth credentials intended for agent-specific clients
such as Claude Code or Codex. Hermes is a separate multi-provider client; in
this setup, Anthropic and OpenAI inference works through the proxy when the
corresponding service contains an API key.

The real keys remain on the host. The sandbox receives sentinel values, and the
forward proxy substitutes the real authorization headers on outbound requests.

## Run with `sbx env`

The repository uses the upcoming unhidden `sbxenv.yaml` filename. From the
repository root:

```console
git clone https://github.com/dvdksn/hermes-sbx-kit.git
cd hermes-sbx-kit
sbx env run
```

The environment has the stable name `hermes-agent` and composes three kits:

- `./kits/hermes-agent` — the image-backed Hermes sandbox kit
- `docker.io/sbx/git-ssh-sign-kit:latest` — SSH commit signing
- `docker.io/sbx/github-ssh-kit:latest` — GitHub SSH clone/push support

It intentionally mounts no workspace. CPU and memory are omitted from the
environment so `sbx` uses its defaults.

Before starting, load the desired Git signing/authentication key into the host
SSH agent:

```console
ssh-add ~/.ssh/id_ed25519
ssh-add -L
```

You can still run the agent kit directly without the declarative environment:

```console
sbx run --kit ./kits/hermes-agent hermes-agent
```

Once Hermes starts, select a model with `hermes model` or connect through the
Hermes desktop app over SSH.

## Local state backups

The host-side scripts use Hermes's native backup and import commands. Hermes
creates a consistent snapshot using SQLite's online backup API; `sbx cp` moves
the ZIP outside the ephemeral sandbox.

```console
./scripts/backup                 # snapshot to protected host storage
./scripts/restore                # restore latest.zip
./scripts/restore /path/file.zip # restore a specific snapshot
./scripts/recreate               # backup → remove → create → restore → attach
```

Default backup locations:

- macOS: `~/Library/Application Support/hermes-sbx/backups/`
- Linux: `${XDG_STATE_HOME:-~/.local/state}/hermes-sbx/backups/`

Set `HERMES_BACKUP_DIR` to override the location. Directories are mode `0700`,
backup ZIPs are mode `0600`, and plaintext temporary copies inside the sandbox
are removed after transfer.

A full Hermes backup contains `.env`, `auth.json`, sessions, and other sensitive
state. Keep the backup directory outside Git and on an encrypted host disk.
These local backups survive `sbx env rm`, but not loss of the host itself; use
your normal host backup system for off-host disaster recovery.

## Why the launcher exists

The built-in `shell` parent contributes `-l` as its command tail. Kit
composition does not clear an inherited list when a child supplies an empty
list, so launching Hermes directly produces `hermes -l` and fails. The image's
`/usr/local/bin/hermes-start` launcher consumes that shell-only argument before
executing Hermes.

## Build and publish manually

Build and push for the current architecture:

```console
docker buildx build \
  --push \
  --tag docker.io/davidkarlsson416/hermes-agent-image:latest \
  ./kits/hermes-agent
```

To publish both supported architectures from a suitably provisioned builder:

```console
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push \
  --tag docker.io/davidkarlsson416/hermes-agent-image:latest \
  ./kits/hermes-agent
```

The full Hermes installation includes browser automation, computer-use, media,
and TUI dependencies, so the resulting image is large. A future slim variant
could pass installer flags such as `--skip-browser` and
`--skip-computer-use`, trading capabilities for a smaller pull.

## GitHub Actions publishing

The `Publish Hermes sandbox image` workflow is manual (`workflow_dispatch`).
Before running it, configure:

- Repository variable `DOCKERHUB_USERNAME`
- Repository secret `DOCKERHUB_TOKEN`

The workflow publishes `latest` and an immutable tag matching the Git commit
SHA for both AMD64 and ARM64.

## Remove provider credentials

```console
sbx secret rm anthropic
sbx secret rm openai
sbx secret rm openrouter
```
