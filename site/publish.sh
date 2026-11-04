#!/usr/bin/env bash
# Gera o site (astro build) e copia o resultado para o servidor Go, que o embute no binário.
# Uso: site/publish.sh   (depois: commit, e `sudo /opt/agacha/deploy.sh` no servidor)
set -euo pipefail
cd "$(dirname "$0")"
pnpm install --frozen-lockfile
pnpm build
rm -rf ../server/internal/web/site
mkdir -p ../server/internal/web/site
cp -R dist/. ../server/internal/web/site/
echo "Site copiado para server/internal/web/site ($(du -sh ../server/internal/web/site | cut -f1))."
