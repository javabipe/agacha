# Privacidade

- Tudo é processado no aparelho; sem rede, sem contas, sem analytics, sem anúncios.
- Câmera: usada só para estimar poses. Quadros não são salvos nem enviados; o `ReplayBuffer` e as fixtures guardam apenas coordenadas de juntas.
- Dados locais (perfis, partidas) ficam em SwiftData no aparelho, com opção "apagar tudo" (Fase 3).
- App Store Privacy Nutrition Label: **Data Not Collected**.
- `NSCameraUsageDescription`: "A câmera identifica quem está de pé ou agachado. As imagens são processadas no aparelho e nunca salvas ou enviadas."

## Microfone e reconhecimento de fala (nomes dos jogadores)

- Antes da partida, o app pergunta o nome de cada jogador e usa o **microfone** e o **reconhecimento de fala do iOS** para entendê-lo.
- Quando o aparelho tem o idioma disponível offline, o reconhecimento roda **no aparelho**. Caso contrário, o iOS pode enviar o áudio **à Apple** para reconhecer a fala (decisão do Paulo em 2026-11-02, para funcionar com internet). O app em si não grava o áudio nem usa servidores próprios.
- O texto do nome fica guardado só no aparelho (últimos nomes usados) e pode ser apagado.
- **Pendente antes da App Store:** com o envio de áudio à Apple, a Label de Privacidade "Data Not Collected" e a categoria Kids (faixa 6–8, Diretriz 1.3) precisam ser reavaliadas, possivelmente exigindo parental gate ou desligar a voz por padrão. Alternativa: usar só reconhecimento offline.
