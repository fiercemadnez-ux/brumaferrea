# Interiores procedurais e mapa de cidade

## Entrar em construções
- Aproxime-se da entrada frontal calculada para o objeto `settlement_XX_building_YYY_tipo` e pressione `F`.
- O interior é construído por código quando é aberto e removido quando se sai.
- Pressione `F` novamente para regressar ao exterior.
- A posição e a rotação do jogador são restauradas na saída. Enquanto estiver dentro, o mapa 3D externo e a chuva ficam ocultos, e as rotinas do overworld, os spawns e o clima ficam pausados para evitar que o mundo exterior apareça dentro da sala.
- O layout é determinístico por ID do edifício, portanto voltar a entrar na mesma construção mantém o mesmo arranjo nesta versão.

## Layout por tipo
- `house`: cama, mesa, cadeira, baú e lareira.
- `shop`: balcão de atendimento, prateleiras e caixas de mercadorias.
- `workshop`: bancada, bigorna, fornalha, suporte de ferramentas e caixa de minério.
- `inn`: balcão, mesas, bancos e barril.
- `town_hall`: mesa de conselho, bancos, quadro de avisos e baú.
- Outros tipos recebem o layout residencial genérico até terem um conjunto específico.

Os móveis e o invólucro usam meshes e colisões simples do Godot, sem adicionar assets externos. É uma primeira camada funcional; ainda não foi ligada à presença física de funcionários dentro de cada interior.

## Zoom do mapa
- Pressione `M` para abrir o mapa; a roda do mouse aumenta ou diminui o zoom.
- O mapa começa com a visão do continente. Ao aproximar, o foco se desloca para a cidade mais próxima do jogador (ou para a cidade do edifício em que ele estiver).
- O zoom médio mostra símbolos de comércio, oficinas, estalagens e salões comunais. Em zoom mais próximo (a partir de 3,8x), os estabelecimentos recebem nomes; isso reduz a sobreposição de rótulos quando a cidade ainda está distante.
- Em zoom alto aparecem também ícones de residências, sem rótulos individuais para evitar sobrecarga visual. O zoom máximo é 9x.
- Os marcadores vêm dos registros reais de construção do GLB, usando os nomes de objeto `settlement_XX_building_YYY_tipo`.

## Limites conhecidos
- Interiores são instâncias locais geradas em posição isolada acima do terreno; o jogador é teletransportado entre a porta exterior virtual e a sala.
- Não há ainda NPCs simulados dentro das salas, inventários físicos de cada loja, portas animadas ou save permanente do estado dos móveis.
- O mapa permite zoom por roda do mouse, mas ainda não tem arrasto livre nem seleção de qualquer cidade por clique.


## Construções reconhecidas no mapa atual
A versão atual do GLB fornece registros para 382 construções categorizadas: 261 casas, 57 lojas, 38 oficinas, 13 estalagens e 13 salões comunais. Esses números vêm dos nomes dos objetos no modelo, não de marcadores inventados pelo mapa.


## Interação por mira e porta de saída

A interação externa agora usa a mira central da câmera: o jogador precisa apontar para um NPC, para a fachada/porta da construção ou para a entrada da cripta e pressionar **F**. Proximidade isolada não aciona mais interações, e obstáculos bloqueiam a seleção quando impedem a linha de visão.

Dentro de uma construção há uma porta fechada com colisão física. O jogador só sai ao apontar a mira diretamente para essa porta e pressionar **F**; mirar em móveis ou pressionar F sem olhar para a saída não encerra a visita. O prompt de interação e a mira ficam dourados quando há um alvo válido.

## Rotinas domésticas e moradores presentes

Os NPCs usam o calendário diário da sociedade para decidir quando se recolher, trabalhar, patrulhar ou circular pela cidade. Os habitantes não deixam todos as casas no mesmo instante: cada identidade recebe um pequeno deslocamento horário estável, mantendo a rotina consistente sem formar uma fila única nas portas.

Ao chegar à entrada residencial, o NPC faz uma curta transição até o lado interno da fachada; sua posição lógica passa a ser `is_at_home`, e ele sai da simulação física enquanto estiver recolhido. Ao retomar uma atividade fora de casa, atravessa o mesmo plano da porta em sentido inverso antes de iniciar a rota pela cidade. Para habitantes distantes, a transição é simulada de forma abstrata para não gastar física desnecessária.

Quando o jogador entra numa casa durante um período em que há residentes em casa, o sistema move temporariamente os próprios nós dos moradores para posições livres do interior procedural. Eles continuam usando seus IDs e métodos de diálogo originais. Ao sair, voltam ao estado doméstico oculto; se um contratante tiver uma missão pronta para entregar, ele permanece acessível junto à porta. A simulação exterior retoma no próximo ciclo de atualização de rotinas.

Os interiores continuam gerados sob demanda. A presença dos moradores depende da rotina: um NPC que está no trabalho ou passeando não é teleportado para sua residência só porque o jogador entrou nela.
