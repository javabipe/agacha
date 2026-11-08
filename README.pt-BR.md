# Agacha!

🇺🇸 [Read in English](README.md)

**Agacha!** é a brincadeira do *morto-vivo* recriada como um jogo julgado pela câmera, para iPhone e iPad. Um personagem na tela grita **"VIVO!"** (fica de pé) ou **"MORTO!"** (agacha) e gesticula com os braços, às vezes fazendo o gesto *contrário* para enganar. Até 6 crianças ficam em pé na frente do aparelho; a câmera frontal detecta quem agachou e quem ficou de pé e elimina quem errou. Quem já está na posição certa, permanece. Vence quem sobrar por último.

- **Feito para famílias.** Pais, avós e crianças de 3 a 10 anos. Projetado para a categoria **Kids** da App Store.
- **Privado por construção.** Toda a visão computacional roda no aparelho com o Apple Vision. Nenhuma imagem é salva ou enviada. Sem anúncios, sem conta, sem rede: funciona em modo avião.
- **Feito para jogar à distância.** O aparelho fica apoiado na parede ou no chão, então o jogo é guiado por voz, com comandos falados e ajuda de posicionamento.
- **Justo por construção.** Toda eliminação mostra um replay de 0,8 s em esqueleto, e o botão "Foi injusto!" repete a rodada sem eliminar ninguém. A tolerância do juiz é ajustável.

## Estado atual

O app para iOS/iPadOS está completo e sendo preparado para a revisão da App Store. <!-- ajustar: "em TestFlight" / "em revisão" / "na App Store desde …" -->

O que já funciona:

- Detecção de pose de várias pessoas e classificação de postura (em pé / agachado / indefinido) com calibração por jogador e histerese, a 30 fps num iPad mini 6.
- Vagas de jogadores com cores e nomes, rastreamento entre quadros, tratamento de "pessoa extra".
- Ciclo completo de jogo: contagem, comando, janela de julgamento, eliminação, pódio.
- Níveis (*Tranquilo*, *Sapeca*, *Furacão*), truques de gesto contrário, comandos de "fica", diretor de comandos determinístico com semente para testes.
- Conjuntos de comandos: *Vivo / Morto* (clássico), *Em pé / Agacha* (escolas e crianças pequenas), *Up / Down* (inglês).
- Acessibilidade: modo braços (levantar/abaixar os braços em vez de agachar), modo só visual, vibração e flash de tela.
- Personagens com voz e estilo de truque próprios; TTS do sistema provisório, com a pipeline de áudio pronta para clipes gravados em estúdio.
- Perfis de crianças, estatísticas, Copa da Família local, conquistas, tutorial em 4 passos.
- Área dos pais com portão parental, restauração de compras e "apagar todos os dados"; "Pacote Família" não consumível via StoreKit 2 com compartilhamento familiar.
- Catálogos de strings em pt-BR e en-US.

Veja o [ROADMAP.md](ROADMAP.md) para o que vem a seguir.

## Arquitetura

Pacotes Swift locais com um alvo de app fino que só os compõe. As regras do jogo nunca tocam a câmera, e a camada de visão nunca conhece as regras, então o mesmo núcleo roda em qualquer plataforma com câmera frontal.

| Pacote | Papel |
|---|---|
| `AganhaCore` | Modelos e regras em Swift puro: máquina de estados, diretor de comandos, juiz, pontuação. Sem câmera, sem UIKit. Totalmente testado. |
| `AganhaVision` | Sessão de câmera (AVFoundation), detecção de pose (Vision), rastreador de vagas, classificador de postura, buffer de replay só com esqueletos. |
| `AganhaAudio` | Clipes de voz, TTS do sistema como reserva e efeitos sonoros com baixa latência. |
| `AganhaUI` | Telas, componentes e tema em SwiftUI. |
| `AganhaStore` | Compras via StoreKit 2, portão parental, restauração. |

Os nomes dos pacotes ainda usam o título provisório do projeto, *Aganha*. Detalhes em [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Requisitos

- iOS / iPadOS 17 ou superior, aparelho com câmera frontal (o Simulador não tem câmera).
- Xcode 26, [XcodeGen](https://github.com/yonaskolb/XcodeGen) e [SwiftLint](https://github.com/realm/SwiftLint) (`brew install xcodegen swiftlint`).

## Compilando

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig   # defina seu DEVELOPMENT_TEAM
make project   # gera o Agacha.xcodeproj com XcodeGen
make test      # testes de Core e Vision (fixtures de esqueleto, sem câmera)
make build     # compila para iOS
make lint      # SwiftLint
```

Depois abra `Agacha.xcodeproj` e rode num aparelho.

## Como usar

Para a detecção funcionar bem, o corpo inteiro de cada jogador precisa aparecer: apoie o aparelho na parede (de preferência no chão, levemente inclinado para cima) e afaste-se até todos caberem no quadro da cabeça aos pés, a uns 2–3 m. Luz boa ajuda. Veja [docs/SETUP-GUIDE.md](docs/SETUP-GUIDE.md).

## Privacidade

Os quadros da câmera são processados no aparelho, um a um, e descartados. Nada é gravado, enviado ou compartilhado. O app não tem código de rede, analytics nem SDKs de terceiros. Os replays são feitos com as juntas do esqueleto, nunca com imagens. A etiqueta de privacidade na App Store é "Dados não coletados". Declaração completa: [docs/PRIVACY.md](docs/PRIVACY.md).

## Documentação

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): pacotes, ciclo de jogo, classificador de postura e rastreador
- [docs/DECISIONS.md](docs/DECISIONS.md): decisões de design e engenharia
- [docs/PRIVACY.md](docs/PRIVACY.md): declaração de privacidade
- [docs/SETUP-GUIDE.md](docs/SETUP-GUIDE.md): posicionando o aparelho e os jogadores
- [docs/AUDIO-SCRIPT.md](docs/AUDIO-SCRIPT.md): roteiro de gravação de voz (pt-BR)
- [docs/PHASE0-CHECKLIST.md](docs/PHASE0-CHECKLIST.md): checklist de teste de campo
- [ROADMAP.md](ROADMAP.md): trabalho planejado

## Contribuindo

Issues e pull requests são bem-vindos, principalmente sobre detecção de postura em aparelhos e iluminações diferentes, acessibilidade e portes para outras plataformas. Mantenha as regras de privacidade acima: nada neste projeto pode armazenar ou transmitir imagens da câmera.

## Licença

O código-fonte é distribuído sob a [Licença MIT](LICENSE).

**"Agacha!"**, os personagens do jogo (Tia Lu, Vovô Chico e os demais), seus nomes, arte, gravações de voz, ícone e textos de loja **não** estão cobertos por esta licença. Permanecem propriedade do autor e não podem ser usados para publicar apps derivados com o mesmo nome ou identidade, nem com nome ou identidade confundíveis. Use o código à vontade; crie a sua própria marca.

Os assets proprietários (arte dos personagens, animações Rive, vozes gravadas) ficam fora deste repositório.
