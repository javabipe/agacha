# Arquitetura

```
App (SwiftUI, composição) ──► AganhaUI ──► AganhaCore (regras puras)
        │                                      ▲
        ├──► AganhaVision (AVFoundation+Vision)┘  só produz posturas por vaga
        ├──► AganhaAudio  (AVAudioEngine/TTS)
        └──► AganhaStore  (StoreKit 2, Fase 3)
```

- `AganhaCore` não conhece câmera nem UIKit; recebe `PostureSample(childSlot, posture, timestamp)`.
- `AganhaVision` não conhece regras. Pipeline: `CameraSession` → `PoseDetector` → `Tracker` (vaga por centroide) → `PostureClassifier` (histerese) → `FrameAnalysis`. `ReplayBuffer` guarda 2 s de esqueletos.
- Nenhuma imagem é gravada ou enviada. Fixtures contêm só juntas normalizadas.
- Testes: `make test` roda Core e Vision no macOS via `swift test`.

## Fase 0 (spike)
`App/SpikeView` + `SpikeModel`: prévia, esqueletos, rótulos, HUD (FPS, ms), painel de `PostureTuning`, gravação de fixture.
