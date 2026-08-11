#!/usr/bin/env bash
# Clone or refresh frappe_docker, then seed its .devcontainer from the
# upstream example. Safe to re-run -- it is how you pick up upstream changes.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_DIR="$REPO_DIR/frappe_docker"
DC_DIR="$UPSTREAM_DIR/.devcontainer"
UPSTREAM_URL="https://github.com/frappe/frappe_docker.git"

if [ -d "$UPSTREAM_DIR/.git" ]; then
	echo "==> Updating frappe_docker"
	git -C "$UPSTREAM_DIR" pull --ff-only
else
	echo "==> Cloning frappe_docker"
	git clone --depth 1 "$UPSTREAM_URL" "$UPSTREAM_DIR"
fi

# Overwrites .devcontainer on every run: upstream is the source of truth for
# service definitions, docker-compose.override.yml is ours.
echo "==> Refreshing .devcontainer from devcontainer-example"
mkdir -p "$DC_DIR"
cp -R "$UPSTREAM_DIR/devcontainer-example/." "$DC_DIR/"

if [ ! -f "$REPO_DIR/.env" ]; then
	echo "==> Creating .env from .env.example"
	cp "$REPO_DIR/.env.example" "$REPO_DIR/.env"
fi

echo "==> Upstream images now in use:"
grep -E '^[[:space:]]+image:' "$DC_DIR/docker-compose.yml" | sed 's/^/   /'

cat <<'EOF'

Done. Next:

   ./services.sh up -d        start mariadb + redis-cache + redis-queue
   ./services.sh ps           check health

EOF
