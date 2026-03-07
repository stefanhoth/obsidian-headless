# Docker Setup

Run `obsidian-headless` in a container without installing Node.js or any dependencies on your host system.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Compose

## Setup

Clone the repository and build the image:

```bash
git clone https://github.com/obsidianmd/obsidian-headless
cd obsidian-headless
docker compose build
```

Create the directory that will hold your vault data:

```bash
mkdir datadir
```

## First-time login

Login interactively. This stores your credentials in a named Docker volume (`ob-config`) that is separate from your vault:

```bash
docker compose run --rm ob login
```

## Vault setup

Configure which remote vault to sync into `datadir/`:

```bash
docker compose run --rm ob sync-setup --vault "My Vault"
```

## Syncing

Run a one-time sync:

```bash
docker compose run --rm ob sync
```

Run continuously (watches for changes):

```bash
docker compose run --rm ob sync --continuous
```

## Volume layout

| Mount | Container path | Purpose |
|---|---|---|
| `./datadir` | `/vault` | Your vault files (notes, attachments) |
| `ob-config` (named volume) | `/config` | CLI credentials and config |

The two mounts are intentionally kept separate — see the [Security considerations](#security-considerations) section below.

## Security considerations

### Why credentials are stored outside the vault

The `ob-config` volume (mounted at `/config`, which serves as `$HOME` inside the container) holds your Obsidian account credentials. This is deliberately separate from `./datadir`.

If you mount `./datadir` for another tool — a local AI agent, a backup script, a second device — it will only see your vault files. Your login credentials stay in the Docker-managed volume and are never written into the vault directory.

### Sharing `datadir` with AI agents

Mounting `./datadir` for a local agent (e.g. to let it read or edit your notes) is safe from a credentials perspective. However, consider the following:

- **`.obsidian/` contains sync state.** The sync database and settings live in `./datadir/.obsidian/`. An agent that modifies or deletes files in that subdirectory can disrupt syncing. Grant agents read-only access to `./datadir` where possible, or explicitly exclude `.obsidian/` from any agent working directory.
- **File deletions are synced.** If an agent deletes files, those deletions will be propagated to your remote vault on the next sync. Consider using `--mode pull-only` (`ob sync-config --mode pull-only`) when running alongside agents that write to the vault, so the container only downloads and never uploads local changes.
- **Principle of least privilege.** If the agent only needs to read your notes, mount `./datadir` as read-only: add `:ro` to the volume in `docker-compose.yml` for the agent's service.

### Resetting credentials

To log out and clear stored credentials:

```bash
docker compose run --rm ob logout
docker volume rm obsidian-headless_ob-config
```
