#!/usr/bin/env bash
# Thin `docker compose` wrapper that merges upstream's devcontainer compose
# file with our override. Passes every argument straight through:
#
#   ./services.sh up -d
#   ./services.sh ps
#   ./services.sh logs -f mariadb
#   ./services.sh down
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DC_DIR="$REPO_DIR/frappe_docker/.devcontainer"

if [ ! -f "$DC_DIR/docker-compose.yml" ]; then
	echo "frappe_docker is not set up yet. Run ./setup.sh first." >&2
	exit 1
fi

# --project-directory keeps upstream's relative bind mounts resolving against
# the .devcontainer directory, the way plain `docker compose` there would.
args=(
	--project-directory "$DC_DIR"
	-f "$DC_DIR/docker-compose.yml"
	-f "$REPO_DIR/docker-compose.override.yml"
)
[ -f "$REPO_DIR/.env" ] && args+=(--env-file "$REPO_DIR/.env")

exec docker compose "${args[@]}" "$@"
