# Aganha!

🇺🇸 [Read in English](README.md)

**Aganha!** é a brincadeira brasileira do **morto-vivo** em versão digital, para iPhone e iPad. Um personagem na tela fala "VIVO!" (fica de pé) ou "MORTO!" (agacha) e faz gestos com os braços, às vezes o *contrário* do que diz, para enganar. Até 6 crianças brincam na frente do aparelho, e a câmera frontal reconhece quem agachou e quem ficou de pé e elimina quem errou. Vence o último que sobrar.

- **Para famílias:** pais, avós e crianças de 3 a 10 anos, pensado para a categoria Kids da App Store.
- **Privacidade:** a visão computacional roda no aparelho; nenhuma imagem é salva ou enviada. Sem anúncios, sem conta, sem rede.
- **Feito para jogar de longe:** o aparelho fica encostado na parede ou no chão, então o jogo é guiado por voz, com instruções faladas.
- **Tecnologia:** Swift 6, SwiftUI, Vision (pose do corpo) e AVFoundation. Requer iOS/iPadOS 17+.

## Status

**Fase 0: protótipo técnico.** O app atual tem uma tela e prova o reconhecimento de postura no aparelho: prévia da câmera, esqueletos, rótulo em pé/agachado por pessoa, painel de ajuste ao vivo e gravação de fixtures só com esqueletos. O jogo em si vem na Fase 1.

## Como compilar

Requer Xcode 26 e [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig   # coloque seu DEVELOPMENT_TEAM
make project   # gera o Agacha.xcodeproj
make test      # testes de Core e Vision
make build     # compila para iOS
make lint      # SwiftLint
```

Abra o `Agacha.xcodeproj` e rode num aparelho (a câmera não funciona no Simulador).

## Como usar

Para a detecção funcionar bem, **o corpo inteiro de cada jogador precisa aparecer**: encoste o aparelho na parede (de preferência no chão, levemente inclinado) e afaste-se até todos aparecerem da cabeça aos pés. Veja [`docs/SETUP-GUIDE.md`](docs/SETUP-GUIDE.md).

## Licença

Ainda sem licença definida. Todos os direitos reservados até que uma seja adicionada.
