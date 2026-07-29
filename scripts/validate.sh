#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 -m py_compile \
  "$ROOT_DIR/application/backend/app.py" \
  "$ROOT_DIR/application/backend/wsgi.py"
node --check "$ROOT_DIR/application/frontend/app.js"
bash -n "$ROOT_DIR/terraform/modules/compute/templates/web-user-data.sh.tftpl"
bash -n "$ROOT_DIR/terraform/modules/compute/templates/app-user-data.sh.tftpl"

terraform -chdir="$ROOT_DIR/terraform" fmt -check -recursive

for environment in dev prod; do
  terraform -chdir="$ROOT_DIR/terraform/environments/$environment" init -backend=false
  terraform -chdir="$ROOT_DIR/terraform/environments/$environment" validate
done

if docker compose version >/dev/null 2>&1; then
  echo "Validating Docker Compose configuration with docker compose."
  docker compose     -f "$ROOT_DIR/application/docker-compose.yml"     config >/dev/null
elif command -v docker-compose >/dev/null 2>&1; then
  echo "Validating Docker Compose configuration with docker-compose."
  docker-compose     -f "$ROOT_DIR/application/docker-compose.yml"     config >/dev/null
else
  echo "Docker Compose is unavailable; skipping Compose config validation."
fi

echo "Static validation completed successfully."
