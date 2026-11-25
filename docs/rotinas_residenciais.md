# Rotinas residenciais dos NPCs

## Correção de entrada pela porta

- O limite de chegada para o objetivo `home` é 1,10 m. A cápsula de colisão do NPC não pode encostar na parede; o limite anterior de 0,72 m era menor que a distância residual até a posição de entrada, deixando habitantes travados diante da fachada.
- O cálculo de espaço livre para entradas usa o footprint local orientado da construção, não a AABB mundial ampliada de edifícios girados. Isso evita que uma caixa delimitadora conservadora empurre virtualmente a entrada metros para fora da porta.
- Na busca de rotas para casa, a construção de destino deixa de ser considerada obstáculo apenas para a ligação final que chega pelo lado externo da fachada. O sistema continua bloqueando rotas que tentem atravessar a casa ou chegar pelo lado posterior.

Os NPCs continuam usando as identidades e rotinas existentes; a transição para dentro/fora da residência permanece controlada pelo estado `home`.


## Aproximação de portas e escadas

Os destinos de NPCs associados a entradas agora informam ao roteador qual construção
está sendo alcançada, inclusive lojas/oficinas e pontos públicos visitados durante o dia.
O algoritmo pode contornar essa construção e conectar-se ao destino somente pelo lado
frontal. Se a rota direta até as escadas não puder ser conectada, tenta um ponto de
aproximação mais afastado na rua antes do último trecho.

O `CharacterBody3D` dos NPCs também possui uma assistência limitada para degraus baixos: só
é ativada quando o avanço horizontal colide, há espaço acima da cápsula e um piso
transitável confirma o pouso dentro de 0,68 m. Isso permite subir os degraus das casas sem
permitir saltar muros altos ou andar para fora de bordas. Os pontos de trabalho são
posicionados adiante e ao lado das escadas, mantendo desimpedido o corredor de entrada.
