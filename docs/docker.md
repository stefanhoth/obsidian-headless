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
mkdir ob-vault
```

On **Linux**, set the ownership to uid/gid 2500 so the container can write to it:

```bash
sudo chown 2500:2500 ob-vault
```

> [!NOTE]
> All `docker compose` commands are run by your regular login user (who must have Docker access). The container executes internally as uid 2500 — no system user with that uid needs to exist on the host.

## First-time login

Login interactively. This stores your credentials in a named Docker volume (`ob-config`) that is separate from your vault:

```bash
docker compose run --rm ob login
```

## Vault setup

Configure which remote vault to sync into `ob-vault/`:

```bash
docker compose run --rm ob sync-setup --vault "My Vault"
```

For end-to-end encrypted vaults, provide the encryption password:

```bash
# Interactive prompt (recommended)
docker compose run --rm ob sync-setup --vault "My Vault"

# Non-interactive (e.g. in a setup script)
docker compose run --rm ob sync-setup --vault "My Vault" --password "your-e2ee-password"
```

> [!NOTE]
> The password is stored in `ob-config` after setup and does not need to be provided again. The `sync` service restarts automatically without any interactive prompt.

## Syncing

Run a one-time sync:

```bash
docker compose run --rm ob sync
```

### Continuous sync with automatic restart

`docker-compose.yml` includes a dedicated `sync` service configured with `restart: unless-stopped`. This means Docker automatically restarts it if the process crashes or the host reboots — no manual intervention needed.

Start it in the background:

```bash
docker compose up -d sync
```

Check its status and logs:

```bash
docker compose ps sync
docker compose logs -f sync
```

Stop it:

```bash
docker compose stop sync
```

> [!TIP]
> The `restart: unless-stopped` policy means the service will **not** restart if you explicitly stop it with `docker compose stop`. It only restarts on unexpected exits or system reboots.

## Volume layout

| Mount | Container path | Purpose |
|---|---|---|
| `./ob-vault` | `/vault` | Your vault files (notes, attachments) |
| `ob-config` (named volume) | `/config` | CLI credentials and config |

The two mounts are intentionally kept separate — see the [Security considerations](#security-considerations) section below.

## Security considerations

### Why credentials are stored outside the vault

The `ob-config` volume (mounted at `/config`, which serves as `$HOME` inside the container) holds your Obsidian account credentials. This is deliberately separate from `./ob-vault`.

If you mount `./ob-vault` for another tool — a local AI agent, a backup script, a second device — it will only see your vault files. Your login credentials stay in the Docker-managed volume and are never written into the vault directory.

### Sharing `ob-vault` with AI agents

Mounting `./ob-vault` for a local agent (e.g. to let it read or edit your notes) is safe from a credentials perspective. However, consider the following:

- **`.obsidian/` contains sync state.** The sync database and settings live in `./ob-vault/.obsidian/`. An agent that modifies or deletes files in that subdirectory can disrupt syncing. Grant agents read-only access to `./ob-vault` where possible, or explicitly exclude `.obsidian/` from any agent working directory.
- **File deletions are synced.** If an agent deletes files, those deletions will be propagated to your remote vault on the next sync. Consider using `--mode pull-only` (`ob sync-config --mode pull-only`) when running alongside agents that write to the vault, so the container only downloads and never uploads local changes.
- **Principle of least privilege.** If the agent only needs to read your notes, mount `./ob-vault` as read-only: add `:ro` to the volume in `docker-compose.yml` for the agent's service.

### Running as non-root

The container runs as a dedicated `ob` user (uid/gid **2500**) rather than root. The value 2500 is chosen to avoid collisions with common system users and default uids used by tools such as coding agents, which tend to use round numbers like 1000 or 2000.

Additional hardening applied to both services:
- `read_only: true` — root filesystem is immutable; all writes go to the mounted volumes or `/tmp`
- `no-new-privileges` — the process cannot gain additional privileges via setuid/setgid
- `cap_drop: ALL` — all Linux capabilities are dropped; the CLI does not need any

On **macOS and Windows** with Docker Desktop, bind mounts handle uid mapping automatically — no extra steps needed.

On **Linux**, the `./ob-vault` directory on the host must be readable and writable by uid 2500:

```bash
sudo chown -R 2500:2500 ./ob-vault
```

The `ob-config` named volume is initialized with the correct ownership automatically on first run.

#### Changing the uid/gid

If 2500 clashes with an existing user on your system, change it in **three places**:

1. **`Dockerfile`** — the `groupadd`/`useradd` line:
   ```dockerfile
   RUN groupadd -g 2500 ob && useradd -u 2500 -g ob ...
   ```

2. **`docker-compose.yml`** — the `user:` field on both the `ob` and `sync` services:
   ```yaml
   user: "2500:2500"
   ```

3. **Host directory** (Linux only) — re-chown `./ob-vault` after changing:
   ```bash
   sudo chown -R <new-uid>:<new-gid> ./ob-vault
   ```

> [!IMPORTANT]
> All three must use the same uid/gid, otherwise the container will fail to read or write its volumes.

### Separate users for `ob` and `sync` (advanced)

Both services currently run as the same `ob` user. A stricter setup would use a dedicated read-only user for the `sync` service so it can read credentials from `ob-config` but cannot modify them (e.g. cannot write new login tokens).

The tradeoff: syncing requires write access to `ob-vault` regardless, so this only isolates credential writes — not vault writes. For most setups the single non-root user is sufficient.

### Resetting credentials

To log out and clear stored credentials:

```bash
docker compose run --rm ob logout
docker compose down -v
```

> [!NOTE]
> `docker compose down -v` removes all volumes for this project, including `ob-config`. The volume name is prefixed with the Docker Compose project name (by default: the directory name), so it varies between setups — `docker compose down -v` always works regardless.
