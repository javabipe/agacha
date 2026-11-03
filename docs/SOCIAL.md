# Compartilhar e redes sociais (pesquisa e plano)

Estado: **simulação** com dados de exemplo (telas "Momentos" e "Compartilhar momento"). Nada sai do aparelho.

## Como os jogos e apps de clipes fazem
- **Padrão de produto:** o jogo guarda os últimos segundos (gravador de tela do sistema, no iOS o ReplayKit), um gatilho salva o clipe (vitória, melhor momento ou botão), o jogo corta, põe marca/placar, converte para vertical 9:16 e abre a **folha de compartilhamento do sistema** (`UIActivityViewController`). WhatsApp, Instagram, TikTok e YouTube aparecem como destinos. (Descrição geral, não de um jogo específico.)
- **Ferramentas de clipes** (Medal, Eklipse) automatizam o mesmo: detectar o destaque, reformatar para vertical, legendas/música/modelos e publicar em TikTok, Reels e Shorts. Fontes: [Medal](https://medal.tv/learn/share-gaming-clips), [Eklipse](https://eklipse.gg/).
- **SDKs por rede (opcionais; o share sheet já funciona sem eles):**
  - **TikTok Share Kit** (iOS): SDK `tiktok-opensdk-ios`, precisa de *client key* do TikTok for Developers, o usuário abre o TikTok para postar e o app precisa de acesso à fototeca. Há também a Content Posting API (servidor). Fontes: [Share Kit iOS](https://developers.tiktok.com/docs/en/share-kit-ios-quickstart-v2), [SDK no GitHub](https://github.com/tiktok/tiktok-opensdk-ios).
  - **Instagram Reels:** "Sharing to Reels" da Meta, por esquema de URL (`instagram-reels` em `LSApplicationQueriesSchemes`) e app ID da Meta com app "live". Fonte: [Meta](https://developers.facebook.com/documentation/ios/sharing-to-reels-instagram).
  - **YouTube Shorts:** nada específico encontrado para iOS além da API de dados (`videos.insert`, com login Google) — **a confirmar** antes de decidir. Pelo share sheet, o usuário envia o vídeo vertical pelo app do YouTube.
  - **WhatsApp:** share sheet (ou esquemas de URL) — sem SDK.

## O que propomos para o Aganha!
1. **Vídeo só de avatares, por padrão.** O jogo já guarda as poses (esqueletos) de cada criança; dá para renderizar o mesmo momento como vídeo vertical **sem nenhum rosto real** (avatar dançando/chorando, placar, tempos, marca e hashtag). É o diferencial: viral **e** seguro para crianças. A câmera de verdade fica como opção, com consentimento.
2. **Portão para adultos:** a conta de multiplicar foi **retirada** a pedido do Paulo (2026-11-17). A App Store (categoria Kids) ainda exige algum portão antes de compartilhar/links; **decidir um portão mais simples antes de publicar** (ex.: segurar um botão por 3 s).
3. **Primeiro, share sheet do sistema** (vale para TikTok, Instagram, YouTube, WhatsApp, AirDrop, Mensagens e "Salvar no álbum"), sem login e sem SDK de terceiros. SDKs de TikTok/Instagram só depois, se valer a pena.
4. **Desafio com hashtag** (#AganhaChallenge) e marca d'água com o nome do jogo; legenda sugerida editável.

## Regras para app infantil (a respeitar antes de publicar)
- **App Store, categoria Kids (guideline 1.3):** links para fora do app, redes sociais e compartilhar só atrás de **portão para adultos**; sem analytics ou publicidade de terceiros; sem enviar dados pessoais/do aparelho a terceiros. Fonte: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
- **COPPA:** foto, vídeo e áudio com imagem/voz de criança são informação pessoal; é preciso aviso aos pais e consentimento verificável. O portão da Apple **não** substitui o consentimento dos pais. Fonte: [iubenda](https://www.iubenda.com/en/help/13394-coppa-mobile-apps/).
- Política de privacidade obrigatória (5.1.4). O vídeo só de avatares evita a maior parte do risco.

## Fases
1. **(feito) Simulação:** telas Momentos e Compartilhar, "Mais…" abre o share sheet do iOS só com a legenda.
2. **Vídeo de avatares local:** renderizar o clipe 9:16 no aparelho (AVAssetWriter) a partir das poses gravadas durante a partida; salvar no álbum e compartilhar pelo share sheet.
3. **SDKs diretos (opcional):** TikTok Share Kit e Reels, com contas de desenvolvedor e revisão das plataformas.
4. **Feed de verdade ("Momentos" público):** exige servidor, moderação e consentimento dos pais; provavelmente incompatível com a categoria Kids. Decidir com cuidado (alternativa: link privado para a família).

## Decisões do Paulo (2026-11-16)
- **Vídeo/imagem de avatares é o padrão**; a **foto real** dos jogadores é uma opção (com aviso de autorização dos responsáveis).
- **Momentos já salva** (só no aparelho, fora do backup, com apagar um/todos e interruptor nos Ajustes): o pôster de avatares e até 4 fotos reais ("shots": uma do fim da partida e até 3 de destaques — acerto PERFEITO no modo pontuação, erro na eliminação). Ainda não há vídeo: o pôster e as fotos são imagens.
- **SDKs instalados, mas desligados** (`SocialConfig.isLive == false`): pacote `Packages/AganhaSocial` — TikTok Share Kit (SDK oficial), Instagram Reels (esquema de URL da Meta; não existe SDK a instalar), WhatsApp (sem SDK), YouTube (sem SDK; API de dados com login Google, a fazer). Nada é enviado enquanto não houver chaves e o interruptor. Chaves: `TIKTOK_CLIENT_KEY` em `Config/Base.xcconfig`/`Local.xcconfig`, ID do app Meta e ID OAuth do Google em `SocialConfig`.
- **Atenção Kids:** SDK de terceiro dentro de app da categoria Kids pode reprovar na App Store (a regra proíbe enviar dados a terceiros). Por isso tudo de terceiros está num pacote só, que dá para **retirar** de uma versão Kids.

## Feed público × links privados da família × categoria Kids
**Feed público** (como TikTok/Instagram dentro do app): exige servidor para guardar e entregar vídeos, contas de usuário, moderação (denúncias, remoção rápida, filtro de conteúdo impróprio, comentários), e consentimento verificável dos pais para vídeos de crianças (COPPA). É o tipo de recurso aberto que a categoria Kids praticamente não admite. Custo e risco altos.

**Links privados da família:** cada momento vira um link com endereço impossível de adivinhar (e que expira), criado só por um adulto e enviado por WhatsApp/Mensagens. Sem conta, sem busca, sem comentários, sem perfil de criança. Quem recebe só assiste. Precisa de um armazenamento mínimo (CloudKit da Apple, que é da própria Apple, ou um servidor nosso) e de um botão "apagar o link". Mantém o efeito de compartilhar sem virar rede social.

**Categoria Kids — vantagens:** confiança dos pais (selo e seção própria na App Store), aparece na navegação por idade (5 e menos, 6–8, 9–11), combina com o produto, protege a marca; **desvantagens:** sem anúncios/analytics de terceiros e sem enviar dados a terceiros, links para fora e compras só atrás de portão para adultos, quase nenhum recurso social aberto, revisão mais rígida, monetização limitada (compra única ou assinatura/compras com portão). Sair da Kids libera SDKs e feed, mas **não** tira o app das regras de privacidade infantil: se o jogo é voltado a crianças, a COPPA continua valendo (não é parecer jurídico — vale consultar um advogado antes de publicar).

**Caminho sugerido:** (1) Kids + avatares + folha de compartilhar do iOS (sem SDK); (2) link privado da família via CloudKit; (3) só se o crescimento exigir: uma versão "família" fora da Kids, com SDKs e feed moderado.

## Perguntas em aberto
- Seguimos com o plano acima ou queremos a versão fora da Kids com SDKs desde já?
- Vídeo de avatares (animado) é o próximo passo? (hoje só pôster)
