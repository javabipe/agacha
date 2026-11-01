# Privacidade

- Tudo é processado no aparelho; sem rede, sem contas, sem analytics, sem anúncios.
- Câmera: usada só para estimar poses. Quadros não são salvos nem enviados; o `ReplayBuffer` e as fixtures guardam apenas coordenadas de juntas.
- Dados locais (perfis, partidas) ficam em SwiftData no aparelho, com opção "apagar tudo" (Fase 3).
- App Store Privacy Nutrition Label: **Data Not Collected**.
- `NSCameraUsageDescription`: "A câmera identifica quem está de pé ou agachado. As imagens são processadas no aparelho e nunca salvas ou enviadas."

## Microfone e reconhecimento de fala (nomes dos jogadores)

- Antes da partida, o app pergunta o nome de cada jogador e usa o **microfone** e o **reconhecimento de fala do iOS** para entendê-lo.
- O reconhecimento roda **somente no aparelho** (`requiresOnDeviceRecognition`). Se o aparelho não tiver o idioma disponível offline, o app **não escuta** e os nomes podem ser digitados.
- O áudio **não é gravado nem enviado**; só o texto do nome é guardado, no próprio aparelho (últimos nomes usados), e pode ser apagado.
- A Label de Privacidade continua "Data Not Collected". Revisar com o parental gate e a categoria Kids antes da Fase 3.
