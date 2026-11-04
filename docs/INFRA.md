# Infraestrutura do agacha.app

- **DNS e HTTPS:** Cloudflare (zonas `agacha.app` e `agacha.com.br`). Nas duas, `@` e `www` são CNAME com proxy para o túnel; o certificado HTTPS é o Universal SSL da Cloudflare. Por enquanto `agacha.com.br` responde igual ao `agacha.app` (a landing page vem depois); `www` redireciona para o domínio sem www. Os registros de e-mail do `.com.br` (MX nulo, SPF `-all`, DMARC `reject`) foram mantidos.
- **Entrada:** Cloudflare Tunnel `agacha` → contêiner `agacha-cloudflared` → `agacha-pairing:8080`. Nenhuma porta aberta no servidor.
- **Servidor:** Hetzner (Ubuntu), pasta `/opt/agacha` (repositório clonado em `/opt/agacha/src`, token do túnel em `/opt/agacha/.env`, só root).
  Compartilha a máquina com contabil.dev e licita.dev, mas com contêineres e rede próprios; não usa o Caddy deles.
- **Atualizar:** `sudo /opt/agacha/deploy.sh` (puxa a branch, recompila o contêiner rodando `go vet` e `go test`).
- **Segredos:** nunca no repositório. Token da Cloudflare no Mac em `~/.config/agacha/cloudflare-token`; revogar quando não for mais preciso.
- **Backend:** ver `server/README.md` (API e regras de segurança).
