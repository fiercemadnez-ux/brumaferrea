# Construções e iluminação — Os Cânticos dos Sete: Brumaférrea

O modelo `assets/world/overworld.glb` desta versão é o mundo atualizado, com construções nomeadas por assentamento e tipo. O sistema reconhece 17 tipos: casas, lojas, oficinas, estalagens, salão comunal, templo, biblioteca, enfermaria, posto da guarda, mirante, depósito, abrigo, estábulo, moinho, celeiro, poço e ruína.

As construções têm nomes localizados, descrições de conhecimento do mundo e contagem por cidade. Guardas procuram postos da guarda, mirantes e, se necessário, o salão comunal. Curandeiras preferem enfermarias. Aldeões podem receber trabalho em moinhos, celeiros, estábulos e depósitos, sem empilhar a população inteira numa mesma porta. Poços continuam sendo elementos exteriores, não interiores visitáveis.

Os interiores procedurais agora têm mobiliário específico para templos, bibliotecas, enfermarias, postos da guarda, mirantes, depósitos, abrigos, estábulos, moinhos, celeiros e ruínas.

## Lanternas

As 252 superfícies do material `OW_LanternGlow` presentes no GLB são usadas para emissão visível à distância. A emissão aumenta no crepúsculo, permanece durante toda a noite (inclusive depois da meia-noite) e diminui ao amanhecer. Um conjunto reutilizável de até 24 luzes pontuais `OmniLight3D` é reposicionado nas lanternas mais próximas do jogador para iluminar fachadas e chão. Assim o mundo não cria centenas de nós de luz inativos. Elas não projetam sombras e o número ativo é limitado para o renderer Compatibility.

A distância de renderização das construções foi ampliada para que elas continuem visíveis ao observar uma cidade, sem depender da colisão carregada. O pacote inclui o cache `.godot/imported` gerado para o GLB e suas texturas atuais; isso evita que a extração sobre uma cópia de projeto existente deixe em uso a cena importada do modelo anterior.
