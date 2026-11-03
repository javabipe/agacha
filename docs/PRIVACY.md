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

## Replay em vídeo do erro (temporário)

- Durante a partida (e só se a opção estiver ligada no menu), o app grava em **arquivos temporários** os últimos segundos da câmera, para mostrar o replay em vídeo quando alguém erra.
- Os arquivos ficam na pasta temporária do app (protegida), sem som, **nunca são enviados**, e são **apagados** quando o replay termina, ao sair da partida, ao fim do jogo e na próxima abertura do app.
- A gravação é desligada fora da partida (nunca grava no menu nem no posicionamento).
- A imagem continua sem sair do aparelho. Isso muda a regra anterior ("nenhuma imagem em disco"): agora há vídeo temporário, que precisa constar na política de privacidade.

## Mostrar na TV pelo navegador (rede local)

- Com "Mostrar na TV pelo navegador" ligado, o app abre um servidor **só na rede Wi-Fi da casa**. A TV (ou outro navegador) abre o endereço mostrado e recebe o estado do jogo: palavra, cores, nomes dos jogadores, vidas e resultados. Os sons do jogo também podem tocar na TV.
- **Nunca envia imagem da câmera, vídeo ou áudio do microfone.** Nada sai da rede local; o servidor para ao desligar a opção ou fechar o app.
- Na versão de teste não há código de acesso: qualquer aparelho da mesma rede que souber o endereço pode ver o estado do jogo (inclusive nomes). Antes da App Store, adicionar um código na URL.
- O iOS pede a permissão de "Rede Local" na primeira vez (`NSLocalNetworkUsageDescription`).
