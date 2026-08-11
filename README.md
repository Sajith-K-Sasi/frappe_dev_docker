# frappe_dev_docker

MariaDB + Redis for a Frappe bench that runs on the **host**, built on
[frappe_docker](https://github.com/frappe/frappe_docker)'s own devcontainer
compose file instead of a hand-maintained copy of it.

Upstream owns the service definitions — images, charset flags,
`MARIADB_AUTO_UPGRADE`. This repo adds only what upstream leaves out because its
services are meant to be reached from a sibling container rather than the host:
published ports, healthchecks, and queue persistence.

## Layout

| Path | Purpose |
| --- | --- |
| `setup.sh` | Clones/refreshes `frappe_docker/`, seeds its `.devcontainer/` |
| `docker-compose.override.yml` | Our overrides, merged on top of upstream |
| `services.sh` | `docker compose` wrapper that merges both files |
| `.env.example` | Ports and root password; `setup.sh` copies it to `.env` |
| `frappe_docker/` | Upstream clone (gitignored) |

## Quick start

```bash
./setup.sh
./services.sh up -d
./services.sh ps
```

| Service | Host address | Image (from upstream) |
| --- | --- | --- |
| MariaDB | `127.0.0.1:3306` | `mariadb:11.8` |
| Redis cache | `127.0.0.1:13000` | `redis:alpine` |
| Redis queue | `127.0.0.1:11000` | `redis:alpine` |

Ports bind to loopback only. Change them in `.env`.

## Bench setup

```bash
bench init --skip-redis-config-generation --frappe-branch version-16 frappe-bench
cd frappe-bench
```

`version-16` is the current stable line; `version-15` also works against
MariaDB 11.8 if you need it.

Point bench at the containers in `sites/common_site_config.json`:

```json
{
  "db_host": "127.0.0.1",
  "db_port": 3306,
  "redis_cache": "redis://127.0.0.1:13000",
  "redis_queue": "redis://127.0.0.1:11000",
  "redis_socketio": "redis://127.0.0.1:11000"
}
```

`redis_socketio` deliberately points at the **queue** instance. The key is
vestigial: it appears nowhere in `frappe/frappe` on any current branch, and the
realtime server subscribes to `redis_queue` (`realtime/index.js` →
`node_utils.js`, `get_redis_subscriber(kind = "redis_queue")`). bench still
writes the key out, so keep it aligned instead of standing up a third instance
for it. frappe_docker does the same thing in `compose.yaml`, commented
"add redis_socketio for backward compatibility".

Drop the redis lines bench wrote into the Procfile, since redis runs in Docker:

```bash
sed -i '' '/redis/d' ./Procfile   # macOS; use sed -i on Linux
```

Create a site:

```bash
bench new-site --db-root-password 123 --admin-password admin \
  --mariadb-user-host-login-scope=% development.localhost
```

`--mariadb-user-host-login-scope=%` matters here: connections arrive from the
Docker bridge rather than localhost, so the site's DB user must not be pinned to
a single host.

## Common commands

```bash
./services.sh up -d              # start
./services.sh ps                 # status + health
./services.sh logs -f mariadb    # follow logs
./services.sh stop               # stop, keep data
./services.sh down               # remove containers, keep data
./services.sh down -v            # remove containers AND data
```

```bash
# MariaDB shell (root password from .env)
docker exec -it frappe-dev-mariadb-1 mariadb -uroot -p123

# Backup / restore
docker exec frappe-dev-mariadb-1 mariadb-dump -uroot -p123 --all-databases > backup.sql
docker exec -i frappe-dev-mariadb-1 mariadb -uroot -p123 < backup.sql

# Flush caches
docker exec frappe-dev-redis-cache-1 redis-cli FLUSHALL
```

Prefer `bench backup` over `mariadb-dump` for real site backups — it captures
site files too.

## Staying current

```bash
./setup.sh          # re-pull frappe_docker, refresh .devcontainer/
./services.sh pull
./services.sh up -d
```

`setup.sh` overwrites `.devcontainer/` from upstream's `devcontainer-example/`
every run — put local changes in `docker-compose.override.yml`, never in
`.devcontainer/`. Image bumps land automatically because the override pins no
versions.

Upstream sets `MARIADB_AUTO_UPGRADE: 1`, so an existing data volume is upgraded
in place when MariaDB's major version moves. Take a `bench backup` before a
major bump anyway.

## Design notes

- **No `.cnf` file.** Upstream passes charset settings on the command line and
  tunes nothing else. The previous `mariadb-config/frappe.cnf` carried settings
  deprecated on MariaDB 11.x (`innodb_flush_method`, `innodb_file_per_table`)
  plus binary logging, which is write amplification with no replica to feed.
- **No `MYSQL_DATABASE` / `MYSQL_USER`.** bench creates a database and user per
  site; a pre-seeded pair goes unused.
- **No third Redis for socketio.** See the `redis_socketio` note above.
- **The upstream `frappe` dev container is gated** behind the `devcontainer`
  compose profile so it never starts. Bring it up with
  `./services.sh --profile devcontainer up -d frappe` if you ever want to run
  bench inside Docker instead.

## Migrating from the old compose file

The old stack ran under compose project `frappe_dev_docker`; this one uses
`frappe-dev`, so the old volumes are still on disk but unused:

```bash
docker volume ls | grep frappe_dev_docker
```

Restore sites into the new stack with `bench restore`, or drop the old volumes
once you no longer need them.
