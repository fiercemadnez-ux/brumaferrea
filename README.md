# As Criptas de Vel'Morah — versão com sistema social de NPCs

Projeto Godot 4.6. Abra esta pasta pelo `project.godot`.

## Sistema de NPCs incluído

- Cada NPC tem um identificador persistente, nome, cidade natal/atual, profissão e residência.
- As casas e edifícios são descobertos pelos nomes presentes em `assets/world/overworld.glb`.
- Cada casa mantém uma lista de residentes; cada NPC recebe a lista de pessoas que moram com ele.
- Os moradores têm rotinas básicas de trabalho, patrulha, circulação diurna e retorno noturno para casa.
- Os vínculos são salvos em `user://npc_society_state.json`.
- O sprite e os diálogos existentes foram preservados.

Os edifícios do mapa atual não possuem interiores nem portas interativas. Nesta versão, o acesso à casa é representado por um ponto exterior: o NPC some do espaço público ao chegar e reaparece nesse ponto ao sair. O registro residencial permanece ativo.

Veja `docs/npc_society_system.md` para detalhes de implementação e API.

Observação: este pacote foi revisado estaticamente, mas não pôde ser executado no editor Godot neste ambiente.

## Correção da saída da loja
- A entrada de teclado agora encaminha teclas para `handle_shop_key()` enquanto a fase é `shop`.
- `Esc` e `F` fecham a loja como indicado na interface; `1`–`9` continuam selecionando itens.
- Ao fechar, o sinal `closed` chama `_on_shop_closed()` e retorna à fase de jogo.

## Persistência do personagem durante a sessão
- Ouro, poções, armas, armaduras, magias aprendidas e equipamento atualmente selecionado ficam no objeto do jogador durante toda a sessão.
- Morrer e escolher “Tentar de novo” (ou reiniciar depois da vitória) restaura vida e mana, mas não apaga inventário, ouro ou seleções.
- Não foi adicionado salvamento em disco para o jogador: ao fechar o jogo, esse progresso de sessão é descartado.

## População proporcional e tarefas procedurais

- O número de moradores de cada cidade é calculado a partir das casas, lojas e oficinas encontradas no GLB, com um limite de 24 NPCs por cidade para preservar o desempenho. No GLB atual, os 13 assentamentos geram cerca de 167 habitantes no total; cidades maiores recebem mais gente e aldeias pequenas, menos.
- Toda cidade gera um conjunto básico de profissões e uma maioria de moradores comuns; cidades maiores recebem mais habitantes. Identidades, residências e rotinas continuam ligadas aos IDs dos edifícios.
- `scripts/procedural_quests.gd` gera trabalhos de caça conforme a profissão do contratante e o porte da cidade. Objetivos usam somente os tipos de inimigos presentes no projeto (ratos gigantes, morcegos, goblins, esqueletos e orcs).
- Até cinco tarefas podem ficar ativas ao mesmo tempo. Derrotar os alvos no overworld atualiza o progresso; voltar ao contratante permite receber ouro e, em alguns trabalhos, poções. Inimigos da cripta não contam, pois o fluxo atual não tem uma saída da dungeon que permita voltar ao contratante.
- Pressione **J** para consultar o diário. As tarefas ficam em memória durante a sessão e não são gravadas em disco. Como ainda não existe retorno da cripta para o overworld, só os monstros derrotados no mundo aberto contam para essas caçadas.

O pacote recebeu uma revisão estática; o motor Godot 4.6 não estava disponível neste ambiente para executar uma validação de runtime.


## Streaming por proximidade e diário de aventura

- Os edifícios e marcos que têm meshes individuais usam distância máxima de renderização com transição por dithering; isso reduz a quantidade de objetos desenhados ao mesmo tempo sem depender apenas do alcance geral da câmera.
- A distância para ativar cada colisão acompanha o alcance visual daquele tipo de objeto: os colisores começam a ser criados antes de a mesh aparecer e são removidos depois que ela sai da área visível. A criação acontece em pequenos lotes para evitar um pico grande de CPU ao entrar numa cidade. O terreno mantém sua colisão para não haver quedas através do mapa.
- NPCs distantes ficam ocultos e com o processamento físico desativado; sua rotina diária usa simulação simplificada. Ao se aproximar, voltam ao mundo. Inimigos distantes pausam renderização, colisão e IA e retomam quando o jogador chega perto.
- A janela **Diário de Aventura** (J) tem filtros para tarefas ativas, disponíveis e concluídas, detalhes, progresso, recompensa e controle de rastreamento.
- Ao rastrear uma missão, o mapa (M) mostra uma estrela dourada na zona de caça; quando o objetivo é concluído, ela aponta de volta para a cidade do contratante. O rastreamento pode ser removido no diário.
- As entradas de cripta só aparecem no mapa depois de descobertas em exploração. O arco de entrada e sua etiqueta também deixam de aparecer à distância.

**Limite atual do streaming:** o arquivo `overworld.glb` ainda é carregado como uma única cena e o terreno visual é uma única malha. Esta melhoria faz culling de renderização por edifício/marco e streaming de colisões/entidades, mas não descarrega o terreno distante da memória. Para streaming real de terreno em blocos, o addon Blender precisa exportar tiles de terreno separados.

## Spawn natural de inimigos e turnos da guarda

- Os pontos de spawn começam com uma janela curta (0–1,6 s) e, depois de um nascimento válido, usam um intervalo de 8–15 s. Uma tentativa que falha é repetida em 0,65–1,8 s em vez de ativar o cooldown longo.
- Os temporizadores continuam correndo mesmo quando o jogador está longe. Ao entrar no alcance de um spawn ativo, os inimigos podem surgir rapidamente; um intervalo global de 0,42 s evita que diversos pontos criem monstros no mesmo frame.
- Cada ponto de spawn mantém no máximo dois inimigos e o sistema limita a oito inimigos próximos ao jogador para preservar o desempenho e evitar enxames instantâneos.
- As guardas seguem três turnos (06:00–14:00, 14:00–22:00 e 22:00–06:00). Em cidades com mais guardas, os turnos se revezam e os que estão fora de serviço voltam para casa. Cidades pequenas mantêm seu único guarda em serviço, alternando entre posto e ronda.
- Como o GLB atual não contém marcadores explícitos de portões, quatro postos virtuais são posicionados no perímetro do conjunto de edifícios de cada cidade. Guardas em serviço revezam entre esses postos e rotas de ronda pelos pontos públicos da cidade.

O projeto não pôde ser executado no Godot neste ambiente; as mudanças foram revisadas estaticamente e devem ser testadas no editor Godot 4.6.

## Simulação de ameaças regionais

- `scripts/regional_threats.gd` mantém um valor de ameaça (0–100) por cidade e por célula de ermos. Cada região apresenta um estado: Tranquila, Inquieta, Em alerta, Perigosa ou Crítica. A ameaça inicial considera zonas de spawn e criptas próximas.
- O sistema regista o surgimento de monstros, as mortes e a descoberta de criptas. A presença de inimigos aumenta a pressão regional ao longo do tempo; derrotá-los e concluir trabalhos de defesa reduz a ameaça. Há recuperação passiva gradual quando a região está menos pressionada.
- Em regiões ameaçadas, os spawns ficam mais frequentes e a seleção dá mais peso a goblins, esqueletos e orcs. O número máximo de inimigos próximos aumenta apenas em níveis de ameaça elevados, respeitando limites de desempenho.
- A guarda ajusta os turnos conforme a crise: mais guardas permanecem em serviço em regiões perigosas. Moradores não guardas recolhem mais cedo durante períodos de perigo.
- Ao conversar com habitantes quando uma região está suficientemente ameaçada, podem ser oferecidos contratos de defesa regional. Esses contratos contam apenas inimigos derrotados na região indicada; a entrega reduz a ameaça e recompensa o jogador.
- Ao entrar numa região ou quando o seu estado muda de categoria, o jogo apresenta uma breve mensagem de situação.
- A ameaça e a descoberta de criptas são mantidas apenas na memória durante a sessão. Não foi adicionado um save em disco; o estado persiste ao reiniciar uma tentativa enquanto o jogo continuar aberto.

**Verificação:** foram feitas revisões estáticas dos scripts e do pacote, mas o motor Godot 4.6 não está disponível neste ambiente; a compilação e o comportamento em runtime ainda precisam de ser testados no editor.


## Ajustes de ameaça regional e alvos de missão

- A ameaça regional é indicada por uma notificação temporária no canto superior esquerdo, em vez de um HUD permanente. Os avisos são exibidos em degraus de dez pontos.
- Ao aceitar uma missão de caça ou defesa, o sistema prepara imediatamente o grupo específico de inimigos no local do marcador antes de mudar a missão para ativa.
- Cada inimigo preparado recebe o ID da missão; apenas esses alvos aumentam o progresso daquele contrato, evitando que mortes aleatórias longe do objetivo contem.
- Se a cena do overworld for recriada após uma morte, os alvos restantes de contratos ativos são preparados novamente com base no progresso já registrado na sessão.
- Os alvos especiais respeitam áreas seguras e, em missões regionais, são mantidos dentro da região indicada.

A compilação em runtime ainda precisa ser confirmada no Godot 4.6; este ambiente não contém o executável do Godot.

## Ajustes de outubro: aviso de ameaça, spawns noturnos e portas das casas

- O painel permanente de ameaça foi substituído por uma notificação temporária de 3,6 segundos. Ela aparece quando a ameaça da região atual cruza uma nova faixa de dez pontos (0, 10, 20… 100); o valor mostrado é aproximado por faixas de dez, enquanto a simulação usa o valor exato.
- As regiões das cidades agora usam um raio calculado a partir do perímetro dos edifícios que realmente existem no GLB, mais uma margem curta. Os assentamentos maiores têm uma área um pouco maior; ao sair do perímetro urbano, o jogador passa para uma célula de ermos em vez de continuar usando o nível de ameaça da cidade até chegar a outro assentamento.
- À noite (20:00–06:00), a espera de respawn fica aproximadamente 38% menor, as tentativas de spawn inválidas são repetidas mais rapidamente e o cooldown global cai. O limite local de inimigos também aumenta em dois, mantendo um teto definido.
- Os pontos de entrada/saída das casas agora respeitam a orientação da mesh de cada edifício exportada pelo Blender. A posição exterior é colocada no lado frontal da construção, normalmente voltado para a rua; ao entrar, o NPC desaparece no ponto da porta, e ao sair reaparece nesse mesmo acesso.

O motor Godot 4.6 não está disponível neste ambiente. O ZIP passou pelas verificações de integridade e os scripts alterados por verificações estáticas, mas a compilação e o teste visual das portas precisam ser confirmados no editor.

## Correção de acesso às residências e ameaça no mapa

- O indicador de ameaça regional deixou de ser criado no HUD de exploração. A leitura da região atual (nome, estado, valor em faixas de dez e barra colorida) agora aparece no menu do mapa (M).
- Os pontos exteriores das residências agora são calculados no centro da fachada frontal usando a orientação exportada pelo modelo, em vez de selecionar um dos quatro lados da caixa delimitadora.
- As rotinas de NPC usam um grafo de visibilidade simples com cantos ao redor das construções e entradas públicas como pontos intermediários. Isso reduz trajetos que cortavam edifícios ao ir para casa, trabalho ou postos de guarda.
- Um NPC só passa ao estado `is_at_home` depois de alcançar o ponto de acesso exterior. A residência e os membros da casa continuam registrados; os interiores ainda são simulados porque não existem cenas internas no projeto.

O ZIP foi verificado quanto à integridade e os scripts alterados foram revisados estaticamente. O motor Godot não está disponível neste ambiente para confirmar a compilação e a movimentação em runtime; teste especialmente os retornos para casa e as entradas de casas próximas umas das outras.

## Correção de entradas residenciais e ameaça no mapa

- O NPC agora calcula o ponto de entrada usando a profundidade local da construção e a direção frontal exportada pelo Blender. Isso evita que casas rotacionadas recebam um ponto de acesso excessivamente distante por causa da caixa delimitadora mundial.
- O ponto virtual de porta fica perto o bastante da fachada para que a cápsula do NPC consiga alcançá-lo mesmo quando a colisão da casa não contém uma abertura física. Ao alcançar esse ponto, a simulação faz a transição para dentro; ao sair, o NPC reaparece no mesmo ponto frontal e segue sua rotina.
- As chegadas aos destinos finais de casa, trabalho e posto aceitam uma tolerância maior, sem relaxar a precisão dos waypoints usados para contornar edifícios.
- A ameaça regional não aparece no HUD durante a exploração. O painel com nome da região, estado, valor e barra de perigo fica disponível no menu do mapa.
- O projeto ainda não contém interiores navegáveis. A entrada/saída é uma transição simulada no ponto da fachada, não uma cena interior real.
