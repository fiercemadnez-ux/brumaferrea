# Sprites de armas em primeira pessoa

O jogador usa um `TextureRect` ancorado ao canto inferior direito para desenhar a arma equipada. A sequência de ataque avança uma vez a cada 0,10 s; o dano é aplicado quando o último frame aparece, e esse quadro permanece visível por mais 0,10 s antes do retorno à pose de repouso.

| Arma | Repouso | Sequência | Escala inicial | Margem direita inicial |
|---|---|---|---:|---:|
| Punhos | `fist/fist/0-0.PNG` | `2-0` a `2-4` | 4.5 | -5 px |
| Espada | `swords/sword/0-0.PNG` | `1-0` a `1-4` | 5.0 | 18 px |
| Adaga | `dagger/0-0.PNG` | `6-0` a `6-4` | 5.0 | 18 px |
| Machado | `axe/0-0.PNG` | `2-0` a `2-4` | 5.0 | 18 px |
| Lança | `spear/0-0.PNG` | `6-0` a `6-4` | 5.0 | 18 px |

As escalas e margens ficam no início de `scripts/player.gd`. A rotina verifica a existência de todos os arquivos antes de habilitar o sprite; se o conjunto estiver incompleto, preserva o modelo 3D existente como fallback.

**Nota de pacote:** a versão de projeto usada para esta alteração ainda não continha os PNGs de adaga, machado e lança. Os caminhos e as animações já estão ligados no código, mas esses três conjuntos precisam estar presentes nas pastas `assets/player/weapons/dagger/`, `assets/player/weapons/axe/` e `assets/player/weapons/spear/` para que o sprite seja ativado.
