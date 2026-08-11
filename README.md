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

## Installing bench on the host

Instructions are for macOS on Apple Silicon. No MariaDB or Redis **server** is
needed on the host — that is what this repo's containers are for.

### Prerequisites

| Requirement | Frappe v16 needs | Check with |
| --- | --- | --- |
| Python | `>=3.14,<3.15` | `python3 --version` |
| Node | `>=24` | `node --version` |
| yarn | any | `yarn --version` |
| MySQL client libs + pkg-config | to build `mysqlclient` | `pkg-config --modversion mysqlclient` |

```bash
brew install mysql-client pkg-config yarn
echo 'export PKG_CONFIG_PATH="$(brew --prefix)/opt/mysql-client/lib/pkgconfig"' >> ~/.zshrc
source ~/.zshrc
```

The `PKG_CONFIG_PATH` export is not optional. Frappe pins `mysqlclient`, a C
extension, and without it `bench init` fails at compile time — the most common
macOS install failure. This is the documented recipe from
[mysqlclient's README](https://github.com/PyMySQL/mysqlclient).

`mysql-client` is keg-only. To also get a `mariadb`/`mysql` CLI on `PATH` for
poking at the container by hand:

```bash
echo 'export PATH="$(brew --prefix)/opt/mysql-client/bin:$PATH"' >> ~/.zshrc
```

If you use nvm alongside Homebrew node, make sure the shell that runs `bench`
resolves to Node 24 — asset builds otherwise pick up whatever nvm last selected.

### 1. Install bench

```bash
uv tool install frappe-bench     # or: pipx install frappe-bench
uv tool update-shell             # puts the tool bin dir on PATH
bench --version
```

### 2. Initialize the bench

```bash
bench init --skip-redis-config-generation \
           --frappe-branch version-16 \
           --python "$(brew --prefix python@3.14)/bin/python3.14" \
           frappe-bench
cd frappe-bench
```

Pass `--python` explicitly — it defaults to bare `python3`, and v16 pins
`>=3.14,<3.15`, so a stray 3.13 or 3.15 on `PATH` fails the install. Add `--dev`
for developer mode and dev dependencies. `version-16` is the current stable
line; `version-15` also works against MariaDB 11.8 if you need it.

### 3. Point bench at the containers

```bash
bench set-config -g  db_host 127.0.0.1
bench set-config -gp db_port 3306
bench set-config -g  redis_cache    redis://127.0.0.1:13000
bench set-config -g  redis_queue    redis://127.0.0.1:11000
bench set-config -g  redis_socketio redis://127.0.0.1:11000
```

`-gp` writes `db_port` as a number rather than a string. Equivalent
`sites/common_site_config.json`:

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

### 4. Set up Chromium for PDFs

```bash
bench setup-chrome
```

v16 dropped wkhtmltopdf. `find_or_download_chromium_executable`
(`frappe/utils/print_utils.py`) downloads Chromium into `<bench>/chromium` when
it is not already on `PATH`. Worth knowing if you are weighing v15: wkhtmltopdf
is no longer in homebrew/core at all, so PDF generation there is a real chore.

### 5. Create a site

```bash
bench new-site --db-root-password 123 --admin-password admin \
  --mariadb-user-host-login-scope=% development.localhost
bench --site development.localhost set-config developer_mode 1
echo "127.0.0.1 development.localhost" | sudo tee -a /etc/hosts
bench start
```

`--mariadb-user-host-login-scope=%` matters here: connections arrive from the
Docker bridge rather than localhost, so the site's DB user must not be pinned to
a single host.

The site is then at http://development.localhost:8000 — `Administrator` /
`admin`. Start the containers first if they are not already up
(`./services.sh up -d`).

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
