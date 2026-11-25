# Nomenclatura geográfica — Brumaférrea

## Regra principal

Os nomes dos nós do `overworld.glb` são identificadores técnicos de Blender/Godot. Eles não são nomes canônicos e nunca devem ser apresentados diretamente ao jogador ou usados em diálogos.

O catálogo `scripts/world_names.gd` é a fonte de nomes e descrições de exibição. Os IDs técnicos continuam iguais para preservar vínculos com construções, rotas, saves, missões, pontos de interesse e registros dos NPCs.

## Cidades

| ID técnico | Nome de exibição |
|---|---|
| `settlement_01` | Espinhal |
| `settlement_02` | Raposeira |
| `settlement_03` | Falcária |
| `settlement_04` | Pedralva |
| `settlement_05` | Várzea da Raposa |
| `settlement_06` | Lobofrio |
| `settlement_07` | Verdevigia |
| `settlement_08` | Dunaforte |
| `settlement_09` | Corval |
| `settlement_10` | Negral |
| `settlement_11` | Serra Rubra |
| `settlement_12` | Prateira |
| `settlement_13` | Penedo Velho |
| `settlement_14` | Barroalto |
| `settlement_15` | Corveira |
| `settlement_16` | Cinzavala |
| `settlement_17` | Vilarégio |
| `settlement_18` | Espinheiral |
| `settlement_19` | Verdevale |
| `settlement_20` | Pouso dos Espinhos |
| `settlement_21` | Raposela |
| `settlement_22` | Ribeira Velha |
| `settlement_23` | Poente |
| `settlement_24` | Brejo dos Lobos |
| `settlement_25` | Solar Velho |
| `settlement_26` | Crista Rubra |
| `settlement_27` | Ponte dos Espinhos |
| `settlement_28` | Feira dos Corvos |

## Pontos de interesse

| ID técnico | Nome de exibição |
|---|---|
| `poi_001` | Acampamento do Vau Seco |
| `poi_002` | Ruínas de Pedrarrasa |
| `poi_003` | Santuário das Sete Pedras |
| `poi_004` | Gruta do Veado |
| `poi_005` | Torre da Vigia Alta |
| `poi_006` | Cripta do Penedo Oco |
| `poi_007` | Ruínas de Vale Morto |
| `poi_008` | Acampamento do Salgueiral |
| `poi_009` | Santuário da Pedra Muda |
| `poi_010` | Torre do Corvo |
| `poi_011` | Cripta de Ossafria |
| `poi_012` | Ruínas de Candeia |
| `poi_013` | Acampamento da Estrada Velha |
| `poi_014` | Gruta das Raízes |
| `poi_015` | Gruta do Eco Fundo |
| `poi_016` | Torre dos Ventos |
| `poi_017` | Ruínas de Vau Cinzento |
| `poi_018` | Santuário da Nascente |
| `poi_019` | Acampamento do Brejo Fundo |
| `poi_020` | Cripta da Boca Fria |
| `poi_021` | Oratório de Pedra Clara |
| `poi_022` | Gruta do Lobo |
| `poi_023` | Catacumba do Rei Esquecido |
| `poi_024` | Torre do Poente |

## Onde os nomes são aplicados

- `overworld.gd`: os marcadores de assentamento recebem o topônimo oficial antes de serem entregues aos demais sistemas.
- `npc_society.gd`: os pontos de interesse recebem nomes próprios antes de entrarem no conhecimento dos NPCs, nos rumores e nas conversas.
- `world_map.gd`: o mapa e o painel de seleção usam o catálogo como fallback, sem expor IDs.
- `game.gd`: a seleção de cidade natal, a descrição da cidade e o carregamento de campanhas antigas usam o catálogo.
- `regional_threats.gd`: anúncios de ataques e quedas de cidades usam o nome de exibição.
- `procedural_quests.gd`: missões novas recebem o nome localizado da cidade e do local de coleta a partir dos registros existentes.

## Migração de campanhas existentes

- O ID da cidade natal permanece inalterado; apenas `character_home_name` é recalculado ao continuar a campanha.
- Memórias de eventos dos NPCs são atualizadas pelo `place_id`. Memórias antigas que só guardavam rótulos numéricos como `Ruinas007` também são normalizadas quando o número permite identificar um dos marcadores conhecidos.
- Missões salvas mantêm seus IDs, progresso, recompensas e estado. O texto e os campos de cidade/local são atualizados a partir de `city_id` e `site_id`.
- Nenhum nó do GLB precisa ser renomeado.

## Novos marcadores

Ao adicionar uma cidade ou ponto de interesse no Blender, mantenha um ID técnico estável e acrescente uma entrada ao catálogo. Enquanto um novo POI ainda não tiver topônimo próprio, o fallback mostra uma designação natural por categoria (por exemplo, `Ruínas antigas` ou `Torre de vigia`), nunca o número do marcador.
