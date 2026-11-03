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
2. **Portão para adultos** antes de qualquer compartilhamento (já na simulação: conta de multiplicar).
3. **Primeiro, share sheet do sistema** (vale para TikTok, Instagram, YouTube, WhatsApp, AirDrop, Mensagens e "Salvar no álbum"), sem login e sem SDK de terceiros. SDKs de TikTok/Instagram só depois, se valer a pena.
4. **Desafio com hashtag** (#AganhaChallenge) e marca d'água com o nome do jogo; legenda sugerida editável.

## Regras para app infantil (a respeitar antes de publicar)
- **App Store, categoria Kids (guideline 1.3):** links para fora do app, redes sociais e compartilhar só atrás de **portão para adultos**; sem analytics ou publicidade de terceiros; sem enviar dados pessoais/do aparelho a terceiros. Fonte: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
- **COPPA:** foto, vídeo e áudio com imagem/voz de criança são informação pessoal; é preciso aviso aos pais e consentimento verificável. O portão da Apple **não** substitui o consentimento dos pais. Fonte: [iubenda](https://www.iubenda.com/en/help/13394-coppa-mobile-apps/).
- Política de privacidade obrigatória (5.1.4). O vídeo só de avatares evita a maior parte do risco.

## Fases
1. **(feito) Simulação:** telas Momentos e Compartilhar, portão para adultos, "Mais…" abre o share sheet do iOS só com a legenda.
2. **Vídeo de avatares local:** renderizar o clipe 9:16 no aparelho (AVAssetWriter) a partir das poses gravadas durante a partida; salvar no álbum e compartilhar pelo share sheet.
3. **SDKs diretos (opcional):** TikTok Share Kit e Reels, com contas de desenvolvedor e revisão das plataformas.
4. **Feed de verdade ("Momentos" público):** exige servidor, moderação e consentimento dos pais; provavelmente incompatível com a categoria Kids. Decidir com cuidado (alternativa: link privado para a família).

## Perguntas em aberto
- Vídeo só de avatares como padrão (recomendado)? A câmera real entra nesta versão?
- Quais redes primeiro: só share sheet ou também SDK de TikTok/Instagram?
- O app continua na categoria Kids (limita muito o social) ou passa a "família/uso geral"?
