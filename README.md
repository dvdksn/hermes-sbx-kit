# Hermes Agent kit for Docker Sandboxes

Personal Docker Sandboxes kit for
[Hermes Agent](https://github.com/NousResearch/hermes-agent).

It is a standalone schema v2 sandbox kit rather than an extension of Docker's
built-in `shell` kit. The kit declares only the credentials and network access
Hermes needs here: direct Anthropic and OpenAI inference plus GitHub API access.
Hermes itself is pre-installed in
`docker.io/davidkarlsson416/hermes-agent-image:latest`, which avoids reinstalling
it whenever a sandbox is created.

> The published image currently contains only `linux/arm64`. Use the included
> GitHub Actions workflow to publish both ARM64 and AMD64 after configuring the
> required Docker Hub repository secrets.

## Configure provider credentials

The checked-in `sbxenv.yaml` resolves all three credentials from the host:

- Anthropic and OpenAI API keys come from the configured 1Password references.
- GitHub comes from `gh auth token`; SSH clone, push, and commit signing still
  use the two SSH mixin kits and your forwarded host SSH agent.

If you run the agent kit directly instead of through `sbx env`, store the same
service credentials first:

```console
sbx secret set anthropic
sbx secret set openai
sbx secret set github --command 'gh auth token'
```

Do not use the host-side OAuth credentials intended for agent-specific clients
such as Claude Code or Codex. Hermes is a separate multi-provider client; in
this setup, Anthropic and OpenAI inference works through the proxy when the
corresponding service contains an API key.

The real keys remain on the host. The sandbox receives sentinel values, and the
forward proxy substitutes the real authorization headers only for the domains
declared by the kit. The environment file also declares the required schema v2
credential bindings, so non-interactive `sbx env create` does not depend on a
first-run approval prompt.

The GitHub token appears inside the sandbox as `GITHUB_TOKEN`, which Hermes can
otherwise interpret as a GitHub Copilot credential. The injected Hermes config
explicitly hides `copilot` and `copilot-acp` from every model picker while
leaving `gh` and GitHub API access available.

## Create for Hermes Desktop

The primary workflow is to provision the environment without attaching a
terminal session:

```console
git clone https://github.com/dvdksn/hermes-sbx-kit.git
cd hermes-sbx-kit
./scripts/create
```

The wrapper creates the mountless environment, seeds a persistent Hermes home
on the host when necessary, and attaches it to `/home/agent/.hermes` with:

```console
sbx mount hermes-agent HOST_PATH:/home/agent/.hermes:rw
```

It sets the host-side `DOCKER_SANDBOXES_ROOT_SIZE=50GB` creation variable,
increasing the sandbox root filesystem from the 20 GB default. Override it for
one creation by exporting a different value before running the wrapper.

The operation is idempotent. Sandbox removal detaches the mount but does not
delete the host directory. To recreate, explicitly remove the environment and
run the same create wrapper again:

```console
sbx env rm sbxenv.yaml --force
./scripts/create
```

Ordinary Desktop wake/sleep cycles require no wrapper or restore step after the
initial bootstrap.

Then open the Hermes desktop app and connect to:

```text
hermes-agent.sbx
```

The desktop app connects over SSH and wakes the sandbox when necessary. After
the initial connection, normal interaction happens through Desktop rather than
an attached terminal UI.

The environment composes three kits:

- `./kits/hermes-agent` — the image-backed Hermes sandbox kit
- `docker.io/sbx/git-ssh-sign-kit:latest` — SSH commit signing
- `docker.io/sbx/github-ssh-kit:latest` — GitHub SSH clone/push support

It intentionally mounts no workspace. CPU and memory are omitted from the
environment so `sbx` uses its defaults.

This relies on the unreleased mountless `sbx env` behavior. Released versions
whose environment schema still defaults an omitted `workspace` to the
environment-file directory will mount this repository instead.

Before creating the environment, load the desired Git signing/authentication
key into the host SSH agent:

```console
ssh-add ~/.ssh/id_ed25519
ssh-add -L
```

For optional terminal interaction, attach with:

```console
sbx env run sbxenv.yaml
```

You can also run the agent kit directly without the declarative environment:

```console
sbx run --kit ./kits/hermes-agent hermes-agent
```

Direct kit runs use the injected config but do not receive the host persistence
mount or the environment-file credential sources and bindings.

## Persistent Hermes state

The complete Hermes home is mounted, including config, memories, skills, cron
jobs, plugins, sessions, and the SQLite state database. Defaults:

- macOS and Linux: `${XDG_STATE_HOME:-$HOME/.local/state}/hermes-sbx/home/`

Set `HERMES_PERSIST_DIR` to override the location. The directory is created with
mode `0700`; secret-bearing files created by Hermes retain their own restrictive
permissions. Keep this directory outside Git and on an encrypted host disk.

The image installs Hermes code and its virtual environment separately under
`/home/agent/.local/share/hermes-agent`. This is intentional: installing under
`HERMES_HOME` would cause the state mount to hide the Hermes executable.

The environment sets `HERMES_WAIT_FOR_HOME_MOUNT=1`. On a newly created
sandbox, the entrypoint waits for a marker from `./scripts/create` before Hermes
opens its config or database, avoiding writes to the image-backed directory
during the brief create-to-mount interval.

The mounted directory is a deliberate writable host boundary. Hermes and code
it executes can persist changes to its config, skills, plugins, and cron jobs.
Proxy-managed Anthropic, OpenAI, and GitHub credentials remain on the host, but
OAuth credentials created inside Hermes would be stored in the mounted
`auth.json`.

## Backups

The mount is the normal persistence mechanism, so sandbox lifecycle scripts do
not create or restore backups. Protect the host persistence directory with Time
Machine or your normal host backup system.

For a consistent point-in-time archive while Hermes is running, invoke Hermes's
native SQLite-aware backup directly and write it through the mount:

```console
sbx env exec sbxenv.yaml -- \
  hermes backup -o /home/agent/.hermes/backups/hermes-backup.zip
```

Use `hermes import --force ZIPFILE` inside the sandbox when an explicit recovery
is needed. Backup archives can contain sensitive configuration and OAuth state;
keep them outside Git and on encrypted storage.

## Injected Hermes configuration

The kit statically injects
`kits/hermes-agent/files/home/.hermes/config.yaml` as
`/home/agent/.hermes/config.yaml` for direct kit runs. `./scripts/create` copies
the same file into a new persistent host directory only when `config.yaml` is
missing. It deliberately contains no secrets and only sets sandbox-specific
defaults:

- leave the model unconfigured so `hermes model` can choose Anthropic or OpenAI;
- use SQLite `DELETE` journaling, which is safer than WAL on virtiofs mounts;
- hide Copilot providers that would otherwise be inferred from `GITHUB_TOKEN`;
- run terminal tools locally inside the sandbox from `/home/agent`; and
- keep subprocess `HOME` at `/home/agent`, where SSH and Git configuration live.

Once seeded, the mounted config is user state and is not overwritten by kit
updates or recreation. Change live settings with `hermes config set`; a later
restore may replace the file with its backed-up version.

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
sbx secret rm github
```
