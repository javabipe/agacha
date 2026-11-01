# Decisões

Registro de suposições pequenas feitas durante o desenvolvimento.

| Data | Decisão | Motivo |
|---|---|---|
| 2026-10-27 | Projeto/target/pacote do app chamam-se `Agacha`; bundle id `br.com.agacha.agacha`; nome exibido `Agacha`. Pacotes locais mantêm o prefixo `Aganha*` da especificação. | Pasta e repositório já se chamam `agacha`. Trocar é só editar `project.yml` (confirmar com o Paulo). |
| 2026-10-27 | `.xcodeproj` e `App/Info.plist` são gerados pelo XcodeGen e ficam no `.gitignore`. | Spec, Seção 3. |
| 2026-10-27 | XcodeGen e SwiftLint ficam em `.tools/` (ignorado pelo git); o Makefile usa o do PATH se existir. | Evita exigir Homebrew. |
| 2026-10-27 | Strict concurrency `complete` no app; `CameraSession` e `PosePipeline` são `@unchecked Sendable` com `NSLock`. | Ambos são chamados da fila da câmera; estado compartilhado protegido por lock. |
| 2026-10-27 | Câmera entrega quadros espelhados e "em pé" (rotation coordinator), iguais à prévia aspect-fit. | Esqueletos batem com a imagem sem conversão extra. |
| 2026-10-27 | `UIFileSharingEnabled` ligado só no spike. | Tirar as fixtures JSON pelo app Arquivos. **Remover antes da Fase 3.** |
| 2026-10-27 | `AganhaUI` e `AganhaAudio` são placeholders na Fase 0. | Entram na Fase 1/2. |
| 2026-10-27 | Tracker: deslocamento vertical pesa 0,25 na distância de associação. | No iPad, agachar criava uma vaga nova (centro pula em y) e reiniciava a calibração. |
| 2026-10-27 | PostureClassifier: se o quadril não é visto, o agachamento é medido pela descida dos ombros (mesma normalização pelo tronco). | Ao agachar de frente o Vision perde os quadris; validado no iPad mini 6. Desvio da spec 6.1 só nesse caso. |
| 2026-10-28 | PostureClassifier: reserva final pelo nariz (escala padrão `noseFallbackScale` quando não há tronco). Center Stage desligado por padrão, com chave no painel de debug. | Teste de campo: enquadramento que segue a pessoa e ombros fora de quadro atrapalham. |
| 2026-10-28 | Requisito de uso: aparelho encostado na parede/chão, levemente inclinado, corpo inteiro visível (ver `SETUP-GUIDE.md`). A tela Posicionar da Fase 1 valida isso antes de iniciar. | Validado no iPad mini 6: corpo inteiro funciona; corpo cortado falha. |
| 2026-11-01 | Gravações brutas ficam em `audios/` (versionadas, repositório público por decisão do Paulo); `scripts/process_audio.py` (`make audio`) gera os `.caf` do app em `AganhaAudio/Resources/pt-BR/lu/`: mono 48 kHz, corte de silêncio (≈4 ms antes da palavra), volume nivelado (−16 dB RMS comandos, −18 demais, pico ≤ −1 dBFS). | Os originais tinham 50–530 ms de silêncio inicial (a janela de julgamento abriria antes da palavra), volumes de −0,1 a −11 dBFS e estéreo 44,1 kHz. |
| 2026-11-01 | Nomes corrigidos pelo script: `preparador`→`preparados`, `nivel_sapequa`→`nivel_sapeca`; MP3 de `campeao` e `fim_de_jogo` convertidos. `make audio-missing` lista os clipes do manifesto que faltam. | Erros de digitação na entrega do estúdio. |
| 2026-11-01 | Comandos processados duram 0,6–0,97 s (7 de 15 passam de 0,8 s), mais que a meta de 0,4–0,6 s. Não foram acelerados (alteraria a voz). O Director precisa contar o intervalo do nível Furacão a partir do início do áudio e não permitir sobreposição. | Palavras como AGACHA/LEVANTA são longas na fala natural. |
