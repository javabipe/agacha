# Inventário do app (Fase 1 do site)

Fonte: repositório do app em 2026-11-04 (branch `phase-1-game`). "A confirmar" = não achei no código; não vai para o site como fato.

## Identidade
- Marca: **Agacha!** (o logo da tela inicial ainda mostra "Aganha!"; o Paulo decidiu que a marca é Agacha — corrigir no app). Nome na tela do iPhone: `CFBundleDisplayName: Agacha` (`project.yml`).
- Frase atual no app: "Levanta, agacha e vê quem é mais rápido!" (`App/Home/HomeView.swift`).
- Bundle: prefixo `br.com.agacha`. Idioma do app: **só pt-BR** hoje (vozes em `AganhaAudio/Resources/pt-BR`). O comando em inglês ("UP!/DOWN!") existe como conjunto de comandos, mas a voz e o app não são em inglês.

## Plataformas (status real)
| Plataforma | Status | Observação |
|---|---|---|
| iPad e iPhone (iOS/iPadOS 17+) | **em desenvolvimento**, testado no iPad mini 6; não há build na App Store nem TestFlight público | `project.yml` (`deploymentTarget iOS 17.0`) |
| TV | **funciona pelo navegador da TV** (Samsung testada) ou AirPlay; é só a tela do jogo, a câmera e a detecção ficam no iPad | `AganhaTV`, `agacha.app` para parear por código |
| macOS, Windows, web app, Apple TV (app) | **não existem** | saem do site |

## Como se joga (o que o app faz)
- A **tia** (ou o **tio**, escolha nos Ajustes) fala o comando; a câmera do iPad detecta quem está de pé ou agachado (Vision, tudo no aparelho). Comando pode vir **ao contrário do gesto** ("truque") e, quando o ritmo sobe, em **comandos duplos** ("Vivo! Morto!").
- **Modos:** *Eliminação* (quem erra sai; com "Foi injusto!" e replay) e *Pontuação* (moedas por rapidez de reação, combo, placar ao vivo; é o padrão da primeira vez, 10 rodadas). **Jogar sozinho** (treino com 1).
- **Níveis:** Tranquilo, Sapeca, Furacão. **Folga do juiz:** Pequenos, Normal, Rígido. **Erros permitidos** por jogador: ajustável.
- **Conjuntos de comandos:** VIVO!/MORTO!, LEVANTA!/AGACHA!, UP!/DOWN!.
- **Jogadores:** vários ao mesmo tempo; o **limite exato não está no código que li — a confirmar** (a referência dizia 6). Perguntar o nome de cada um por voz (microfone + reconhecimento de fala do iOS).
- **Avatares:** bonecos desenhados a partir das juntas do corpo (cabeça que inclina, mãos com dedos, tênis), cor por jogador, **visual de menino/menina sugerido pelo nome** (trocável), danças ao vencer e choro ao perder. Nunca usam a imagem da criança.
- **Momentos:** pôster de avatares, vídeo de avatares (MP4 vertical) e replay do último erro, guardados só no aparelho; compartilhar nas redes está **simulado** (SDKs instalados e desligados).
- **TV:** "Mostrar na TV pelo navegador" (rede Wi-Fi da casa), sons na TV, câmera/replay na TV com código de 4 dígitos; **Conectar TV** pelo código em `agacha.app`.

## Personagens
- Só **Tia** e **Tio** (apresentadores) e os avatares dos jogadores. **Não existem** Tia Lu (a "Lu" é só o nome da voz gravada), Vovô Chico, Robô Zum, Pirata Pepa, Juíza Jô nem Noel. Nenhum arquivo Rive (`.riv`) no projeto.

## Compras
- **Não há compras.** `AganhaStore` é um placeholder ("StoreKit 2 e parental gate entram na Fase 3"). Preço, plano grátis/pago e licença escola: **não definidos**.

## Privacidade (`docs/PRIVACY.md`)
- Câmera processada no aparelho; quadros não são enviados. Replay do erro em vídeo temporário, apagado em seguida; Momentos só no aparelho, fora do backup.
- Microfone/fala: o iOS pode enviar o áudio à Apple quando não há reconhecimento offline → a etiqueta "Data Not Collected" **precisa ser reavaliada** (pendência registrada). O site **não pode** prometer essa etiqueta ainda.
- TV: servidor só na rede local; vídeo da câmera na TV só com código, só na rede da casa.
- Pendências antes da App Store: portão para adultos (categoria Kids), política de privacidade em pt-BR, avaliar tirar o SDK do TikTok.
- `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSLocalNetworkUsageDescription` em `App/Info.plist`.

## Assets reaproveitáveis
- Desenho dos avatares e da tia/tio em JavaScript canvas (`Packages/AganhaTV/.../TVPage.swift`) e SwiftUI (`App/Avatar`): dá para portar para o site como a animação da tela inicial. Sem screenshots nem vídeos oficiais ainda (posso gerar capturas com a ferramenta de render offline).

## Links e contato
- App Store/TestFlight: **não há**. Suporte/e-mail e nome legal/CNPJ: **a definir** (placeholders).
- Domínios: `agacha.com.br` (landing) e `agacha.app` (pareamento da TV).
