# Infraestrutura do agacha.app

- **DNS e HTTPS:** Cloudflare (zona `agacha.app`). `agacha.com.br` ainda sem uso (landing page, depois).
- **Entrada:** Cloudflare Tunnel `agacha` → contêiner `agacha-cloudflared` → `agacha-pairing:8080`. Nenhuma porta aberta no servidor.
- **Servidor:** Hetzner (Ubuntu), pasta `/opt/agacha` (repositório clonado em `/opt/agacha/src`, token do túnel em `/opt/agacha/.env`, só root).
  Compartilha a máquina com contabil.dev e licita.dev, mas com contêineres e rede próprios; não usa o Caddy deles.
- **Atualizar:** `sudo /opt/agacha/deploy.sh` (puxa a branch, recompila o contêiner rodando `go vet` e `go test`).
- **Segredos:** nunca no repositório. Token da Cloudflare no Mac em `~/.config/agacha/cloudflare-token`; revogar quando não for mais preciso.
- **Backend:** ver `server/README.md` (API e regras de segurança).
