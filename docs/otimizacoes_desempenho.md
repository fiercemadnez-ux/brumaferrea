# Otimizações de desempenho — Os Cânticos dos Sete: Brumaférrea

Esta revisão prioriza máquinas modestas e o renderer Compatibility do Godot 4.6. As mudanças são focadas em reduzir picos de CPU durante a exploração e em cidades povoadas.

- A simulação de pontos de spawn é verificada em intervalos de 0,25 s; referências a inimigos destruídos são removidas dos arrays em lugar de gerar arrays temporários com `Array.filter()`.
- A atualização de streaming/rotina dos NPCs ocorre em passos de 0,5 s e o plantel de guardas é reconstruído a cada 4 s.
- A separação dos NPCs usa uma grade espacial de células de 5,5 m. A cada atualização, cada habitante recebe apenas candidatos das nove células vizinhas; isso substitui a comparação quadrática entre todos os NPCs por consultas locais. A física do NPC continua filtrando os candidatos pela distância real.
- Os NPCs não executam `_process()` quando não têm uma fala ambiente ativa; a atualização do temporizador só é ligada durante a exibição de uma fala.
- A serialização completa da sociedade deixou de ocorrer a cada conversa, rumor, interação, entrega de missão ou chegada de mercador. Essas alterações são mantidas em memória e persistidas no checkpoint periódico (30 s) e ao sair da cena. Isso evita várias gravações síncronas em sequência durante conversas e combate.
- A máscara de umidade do clima usa resolução 32×32 e atualiza a textura a cada 3 s. A chuva CPU foi reduzida para 280 partículas.
- A iluminação pontual dinâmica das lanternas limita-se às 12 fontes mais próximas num raio de 145 unidades, com alcance de 9,5; materiais emissivos só são alterados quando a iluminação muda de forma perceptível.
- As colisões dinâmicas das construções deixam de ser criadas a distâncias de renderização de 500–600 m. Colisões de edifícios são solicitadas num raio de 165 m, marcos num raio de 180 m e demais malhas num raio de 140 m, com histerese de 42 m. O carregamento processa uma colisão por atualização a cada 0,25 s; a inicialização prepara somente duas colisões próximas.
- As distâncias de renderização foram ajustadas para 420 m em edifícios, 480 m em marcos e 135 m em detalhes, reduzindo a quantidade de objetos visíveis simultaneamente.
- A geração procedural de vegetação cede o frame a cada quatro amostras de terreno, em vez de doze. A criação das MultiMesh de grama, flores, arbustos e insetos é distribuída por frames separados para evitar um pico único no fim de cada bloco.
- A máscara de albedo do terreno é normalizada para `RGBA8` uma única vez na inicialização. Se a textura importada vier comprimida e não puder ser descomprimida, o sistema tenta carregar a imagem-fonte PNG; a amostragem evita chamar `get_pixel()` numa imagem comprimida.
- A atualização da mira ignora NPCs, recursos, entradas e edifícios fora do alcance antes de avaliar candidatos; para edifícios, só verifica os dados de interior depois do filtro de distância. A limpeza de referências de inimigos usa remoção in-place em vez de criar arrays temporários.

## Validação

As mudanças foram inspecionadas estaticamente, e o ZIP final foi verificado estruturalmente. O executável do Godot 4.6 não está disponível neste ambiente, então não foi possível medir FPS/frametime nem validar o Profiler em runtime. Para identificar o gargalo dominante no computador-alvo, comparar Debugger > Profiler e Rendering > Frame Time, principalmente ao entrar em cidades, chover, gerar vegetação e durante conversas entre NPCs.
