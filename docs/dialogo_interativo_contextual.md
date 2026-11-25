# Diálogo interativo contextual

As conversas iniciadas pelo jogador agora são construídas no momento da interação, no mesmo espírito das conversas autônomas entre habitantes. O menu deixa de apresentar assuntos fixos sobre criptas para todos os NPCs.

## Dados consultados

- Profissão e estabelecimento do NPC.
- Personalidade e número de conversas anteriores com o jogador.
- Horário do mundo, clima atual e nível/estado da ameaça regional.
- Acontecimentos que o NPC registrou perto de si, filtrados por cidade e pela janela de memória social.
- Composição conhecida da residência/família.
- Saúde e ouro atuais do jogador, quando isso muda a resposta ou o rótulo de uma opção.
- Estado dos contratos, oferecidos separadamente pelo gerenciador de tarefas existente.

## Opções condicionais

- Assuntos sobre acontecimentos recentes só aparecem quando o NPC tem uma memória pertinente.
- Perguntas sobre segurança só aparecem quando a ameaça regional está elevada.
- Comentários sobre o clima aparecem quando está chovendo ou há tempestade.
- Assuntos sobre a noite aparecem durante o período noturno.
- Perguntas sobre família aparecem quando existem nomes de outros moradores na residência.
- As opções de loja e profissão mudam conforme cargo, horário, saúde do jogador e ouro disponível.

O sistema é local e baseado em regras/dados do jogo. Não depende de serviços externos nem de uma API de IA. As falas e opções são montadas dinamicamente, mas o conjunto de templates ainda é escrito manualmente; novas profissões, eventos e relações podem ampliar o vocabulário depois.
