#!/usr/bin/env bash
# Atualiza o backend do agacha.app no servidor: puxa o repositório e recompila o contêiner (os testes rodam na compilação).
# Uso (no servidor): sudo /opt/agacha/deploy.sh
set -euo pipefail

REPO_DIR=/opt/agacha/src
cd "$REPO_DIR"
git fetch --quiet origin phase-1-game main 2>/dev/null || git fetch --quiet origin
git reset --hard "${AGACHA_REF:-origin/phase-1-game}"
docker compose -f server/deploy/compose.yml up -d --build
docker image prune -f >/dev/null
docker ps --filter name=agacha-pairing --format '{{.Names}} {{.Status}}'
