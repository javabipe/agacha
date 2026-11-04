# PROMPT PARA O CLAUDE CODE — site agacha.com.br (landing page do Agacha!)

> Cole este arquivo inteiro como primeira mensagem. O arquivo `reference/agacha-landing.html` na mesma pasta é a referência visual aprovada. Leia os dois antes de responder. Responda às perguntas da **Seção 9** e espere meu OK antes de criar qualquer coisa.

---

## 0. Contexto e como quero trabalhar

Sou o desenvolvedor do **Agacha!**, um jogo multiplataforma do morto-vivo (a "tia" na tela fala VIVO/MORTO e gesticula ao contrário; a câmera frontal detecta quem agachou e elimina quem errou). O app está **praticamente pronto**; o código-fonte está na pasta que eu indico na Seção 9. O domínio **agacha.com.br** é meu e está no Registro.br.

Você tem duas fontes de verdade, nesta ordem de prioridade:

1. **O app como ele é hoje** (o repositório Swift): modos, níveis, personagens, conjuntos de comandos, acessibilidade, preços, plataformas, requisitos mínimos, textos de loja, política de privacidade. **Leia o código e os docs antes de escrever qualquer copy.** Se o site disser algo que o app não faz, está errado.
2. **A referência visual** (`reference/agacha-landing.html`): a identidade que eu aprovei. Paleta, tipografia (Baloo 2 + Nunito), botões "clay" com sombra sólida, hero cinético com a palavra VIVO!/MORTO! alternando e o iPad com a demo, faixa verde de privacidade, cards de personagens, tabela de preços, FAQ, tema claro/escuro, PT/EN. **Mantenha essa UI.** Você pode melhorar execução, acessibilidade, performance e conteúdo; não pode trocar a direção visual.

Onde a referência e o app discordarem (um personagem que mudou de nome, um nível a mais, um preço diferente, uma plataforma que ainda não existe), **o app vence** e você atualiza o site. Registre cada divergência encontrada em `docs/DIVERGENCES.md` para eu conferir.

Regras:
- Trabalhe em fases (Seção 7). Ao fim de cada fase pare, mostre o resultado (URL de preview) e espere meu OK.
- Antes de inventar qualquer número, depoimento, avaliação ou nome, pergunte. Placeholders ficam entre colchetes, como `[12 mil famílias]`, nunca como fato.
- Nada que o site publique pode contrariar a categoria Kids da App Store e a política de privacidade do app: sem rastreadores de terceiros, sem pixel de anúncio, sem cookie banner que não precise existir. Analytics, se houver, só Cloudflare Web Analytics (sem cookies) — e pergunte antes.
- Commits pequenos com mensagens descritivas. Ações manuais minhas (DNS, Cloudflare, chaves) vão para `docs/MANUAL-STEPS.md` com passo a passo.

---

## 1. Primeiro trabalho: inventário do app (antes de qualquer HTML)

Explore o repositório do app e produza `docs/APP-INVENTORY.md` com o que o site precisa saber, cada item com o arquivo de origem:

- Nome oficial, tagline(s) e textos de loja já escritos (App Store Connect metadata, String Catalogs).
- Plataformas e versões mínimas **reais** hoje (iOS/iPadOS? macOS? Windows? web app? Apple TV?), e o status de cada uma: publicada, em TestFlight, em desenvolvimento, planejada. O site só marca "disponível" o que tem build publicada; o resto é "em breve" ou não aparece.
- Modos de jogo (passa a tela, Copa da Família, Turma, etc.), níveis e seus nomes, conjuntos de comandos (Vivo/Morto, Em pé/Agacha, Up/Down…), número máximo de crianças, acessibilidade (modo braços, só visual, vibração…).
- Personagens: nomes, descrição de um linha, quais são grátis e quais são do pacote; se houver `.riv` (Rive) ou imagens, onde estão.
- Compras: produtos StoreKit, preços por país, Family Sharing, licença escola se existir.
- Privacidade: o que `PRIVACY.md` / Privacy Nutrition Label dizem; texto da `NSCameraUsageDescription`.
- Idiomas suportados no app.
- Assets reutilizáveis: ícone, logo, screenshots, vídeos, fontes embutidas (confirme licença OFL das fontes antes de usar no site).
- Links: App Store (se já houver), TestFlight, suporte, e-mail de contato, nome legal do estúdio/CNPJ (se não houver, placeholder).

Só depois do inventário você monta o conteúdo do site.

---

## 2. Pesquisa (com liberdade)

Você tem liberdade para pesquisar na web e decidir:

- Tendências atuais de landing page para jogos e apps infantis/família (hero com vídeo ou demo, badges de plataforma, CTA persistente, prova social, privacidade como argumento). Aplique o que servir ao Agacha!; descarte modismos que pesem (3D WebGL pesado, cursores customizados, scroll hijacking).
- Bibliotecas: minha indicação é **Astro 5 + Tailwind v4 + GSAP/ScrollTrigger**, com **Rive** no hero se o app já tiver a Tia Lu em `.riv`. Se você encontrar algo comprovadamente melhor para este caso, proponha com justificativa antes de usar. Não use Next.js: a landing é estática e separada da web app.
- SEO para "morto vivo jogo", "brincadeira morto vivo", "jogo com câmera para crianças" em pt-BR, e "Simon Says camera game" em en-US. Open Graph e Twitter cards com imagem gerada do hero.

Documente as decisões em `docs/DECISIONS.md`.

---

## 3. O que o site precisa ter

Estrutura de páginas (Astro, i18n nativo, `/` pt-BR e `/en`):

- **Home** — a landing da referência, atualizada pelo inventário: nav com tema e idioma; hero cinético com demo (CSS/SVG como na referência, ou vídeo real `<video muted autoplay loop playsinline>` se eu fornecer); badges de plataforma com status real; prova social (placeholders até eu dar números); Como funciona; Plataformas; Privacidade (faixa verde com a etiqueta real da loja); Personagens; Preços; Depoimentos (placeholders); FAQ; rodapé.
- **/privacidade** e **/en/privacy** — a política completa, gerada a partir do `PRIVACY.md` do app (a App Store exige URL pública).
- **/suporte** e **/en/support** — como pedir ajuda, FAQ estendido, e-mail (também exigido pela loja).
- **/imprensa** (opcional, fase 3) — kit de imprensa: logo, screenshots, descrição curta, contato.
- **/app** — por enquanto, uma página "em breve" para a web app, ou redirecionamento, conforme o inventário disser.
- `robots.txt`, `sitemap.xml`, `manifest`, favicons e ícones a partir do ícone do app.

Requisitos não negociáveis:
- Mobile-first; nada rola horizontalmente; gutter lateral ≥ 16 px; CTA fixo no mobile.
- Tema claro/escuro seguindo o sistema, com toggle; PT/EN com toggle e URLs separadas.
- `prefers-reduced-motion` respeitado (o loop VIVO/MORTO para).
- Lighthouse ≥ 95 em Performance, Acessibilidade, Boas práticas e SEO no mobile.
- Fontes servidas localmente (self-host), não do Google Fonts, se a licença permitir.
- Zero JavaScript fora do hero, do toggle de tema/idioma e do reveal por scroll.

---

## 4. Stack e estrutura

```
agacha-site/
├─ package.json  astro.config.mjs  tailwind.config (v4: CSS-first)  tsconfig.json
├─ src/
│  ├─ pages/            index.astro, privacidade.astro, suporte.astro, app.astro, en/…
│  ├─ layouts/          Base.astro (head, OG, tema, fontes)
│  ├─ components/       Nav, Hero, HeroDemo (a demo do iPad), Platforms, Privacy, Characters, Pricing, Testimonials, Faq, Footer, StickyCta
│  ├─ i18n/             pt-BR.json, en.json (todas as strings; nada hardcoded nos componentes)
│  ├─ content/          faq, personagens, planos — em JSON/MD, gerados do inventário
│  └─ styles/           tokens.css (paleta e tipografia da referência), global.css
├─ public/              fontes, ícones, og.png, robots.txt
├─ docs/                APP-INVENTORY.md  DECISIONS.md  DIVERGENCES.md  MANUAL-STEPS.md
└─ .github/workflows/   (opcional) build + deploy
```

Tokens da referência que devem ser preservados (copiar de `reference/agacha-landing.html`): fundo `#1B1433`/`#2A1E4F`, creme `#FFF6E5`, amarelo `#FFC845` (sombra `#B9781B`), verde-água `#36C9A6`/`#1FA98A` (sombra `#0F5C49`), coral `#FF8F6B`/`#E0523C` (sombra `#8A2E1E`), lilás `#8E7BFF`; tema claro com fundo `#FFF6E5`/`#FFE9C2` e tinta `#2A1E3F`. Botões com sombra sólida de 6 px + sombra difusa + brilho interno. Títulos Baloo 2 800, texto Nunito.

---

## 5. Hospedagem e domínio

- **Cloudflare Pages** (plano grátis), build `astro build`, saída `dist/`. Preview automático por branch; produção em `main`.
- Domínio **agacha.com.br** (Registro.br): a opção recomendada é apontar os nameservers do Registro.br para o Cloudflare (DNS grátis), depois adicionar o domínio customizado no Pages. Alternativa: manter DNS no Registro.br e criar CNAME `www` + redirecionamento do apex. Escreva os dois caminhos em `MANUAL-STEPS.md` com os passos exatos e me pergunte qual eu quero.
- `www.agacha.com.br` → redireciona para `agacha.com.br`. HTTPS automático. Cabeçalhos de segurança básicos via `_headers`.
- Deploy pelo **Wrangler** (`wrangler pages deploy dist`) ou pela integração Git do Cloudflare — pergunte qual prefiro na Seção 9.

---

## 6. Qualidade

- Lighthouse CI local (`npx lighthouse` ou `unlighthouse`) nas duas línguas, mobile e desktop; anexe os números no fim de cada fase.
- Validação de HTML e verificação de links quebrados.
- Teste manual que eu faço: iPhone, iPad mini, Mac, tema claro e escuro, PT e EN, com `reduce motion` ligado.
- Nenhum console error. Nenhum request para domínio de terceiros além de fontes locais e, se aprovado, Cloudflare Web Analytics.

---

## 7. Fases

**Fase 1 — Inventário e plano (sem código de site):** `docs/APP-INVENTORY.md`, `docs/DIVERGENCES.md` (referência × app), `docs/DECISIONS.md` com a stack e a pesquisa resumida, e um esboço do conteúdo final da home (copy pt-BR). Pare e me mostre.

**Fase 2 — Site funcional:** projeto Astro, home pt-BR com a UI da referência e o conteúdo da Fase 1, tema e idioma, privacidade e suporte, deploy de preview no Cloudflare Pages. Pare, me mande a URL de preview e os números do Lighthouse.

**Fase 3 — Polimento e produção:** `/en`, OG/SEO, Rive ou vídeo no hero se houver assets, kit de imprensa opcional, domínio agacha.com.br apontado, redirecionamentos, `MANUAL-STEPS.md` concluído. Pare e me entregue o checklist final.

---

## 8. O que não fazer

- Não inventar avaliações, números de usuários, depoimentos, prêmios ou logos de imprensa.
- Não marcar plataforma como disponível sem build publicada.
- Não trocar a direção visual aprovada (paleta, tipografia, hero cinético, botões clay).
- Não adicionar rastreadores, pixels, chat widgets, pop-ups ou cookie banner desnecessário.
- Não usar imagens de banco genéricas de crianças; use a demo em SVG/CSS, screenshots reais do app ou ilustrações da identidade.

---

## 9. Perguntas que você deve me fazer ANTES de começar (responda e espere)

1. Caminho do repositório do app Swift no Mac (para o inventário). Posso lê-lo inteiro? Há `docs/` com `PRIVACY.md`, `DECISIONS.md` e metadata de loja?
2. Onde criar o site: pasta irmã do app (`../agacha-site`) com repositório Git próprio, ou dentro do monorepo do app em `site/`? (Recomendo repositório próprio.)
3. Já existe conta Cloudflare? Prefere deploy pela integração Git (GitHub) ou pelo Wrangler a partir do Mac?
4. O DNS de agacha.com.br pode ir para o Cloudflare, ou deve ficar no Registro.br?
5. Status real hoje de cada plataforma (iOS, macOS, Windows, web app, Apple TV): publicada, TestFlight, em desenvolvimento, planejada?
6. Existe o arquivo Rive da Tia Lu? Existe vídeo curto do jogo com crianças para o hero? Se não, mantenho a demo em CSS/SVG da referência.
7. Posso usar Cloudflare Web Analytics (sem cookies), ou nenhum analytics?
8. Nome legal do estúdio/CNPJ e e-mail de suporte para o rodapé e para a página de suporte — ou deixo placeholders?
9. Confirmo que posso instalar Node LTS, pnpm e Wrangler nesta máquina (via Homebrew/corepack)?

Depois das respostas, comece pela **Fase 1**.
