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

## Reconhecimento dos jogadores por rosto (teste)

- Com a **autorização de um adulto** (confirmada com uma continha), o app guarda uma **impressão do rosto** (vetor do Vision, não é foto) e o nome de cada jogador, **somente no aparelho**: arquivo protegido, fora do backup do iCloud, sem envio.
- Na apresentação, o app também guarda por alguns minutos a **cor da roupa** de cada pessoa para ligar quem está longe ao jogador certo. Isso não é gravado em disco.
- Menu › **Jogadores salvos** mostra, apaga um por um ou apaga tudo. Desligar "Guardar rostos" apaga tudo.
- Sem autorização, o app não guarda rosto algum e pergunta o nome a cada partida.
- **Pendente antes da App Store:** dados biométricos de crianças são sensíveis (LGPD arts. 11 e 14; consentimento específico do responsável) e a categoria Kids tem regras próprias (Diretriz 1.3). Rever com a Label de Privacidade, política de privacidade e, se preciso, parental gate completo.
