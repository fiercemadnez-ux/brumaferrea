# Água procedural dos rios — Godot 4.6

Esta versão substitui a faixa de água de largura fixa por uma superfície contínua, opaca e animada que tenta caber no canal existente do `OW_Terrain`.

## O que mudou

- A água usa a malha esculpida no Blender; o script de runtime não modifica `OW_Terrain` nem a colisão.
- A largura é calculada em cada seção a partir da altura real das duas margens. Se uma seção não encontrar margem acima da superfície, ela colapsa em vez de lançar uma lâmina sobre a encosta.
- O nível de água é limitado pela margem mais baixa e por uma folga de segurança. O perfil longitudinal é suavizado sem apagar o declive geral do rio.
- Cada percurso é orientado de montante para jusante comparando as alturas das pontas. Os UVs usam a distância acumulada ao longo da linha, então o shader anima a correnteza ao longo do próprio rio, não em uma direção global do mapa.
- O material é totalmente opaco, com reflexos moderados, variação estilizada de cor e faixas de correnteza discretas.
- A água não tem `CollisionShape3D`, `StaticBody3D` nem collider próprio.

## Instalação no projeto

1. Extraia o ZIP em uma pasta nova.
2. Abra o `project.godot` no Godot 4.6.
3. Execute o projeto e entre no overworld. `scripts/overworld.gd` já instancia `scripts/river_water_generator.gd`.

O código da água está em:

- `scripts/river_water_generator.gd`
- `shaders/river_water.gdshader`

## Importantíssimo para o alinhamento exato

O `river_paths.json` incluído nesta cópia foi originalmente recuperado das marcações azuis da textura do terreno, não dos dados de drenagem originais do arquivo `.blend`. O gerador tenta recentrar os pontos na depressão do terreno e restringe a água pelas margens, mas esta fonte legada ainda pode ter desvios locais.

Para percursos exatos no mundo gerado mais recentemente:

1. No Blender, instale `tools_blender/daggerfall_overworld_generator_v0_4_6.py`.
2. Gere o overworld correspondente ao GLB que será usado no jogo.
3. No painel Overworld, use **Exportar para Godot (.glb)** para substituir `assets/world/overworld.glb`.
4. Use **Exportar percursos dos rios (.json)** e salve por cima de `assets/world/river_paths.json`.
5. Reabra/importa o projeto no Godot.

O JSON exportado pelo objeto `OW_Rivers` inclui linhas centrais do solver, largura, raio de canal e profundidade. Isso evita qualquer necessidade de identificar rios pela cor de pixels e é a fonte recomendada para projetos futuros.

## Ajustes

No shader, `flow_speed` altera a velocidade da correnteza, `flow_streaks` controla a frequência das faixas e `roughness_value` controla a aspereza da superfície. As cores podem ser ajustadas em `deep_water_color`, `current_color` e `ripple_color`.

## Limitações de validação

O projeto foi revisado estruturalmente e a malha de água foi avaliada offline usando as dimensões e alturas do GLB incluído. O Godot 4.6 não está instalado neste ambiente, por isso não foi possível compilar o projeto nem verificar a aparência em execução. Faça um teste visual no motor após abrir esta cópia.
