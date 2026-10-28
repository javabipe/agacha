# Roteiro de gravação — Aganha! (pt-BR)

Documento para o estúdio/locutor. A lista completa de arquivos (um por linha) está em `docs/audio-manifest.csv`.

## Locutores

| Código | Personagem | Direção de voz |
|---|---|---|
| `lu` | Tia Lu | Mulher, 30–45 anos. Tia divertida e carinhosa, energia alta, sorriso na voz. |
| `chico` | Vovô Chico | Homem, 60+ (ou voz que soe assim). Grave e calorosa, brincalhão, um pouco mais pausado. Nunca severo. |

Os dois gravam **as mesmas linhas** (só o texto da introdução do tutorial muda). Sotaque: **pt-BR neutro**, sem gírias regionais. Público: crianças de 3 a 10 anos e avós.

## Como dizer (vale para tudo)

- **O aparelho ficará a 2–3 m, no chão, com barulho de crianças.** Projetem a voz, consoantes bem marcadas, dicção limpa. Falem como para uma sala, não como para um microfone.
- Sem música, sem efeitos, sem reverb, sem eco. Uma frase por arquivo.
- **Comandos de jogo:** o arquivo deve **começar na própria palavra** (silêncio inicial ≤ 10 ms). Cada gravação é cortada e entregue separada. Duração alvo: **0,4–0,6 s** (o nível Furacão tem só 0,6 s entre comandos).
- **Não dar pistas:** quando o jogo "engana" (gesto contrário à palavra), a voz é a mesma. As 3 variações de cada comando existem só para a brincadeira não ficar repetitiva.
- Tom sempre positivo: quem erra não é zombado. "MORTO" é palavra de brincadeira, nunca sombria.
- Gravem 2 tomadas de cada linha e escolham a melhor; entreguem só a escolhida.

## Especificações técnicas

- Formato: **WAV, 48 kHz, 24 bits, mono**.
- Nível: pico máximo **−1 dBFS**; volume médio parecido entre todos os arquivos (alvo ≈ −16 LUFS). Comandos e reações podem estar ~2 dB acima das instruções.
- Cauda final ≤ 80 ms de silêncio. Sem cliques, respiração audível nem ruído de sala.
- Compressão leve é bem-vinda (voz precisa ser inteligível de longe).

## Nomes de arquivo

`{voz}_{categoria}_{id}_v{n}.wav`, por exemplo `lu_cmd_vivo_v1.wav`, `chico_setup_afastem_v1.wav`.

Pastas sugeridas: `pt-BR/lu/` e `pt-BR/chico/` (todos os arquivos do locutor juntos). Podem entregar tudo numa pasta só; eu organizo.

## Prioridades

- **P0** = necessário para o jogo funcionar de longe (Fase 1/2). **P1** = polimento/tutorial. **P2** = opcional/futuro.
- Arquivos por locutor: **97** no total (P0: 57, P1: 33, P2: 7). Dois locutores: **194**.
- Se for gravar por etapas: comece pelo P0.

## Notas
- **Nomes de crianças** não são gravados: o app usa voz do sistema para eles. Por isso os anúncios usam **cores** (amarelo, verde, laranja, roxo, azul, rosa); as cores dos jogadores no app serão essas seis.
- O conjunto escolar usa **LEVANTA / AGACHA** (em vez de "EM PÉ / AGACHA"). "EM PÉ!" fica como extra (P2).
- Inglês (UP/DOWN etc.) será pedido numa segunda rodada.


## 1. Comandos de jogo (os mais importantes)

| ID | Texto | Variações | Prior. | Direção |
|---|---|---|---|---|
| `cmd_vivo` | VIVO! | 3 | P0 | Seco e enérgico. Começa direto na consoante, sem respirar antes. Não alongue a vogal final. SEM tom de malícia ou dica: as 3 variações têm a mesma intenção, só mudam levemente a entonação. |
| `cmd_morto` | MORTO! | 3 | P0 | Seco e enérgico. Começa direto na consoante, sem respirar antes. Não alongue a vogal final. SEM tom de malícia ou dica: as 3 variações têm a mesma intenção, só mudam levemente a entonação. MORTO é palavra de brincadeira: tom divertido, nunca sombrio. |
| `cmd_levanta` | LEVANTA! | 3 | P0 | Seco e enérgico. Começa direto na consoante, sem respirar antes. Não alongue a vogal final. SEM tom de malícia ou dica: as 3 variações têm a mesma intenção, só mudam levemente a entonação. |
| `cmd_agacha` | AGACHA! | 3 | P0 | Seco e enérgico. Começa direto na consoante, sem respirar antes. Não alongue a vogal final. SEM tom de malícia ou dica: as 3 variações têm a mesma intenção, só mudam levemente a entonação. |
| `cmd_em_pe` | EM PÉ! | 2 | P2 | Seco e enérgico. Começa direto na consoante, sem respirar antes. Não alongue a vogal final. SEM tom de malícia ou dica: as 3 variações têm a mesma intenção, só mudam levemente a entonação. |

## 2. Condução da partida

| ID | Texto | Variações | Prior. | Direção |
|---|---|---|---|---|
| `flow_vamos_brincar` | Vamos brincar de Agacha! | 2 | P0 | Animado, claro, projetado como quem fala com a sala inteira. |
| `flow_todos_em_pe` | Todo mundo em pé, de frente para mim! | 1 | P0 | Animado, claro, projetado como quem fala com a sala inteira. |
| `flow_preparados` | Preparados? | 2 | P0 | Animado, claro, projetado como quem fala com a sala inteira. |
| `flow_count_3` | Três! | 1 | P0 | Contagem: cada número separado, ritmo de 1 por segundo. |
| `flow_count_2` | Dois! | 1 | P0 | Idem. |
| `flow_count_1` | Um! | 1 | P0 | Idem. |
| `flow_count_go` | Já! | 2 | P0 | Animado, claro, projetado como quem fala com a sala inteira. Mais forte que a contagem. |
| `flow_nivel_tranquilo` | Nível Tranquilo! | 1 | P1 | Animado, claro, projetado como quem fala com a sala inteira. |
| `flow_nivel_sapeca` | Nível Sapeca! | 1 | P1 | Animado, claro, projetado como quem fala com a sala inteira. |
| `flow_nivel_furacao` | Nível Furacão! | 1 | P1 | Animado, claro, projetado como quem fala com a sala inteira. Mais intenso. |
| `flow_truque_aviso` | Atenção! Às vezes eu vou enganar vocês! | 1 | P1 | Animado, claro, projetado como quem fala com a sala inteira. Tom brincalhão, cúmplice. |
| `flow_mais_rapido` | Mais rápido! | 2 | P1 | Animado, claro, projetado como quem fala com a sala inteira. |
| `flow_ficou_dificil` | Agora vai ficar difícil! | 1 | P1 | Animado, claro, projetado como quem fala com a sala inteira. |
| `flow_proxima_rodada` | Próxima rodada! | 2 | P1 | Animado, claro, projetado como quem fala com a sala inteira. |
| `flow_repetir_rodada` | Tudo bem, vamos repetir essa! | 1 | P0 | Gentil, conciliador (botão "Foi injusto!"). |
| `flow_pausa` | Pausa! | 1 | P1 | Animado, claro, projetado como quem fala com a sala inteira. |
| `flow_continuar` | Vamos continuar! | 1 | P1 | Animado, claro, projetado como quem fala com a sala inteira. |
| `flow_descansar` | Que tal descansar um pouquinho? Depois a gente brinca de novo! | 1 | P1 | Carinhoso, de quem cuida (pausa automática aos 20 min). |

## 3. Reações (sem nome de pessoa)

| ID | Texto | Variações | Prior. | Direção |
|---|---|---|---|---|
| `fb_acertou_1` | Isso! | 1 | P0 | Reação curta e calorosa. Nunca zombar de quem erra. |
| `fb_acertou_2` | Muito bem! | 1 | P0 | Reação curta e calorosa. Nunca zombar de quem erra. |
| `fb_acertou_3` | Boa! | 1 | P1 | Reação curta e calorosa. Nunca zombar de quem erra. |
| `fb_errou_1` | Ih, alguém errou! | 1 | P0 | Reação curta e calorosa. Nunca zombar de quem erra. |
| `fb_errou_2` | Ops! | 1 | P1 | Reação curta e calorosa. Nunca zombar de quem erra. |
| `fb_errou_3` | Quase! | 1 | P1 | Reação curta e calorosa. Nunca zombar de quem erra. |
| `fb_ninguem_errou` | Ninguém errou! Continua! | 1 | P1 | Reação curta e calorosa. Nunca zombar de quem erra. |
| `fb_restam_dois` | Só restam dois! É a final! | 1 | P0 | Animado, claro, projetado como quem fala com a sala inteira. Tensão divertida. |
| `fb_nao_vi` | Cadê você? Não consegui te ver! | 1 | P1 | Reação curta e calorosa. Nunca zombar de quem erra. |
| `fb_fim_de_jogo` | Fim de jogo! | 1 | P0 | Animado, claro, projetado como quem fala com a sala inteira. |
| `fb_campeao` | Temos um campeão! Parabéns! | 2 | P0 | Animado, claro, projetado como quem fala com a sala inteira. Comemoração. |
| `fb_empate` | Deu empate! Que brincadeira boa! | 1 | P1 | Animado, claro, projetado como quem fala com a sala inteira. |
| `fb_de_novo` | Vamos jogar de novo? | 1 | P0 | Animado, claro, projetado como quem fala com a sala inteira. |

## 4. Anúncios por cor do jogador (as 6 vagas)

| ID | Texto | Variações | Prior. | Direção |
|---|---|---|---|---|
| `cor_amarelo_errou` | Amarelo errou! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_amarelo_venceu` | Amarelo venceu! Parabéns! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_amarelo_sumiu` | Amarelo, saiu da câmera! Volte para o seu lugar. | 1 | P1 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_verde_errou` | Verde errou! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_verde_venceu` | Verde venceu! Parabéns! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_verde_sumiu` | Verde, saiu da câmera! Volte para o seu lugar. | 1 | P1 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_laranja_errou` | Laranja errou! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_laranja_venceu` | Laranja venceu! Parabéns! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_laranja_sumiu` | Laranja, saiu da câmera! Volte para o seu lugar. | 1 | P1 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_roxo_errou` | Roxo errou! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_roxo_venceu` | Roxo venceu! Parabéns! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_roxo_sumiu` | Roxo, saiu da câmera! Volte para o seu lugar. | 1 | P1 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_azul_errou` | Azul errou! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_azul_venceu` | Azul venceu! Parabéns! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_azul_sumiu` | Azul, saiu da câmera! Volte para o seu lugar. | 1 | P1 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_rosa_errou` | Rosa errou! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_rosa_venceu` | Rosa venceu! Parabéns! | 1 | P0 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |
| `cor_rosa_sumiu` | Rosa, saiu da câmera! Volte para o seu lugar. | 1 | P1 | Anúncio animado. Pronuncie a cor com clareza; é a identificação do jogador. |

## 5. Posicionar o aparelho (crítico: ninguém vai ler a tela de longe)

| ID | Texto | Variações | Prior. | Direção |
|---|---|---|---|---|
| `setup_intro` | Encoste o aparelho na parede, de preferência no chão, um pouquinho inclinado para cima. | 1 | P0 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `setup_afastem` | Afastem-se até eu ver todo mundo, da cabeça aos pés. | 1 | P0 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `setup_passo_tras` | Deem um passinho para trás. | 1 | P0 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. Curto e claro. |
| `setup_passo_frente` | Deem um passinho para a frente. | 1 | P0 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. Curto e claro. |
| `setup_para_meio` | Cheguem mais para o meio. | 1 | P0 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. Curto e claro. |
| `setup_sem_cabeca` | Não estou vendo a cabeça de alguém. | 1 | P0 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `setup_sem_pes` | Não estou vendo os pés de alguém. | 1 | P0 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `setup_cortado` | Tem alguém cortado na imagem. | 1 | P0 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `setup_luz_fraca` | Está escuro aqui. Acendam uma luz! | 1 | P0 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `setup_contraluz` | A luz está atrás de vocês. Virem a luz para a frente. | 1 | P1 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `setup_parados` | Fiquem em pé, paradinhos, de frente para mim. Vou conhecer vocês! | 1 | P0 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `setup_pronto` | Pronto! Já vi todo mundo! | 1 | P0 | Animado, claro, projetado como quem fala com a sala inteira. |
| `setup_gente_demais` | Tem gente demais! Só podem brincar seis de cada vez. | 1 | P1 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `setup_pouca_gente` | Preciso de pelo menos duas pessoas para brincar. | 1 | P1 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `setup_comecar_bracos` | Para começar, levantem os dois braços! | 2 | P0 | Animado, claro, projetado como quem fala com a sala inteira. |
| `setup_comecar_ok` | Isso! Vamos começar! | 1 | P0 | Animado, claro, projetado como quem fala com a sala inteira. |
| `setup_camera_negada` | O Agacha precisa da câmera para funcionar. Peça a um adulto para permitir nos Ajustes. | 1 | P2 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |

## 6. Tutorial (4 passos). Os textos de intro mudam por locutor

| ID | Texto | Variações | Prior. | Direção |
|---|---|---|---|---|
| `tut_intro` | LU: "Oi! Eu sou a Tia Lu! Vem brincar de Agacha comigo?" | CHICO: "Olá, crianças! Eu sou o Vovô Chico! Vamos brincar de Agacha?" | 1 | P1 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. Apresentação do personagem. |
| `tut_regra_classic` | Quando eu disser VIVO, fiquem em pé. Quando eu disser MORTO, agachem! | 1 | P1 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `tut_regra_school` | Quando eu disser LEVANTA, fiquem em pé. Quando eu disser AGACHA, agachem! | 1 | P1 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `tut_regra_fica` | Se já estiver na posição que eu mandar, é só ficar parado! | 1 | P1 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `tut_regra_truque` | Mas cuidado! Às vezes eu mexo os braços ao contrário para enganar vocês. Escutem a minha voz! | 1 | P1 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `tut_regra_fim` | Quem errar sai da brincadeira. Quem ficar por último vence! Vamos lá? | 1 | P1 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |

## 7. Menu sem tocar na tela (gestos) — só se aprovarmos a ideia

| ID | Texto | Variações | Prior. | Direção |
|---|---|---|---|---|
| `nav_menu_jogar` | Levantem o braço direito para jogar. | 1 | P2 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `nav_menu_proximo` | Levantem o braço direito para a próxima opção. | 1 | P2 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `nav_menu_voltar` | Levantem o braço esquerdo para voltar. | 1 | P2 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
| `nav_menu_escolha_nivel` | Escolham o nível! | 1 | P2 | Calmo e simpático, pausado, como quem explica para uma criança de 5 anos e um avô ao mesmo tempo. |
