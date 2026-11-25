# Vegetação baixa e trilhas de passagem

## Máscara geográfica

O `scripts/environment_details.gd` tenta primeiro obter a textura de albedo diretamente do material ativo de `OW_Terrain`. Como o sufixo numérico do arquivo `overworld_OW_TerrainAlbedo_*.png` muda quando o modelo é exportado novamente do Blender, o sistema procura automaticamente uma textura compatível em `assets/world` se o material não expuser a imagem. A máscara está alinhada ao UV de 0–1 do terreno: X mapeia da esquerda para a direita e Z de cima para baixo.

Só são aceitos pixels verdes (canal G claramente maior que R e B). Isso permite capim, flores, arbustos e desgaste de trilhas apenas sobre as áreas verdes pintadas no mapa. Água azul, areia bege, rocha cinza e as estradas/marcas marrons pintadas na textura são rejeitadas. Uma pequena margem de segurança de 1,5 m ao redor do ponto também precisa continuar verde, para reduzir vegetação nas bordas de praias, rochas e estradas.

Se a textura da máscara não puder ser carregada, o sistema deixa de criar vegetação e trilhas em vez de distribuí-las sem restrição.

## Vegetação

O sistema acrescenta tufos de capim, flores silvestres e arbustos baixos. A geração acontece em setores de 48 m, de forma incremental, e agrupa a decoração em `MultiMeshInstance3D` para limitar o custo de renderização. Os detalhes são somente visuais, sem colisão; árvores e geometria original do Blender permanecem intactas.

Além da máscara verde, a colocação verifica a altura e a inclinação do terreno, evita a água, os centros dos assentamentos e as caixas de construções/pontos de interesse.

## Trilhas dinâmicas

O jogador e NPCs ativos/visíveis são amostrados durante o movimento. Cada trecho acumula tráfego quando alguém o atravessa; pequenas repetições do mesmo ator em sequência não contam como passagens novas. Ao atingir `TRAIL_VISIBLE_AT`, surge uma marca irregular de grama pisoteada/terra exposta e os tufos próximos são removidos do MultiMesh. O desgaste aumenta com novas passagens.

As trilhas consultam a mesma máscara geográfica da vegetação. O desgaste só é acumulado sobre áreas verdes; não são criadas marcas de grama pisoteada sobre estradas desenhadas, areia, rocha ou água. Dados antigos de trilhas também são filtrados ao inicializar o sistema.

Os NPCs simulados fora da área ativa não desenham linhas artificiais: somente o deslocamento físico visível é registrado. Trilhas ficam em memória durante a sessão e entre novas tentativas, mas não são gravadas em arquivo de save.

## Ajustes rápidos

No topo de `environment_details.gd`:

- `LOAD_RADIUS`: distância em que os setores de vegetação são criados.
- `UNLOAD_RADIUS`: distância para liberar os setores decorativos distantes.
- `GRID_RESOLUTION`: densidade das posições candidatas de vegetação por setor; subir o valor cria mais detalhes e custa mais processamento durante a geração.
- `GREEN_MASK_FILE_PREFIX`: prefixo usado na busca de uma máscara de terreno alternativa; preferencialmente é usada a textura ligada ao material real de `OW_Terrain`.
- `GREEN_MASK_EDGE_CLEARANCE`: distância de segurança para manter vegetação e trilhas longe de bordas de áreas verdes, estradas, água, areia e rocha.
- `TRAIL_VISIBLE_AT`: tráfego acumulado necessário antes da trilha ficar visível.
- `TRAIL_CELL_SIZE`: resolução espacial das marcas de passagem.
- `TRAFFIC_SAMPLE_INTERVAL`: intervalo de amostragem do movimento.
