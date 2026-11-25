# Sistema de identidade, residências e rotinas de NPCs

## O que foi adicionado

- `scripts/npc_society.gd` reúne os registros das cidades, edifícios, residências e moradores.
- `scripts/npc.gd` mantém os diálogos e sprites existentes e acrescenta identidade estável, deslocamento e rotinas diárias.
- `scenes/npc.tscn` usa `CharacterBody3D` para permitir a movimentação dos NPCs.
- `scripts/overworld.gd` registra as cidades do mapa, identifica os edifícios pelos nomes exportados do Blender e inicializa o sistema social.

## Identificadores derivados do mapa

O ID da cidade vem de nomes como `Settlement_01_Thornstead`. Esse nome é apenas um identificador técnico do GLB: o nome mostrado ao jogador, aos NPCs e nas missões é obtido do catálogo `scripts/world_names.gd`, sem expor o sufixo em inglês do marcador. Casas e locais de trabalho são descobertos por nomes como `ow..._settlement_01_Building_005_house`, `..._shop`, `..._workshop`, `..._town_hall` e `..._inn`.

Um ID residencial tem a forma `settlement_01/building_005`. Um habitante gerado para a cidade usa um ID estável como `npc:settlement_01:resident_01`. Esses IDs não dependem do nome de exibição, então renomear o município não quebra o vínculo entre seus moradores e suas casas, desde que o identificador numérico do assentamento e o número do edifício sejam preservados.


## Nomes procedurais portugueses

Os nomes próprios e apelidos são combinados a partir de repertórios lusófonos escritos em português, incluindo acentos, sobrenomes compostos e algumas formas regionais ligadas à paisagem de Brumaférrea. A escolha usa o ID estável do NPC, portanto não muda aleatoriamente a cada carregamento. O gerador evita repetir um nome completo já atribuído a outro registro. Na primeira carga após a atualização, nomes antigos que não correspondem ao novo repertório são migrados; nomes já válidos são preservados. O gênero usado para selecionar nome e sprite continua coerente com o perfil do personagem.

## Dados acessíveis em cada NPC

- `npc_id`
- `city_id`, `origin_city_id` e `city_name`
- `home_id`, `home_name` e `home_position`
- `household_member_ids` e `household_member_names`
- `home_information()`, `knows_city()`, `knows_house()` e `knows_household_member()`

O registro central também permite consultar `get_residents_of_house(house_id)`, `get_residents_of_city(city_id)`, `get_house_record(house_id)` e `get_city_record(city_id)`.

## Rotina atual

- Ferreiros, mercadores e curandeiras deslocam-se ao local de trabalho durante o dia.
- Guardas percorrem pontos públicos durante o turno.
- Outros habitantes circulam entre pontos de interesse da cidade.
- À noite, os NPCs regressam à residência e deixam de aparecer no espaço público; ao amanhecer, saem novamente.
- As identidades, nomes e IDs residenciais são gravados em `user://npc_society_state.json` e recuperados na próxima sessão.

## Limite visual atual

Os edifícios do mapa atual são malhas exteriores sem interiores ou portas interativas. Por isso, a entrada/saída é representada por um ponto de acesso calculado no exterior da casa, usando a orientação frontal exportada pelo Blender para escolher o lado da fachada voltado para a rua: ao chegar, o NPC fica oculto, mas continua registrado como residente; ao sair, reaparece nesse mesmo ponto. Quando houver cenas interiores e portas reais, os mesmos IDs e registros poderão ser conectados a elas.


## População escalável

`get_population_target(city_id)` estima quantos residentes gerar com base na quantidade de casas, lojas e oficinas do assentamento, limitando o resultado a 6–24 habitantes por cidade. `overworld.gd` distribui funções essenciais nos primeiros residentes e preenche o restante majoritariamente com aldeões.

## Tarefas procedurais

`scripts/procedural_quests.gd` integra-se à árvore de diálogo do NPC. Os trabalhos são gerados na primeira conversa, tendo como base o papel do contratante e a escala da cidade. O jogador pode manter até cinco tarefas de caça ativas, consultar o progresso com **J** e entregá-las ao NPC que as ofereceu. O progresso e as recompensas vivem apenas em memória durante a sessão.


## Relações e conversas contextualizadas (versão 4 do estado social)

- `npc_society_state.json` mantém agora também um dicionário `relationships`, com um registro por par de NPCs: familiaridade, afinidade, quantidade de conversas, progresso romântico, etapa da relação, último assunto e contagem de tópicos. Registros antigos sem esse campo continuam sendo carregados como antes.
- As relações progridem de desconhecidos para conhecidos, amigos e amigos próximos conforme os habitantes conversam. Casais só podem se formar depois de vários encontros entre adultos de gêneros diferentes, com familiaridade e afinidade suficientes; cada NPC pode ter no máximo um parceiro registrado.
- O ID do parceiro também fica no perfil persistente e no objeto do NPC, permitindo que diálogos, rotinas e sistemas futuros consultem o vínculo.
- A conversa ambiente agora seleciona um tópico e constrói as três falas como abertura, resposta relevante e encerramento do mesmo assunto. Eventos testemunhados, perigos regionais, chuva/tempestade, trabalho, convivência doméstica, guardas e interesses pessoais usam respostas contextualizadas. Os pares alternam assuntos para reduzir a repetição imediata.
- A relação influencia a chance de os mesmos habitantes conversarem de novo; casais têm diálogos específicos em parte dos encontros, sem impedir que falem sobre notícias, clima ou perigo.
- **Limite desta etapa:** o registro de casal está implementado, mas nascimento de filhos, árvore genealógica, envelhecimento e mudança de profissão na idade adulta ainda não foram implementados. Isso exigirá calendário persistente e integração do ciclo de vida com a criação/remoção de NPCs no overworld.

## Estado de vida, salvamento e retorno à cidade

O estado persistente agora inclui também a atividade e a posição lógica de cada NPC no mundo exterior. O registro distingue moradores em casa, trabalhando, circulando em público e mercadores em viagem. Coordenadas de interiores temporários não são gravadas como se fossem posições externas. O estado é salvo periodicamente e novamente quando o nó de sociedade sai da árvore, para reduzir a chance de o habitante reaparecer em casa depois de o jogador encerrar a sessão.

O relógio acumulado e os horários previstos de partida dos mercadores também entram no salvamento. A restauração valida a cidade associada à posição; quando o estado antigo não combina com o assentamento atual, o NPC volta a uma posição segura definida pela rotina.

## Relação individual com o jogador

Cada NPC mantém um registro próprio de familiaridade, confiança, gratidão, conversas, cidade e hora do último encontro, além de contagens de missões concluídas, atos heroicos testemunhados e rodadas pagas na estalagem. A familiaridade não cresce de forma relevante apenas por abrir repetidamente a conversa. Completar um trabalho diante/para o contratante melhora a relação com essa pessoa; moradores que presenciam o jogador derrotar uma criatura podem ajustar sua confiança. A saudação considera parte desse histórico persistente.

## Eventos do mundo, memória e rumores

O sistema registra acontecimentos como criaturas avistadas ou derrotadas, trabalhos concluídos e gestos sociais. Cada memória distingue testemunho, recebimento direto e informação ouvida de outra pessoa. Quando conversam sobre um evento, os habitantes transmitem a informação apenas a quem ainda não a conhece; o registro recebido identifica quem contou, quantas transmissões já ocorreram e a confiança restante. A confiança diminui a cada passagem e a transmissão é limitada a três etapas. As falas deixam explícito quando o NPC está repetindo um relato em vez de afirmar que viu o acontecimento pessoalmente.

O sistema de rumores funciona nas conversas locais entre habitantes materializados. **O transporte completo de notícias por mensageiros entre cidades ainda não está implementado**: os mensageiros já existem como profissão/rotina, mas a entrega de conhecimento entre assentamentos precisa ser conectada a viagens e tempos de percurso. Nascimento de filhos, envelhecimento e a atualização de papéis conforme as fases da vida também continuam como trabalho futuro.
