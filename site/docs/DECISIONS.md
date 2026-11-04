# Decisões do site

- 2026-11-04 **Hospedagem:** arquivos estáticos servidos pelo contêiner Go que já atende agacha.com.br (túnel Cloudflare), sem Cloudflare Pages. O servidor passa a servir um site por domínio (`agacha.app` = pareamento, `agacha.com.br` = landing).
- 2026-11-04 **Stack (decisão do Paulo):** Astro + Tailwind v4 + GSAP/ScrollTrigger. Node/pnpm só na máquina de build; o resultado (`dist/`) é copiado para o servidor. Sem Next.js.
- 2026-11-04 **Código:** pasta `site/` no repositório do app (`javabipe/agacha`). `landing-page/` é só rascunho de referência.
- 2026-11-04 **Animação das crianças (hero):** o Paulo quer a animação como a da tela inicial do jogo. O app não tem `.riv`; a tia/tio e os avatares já existem em canvas/JS. Proposta: portar esse desenho para um canvas leve no hero (sem Rive). **Rive só se você quiser produzir um `.riv` — pergunta aberta.**
- 2026-11-04 **Plataformas:** nada marcado como publicado; iPhone/iPad "em breve", TV pelo navegador como recurso.
- Privacidade do site: sem rastreadores, sem cookies; analytics só se aprovado (pergunta aberta).
