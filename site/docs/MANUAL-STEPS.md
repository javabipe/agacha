# Passos manuais

## Publicar uma nova versão do site
1. `site/publish.sh` (usa Node em `~/.local/node/bin`; gera o site e copia para `server/internal/web/site`).
2. Commit e push em `phase-1-game`.
3. No servidor: `sudo /opt/agacha/deploy.sh` (recompila o contêiner; os testes rodam na compilação).

## Cloudflare Web Analytics (sem cookies) — fazer no painel
1. Painel Cloudflare → Web Analytics → "Add a site" → `agacha.com.br`.
2. Escolha a inserção automática (sites que passam pelo proxy da Cloudflare). Nada muda no código; a política de segurança do servidor já permite `static.cloudflareinsights.com`.
3. Se não quiser medir visitas, não ative e remova a frase "Usamos a medição de visitas da Cloudflare" da página de privacidade.

## Pendente
- Imagem de compartilhamento `og.png` (1200×630) em `site/public/`.
- Quando houver app na App Store: trocar "Em breve" pelo selo e link da loja.
