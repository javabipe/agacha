# Servidor do agacha.app

Roteador de pareamento: a TV abre `https://agacha.app`, vê um código de 4 dígitos, o iPad digita o código e a TV é levada
sozinha para o jogo na rede da casa (`http://192.168.x.x:8080`). Também funciona no sentido contrário: o iPad mostra um
código e a TV digita.

- Linguagem: Go (só a biblioteca padrão). Sem banco de dados: códigos ficam só na memória, por 10 minutos.
- Privacidade: sem log de acesso; o servidor só vê o endereço privado do iPad e some com ele em minutos.
- Entrada: túnel da Cloudflare (`cloudflared`); o servidor não abre porta nenhuma para o agacha.app.
- Segurança: só aceita IPv4 privado (10.x, 172.16–31.x, 192.168.x) e portas 1024–65535, então nunca redireciona para fora
  da rede local; 10 tentativas de código por minuto por IP e 300 por minuto no total.

## API (JSON)
| Quem | Chamada | O que faz |
|---|---|---|
| TV | `POST /api/tv/session` | abre uma sessão e devolve `{session, code}` |
| TV | `GET /api/tv/wait?s=<session>` | espera até 20 s; `{status:"paired", url}` quando o iPad pareou |
| TV | `POST /api/tv/claim {code}` | digita o código que o iPad mostra e recebe `{url}` |
| iPad | `POST /api/app/pair {code, host, port, token?}` | digita o código da TV e entrega o endereço |
| iPad | `POST /api/app/offer {host, port, token?}` | recebe um código para digitar na TV |

## Testar e rodar
    docker build -t agacha-server server      # compila rodando go vet e go test
    docker compose -f server/deploy/compose.yml up -d --build

O HTTPS e o DNS ficam na Cloudflare (túnel `agacha` -> `cloudflared` -> `pairing:8080`); os cabeçalhos de segurança saem do próprio servidor. `deploy/deploy.sh` atualiza o servidor (puxa o repositório, recompila e roda os testes).
