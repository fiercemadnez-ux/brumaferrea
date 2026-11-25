# Brumaférrea — seed do mundo e localização da bruxa

- **World Seed:** `16983215`
- **Modelo usado pelo jogo:** `assets/world/overworld.glb`
- **Indício arquivado no projeto:** os mapas de textura do terreno usam nomes como `overworld_OW_TerrainAlbedo_16983215_...png`, contendo a seed recuperada.

## Localizações possíveis da bruxa única

A localização é escolhida uma única vez por mundo salvo e fica persistida no estado do mundo:

1. **Casa da Bruxa:** usa o nó `OW_WitchHut` do `overworld.glb`. A personagem aparece do lado de fora da construção, próxima à casa, evitando nascer dentro da malha/colisão.
2. **Margem do lago:** coordenadas do mapa **X = -954, Z = 465**; a altura é ajustada ao terreno.

A bruxa continua sendo única. Se morrer, não reaparece. Para compatibilidade com saves antigos, a opção antiga `lake` migra para `lake_edge`, e `forest` migra para `witch_house`.

**Nota:** este registro preserva a seed recuperada e os pontos usados pelo jogo; não substitui o arquivo `.blend` original nem garante reprodução bit a bit do mundo se o addon/configuração de geração for diferente.
