# Efeitos sonoros do jogador

Os efeitos ficam em `assets/sound/sfx/player/` e são disparados pelo `scripts/player.gd`.

- `woosh.mp3`: toca quando um ataque corpo a corpo válido começa, acompanhando o movimento da arma.
- `swordhit.mp3`: toca quando um golpe de espada acerta uma criatura.
- `daggerhit.mp3`: toca quando um golpe de adaga acerta uma criatura.
- `hit.mp3`: impacto genérico para punhos, machado e lança, e para golpes corpo a corpo que atingem uma superfície sólida.
- `footsteps.mp3`: toca ao caminhar ou correr, usando a distância realmente percorrida e apenas quando o jogador está no chão durante a exploração. A cadência acelera ao correr; não toca em menus, durante saltos ou quando o jogador está parado/encostado numa parede.

O sistema usa cinco vozes reutilizáveis para permitir sobreposição curta de efeitos sem criar nós a cada som. O impacto toca apenas uma vez por golpe, mesmo quando o ataque atinge vários inimigos, para evitar uma explosão de áudio. Pequena variação de pitch reduz a repetição mecânica. Os ganhos por efeito compensam as diferenças de nível dos MP3 originais, sem alterar os arquivos de áudio; o arquivo de passos recebe ganho de 10.0 dB, conforme o ajuste de volume solicitado.

No momento, os passos usam o mesmo arquivo em todas as superfícies, pois há apenas uma gravação de passos disponível. Sons diferentes para grama, pedra, madeira, água ou neve podem ser adicionados quando houver gravações específicas.
