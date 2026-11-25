# Clima regional — Os Cânticos dos Sete: Brumaférrea

## Integração com o modelo de mundo atualizado

O clima regional é calculado a partir dos limites da malha `OW_Terrain` carregada em `assets/world/overworld.glb`, em vez de uma lista fixa de coordenadas. O modelo atual mantém cerca de 4.000 × 4.000 unidades no plano X/Z (de -2.000 a +2.000), com alturas observadas entre aproximadamente -32 e 112,7 unidades. A câmera do menu foi ajustada levemente para continuar enquadrando o cume atualizado de Brumaférrea.

O mundo usa células meteorológicas de 520 unidades. Com essa extensão, a malha ocupa cerca de oito células no sentido X e oito no sentido Z, incluindo células parciais nas bordas e uma borda adicional de vizinhança para interpolação. O sistema inicializa a região pelo relevo real e lê a superfície de colisão `OW_Terrain-colonly` para estimar a altitude, ignorando água e construções.

## Funcionamento

- Cada célula mantém seu próprio estado meteorológico, temporizador, nuvens, precipitação, intensidade da tempestade, umidade do solo e classificação térmica.
- A semente meteorológica e os estados regionais persistem durante a sessão, inclusive entre recriações do overworld. Estados salvos pelo sistema antigo são convertidos na primeira atualização.
- As condições iniciais combinam ruído espacial, altitude e um campo de temperatura separado. Regiões altas e arredores de Lobofrio são frios; bolsões de temperatura baixa também podem aparecer em encostas e vales elevados. Células vizinhas influenciam as probabilidades de transição, favorecendo frentes climáticas coerentes.
- Em regiões frias, chuva é convertida em neve e tempestades elétricas são substituídas por tempestades de neve. A região não desenha chuva e neve simultaneamente durante a transição entre células.
- As intensidades mudam gradualmente; o clima mostrado é interpolado entre os centros das células para reduzir fronteiras abruptas.
- Chuva, flocos de neve e relâmpagos só são renderizados para a área meteorológica ocupada pelo jogador. A precipitação usa partículas próximas à câmera, não partículas cobrindo o mapa inteiro. Os flocos têm tamanho e opacidade suficientes para permanecer visíveis em movimento. Tempestades de neve aumentam o vento lateral, a velocidade e a dispersão dos flocos, além da névoa, reduzindo a visibilidade sem gerar relâmpagos.
- A umidade do solo é registrada por região e amostrada numa textura espacial; uma chuva local não molha automaticamente toda a malha. Neve não cria o efeito de poças de chuva.
- Os diálogos individuais e as conversas entre habitantes consultam o clima da posição do NPC, e não apenas o clima na posição do jogador. Há respostas específicas para chuva, tempestade elétrica, neve e nevasca, incluindo reações distintas de guardas e mercadores.

## Tempos e controles

Os intervalos padrão de mudança são de aproximadamente 180–420 segundos reais, e as transições principais levam cerca de 28 segundos. O solo demora mais para molhar e secar.

Durante a exploração, `F5`–`F11` permitem testar o clima: `F5` reativa a evolução automática; `F6` força céu limpo; `F7` força tempo nublado; `F8` força precipitação (chuva em regiões temperadas, neve nas frias); `F9` força tempestade (tempestade de neve nas regiões frias); `F10` força neve e `F11` força tempestade de neve para testes visuais. Os comandos afetam apenas a célula atual do jogador.

## Limitação visual atual

O céu, a iluminação e a névoa são um único ambiente de renderização do Godot e refletem o clima local do jogador. Chuva e neve são localizadas perto da câmera; nuvens volumétricas ou frentes de precipitação visíveis em regiões distantes ainda não estão implementadas. O calendário sazonal também ainda não altera as probabilidades.


## Integração com construções e lanternas do modelo atual

O modelo atual contém 17 tipos de construção (incluindo prefeitura, templo, biblioteca, estalagem, enfermaria, loja, posto de guarda, mirante, depósito, abrigo, estábulo, oficina, moinho, celeiro, poço e ruínas). O sistema de chuva usa os volumes de colisão das construções para reconhecer um telhado/abrigo diretamente acima do jogador e suspender a chuva local enquanto ele estiver protegido. A chuva regional e a umidade do terreno continuam ativas do lado de fora.

As superfícies existentes com material `OW_LanternGlow` são detectadas ao carregar o GLB. A emissão das lanternas diminui durante o dia e aumenta gradualmente no crepúsculo/noite. O sistema recupera posições aproximadas das lanternas a partir da geometria emissiva e acrescenta luzes pontuais sem sombras; apenas as 24 luzes mais próximas, dentro de 132 unidades, ficam ativas ao mesmo tempo para limitar o custo no renderer Compatibility. A força é ajustada de forma moderada por tipo de construção, e dias encobertos deixam a luz local um pouco mais perceptível.

A configuração do projeto agora também apresenta o título `Os Cânticos dos Sete: Brumaférrea`.

## Limitações

O clima regional simula estados por célula e usa um único céu/ambiente global do Godot para a região do jogador. A neve é representada por partículas e neblina; cobertura de neve acumulada no terreno, telhados e vegetação ainda não está implementada. As lanternas criam iluminação local à noite, mas não geram sombras. A deteção de abrigo depende de a colisão da estrutura estar carregada e de haver um telhado acima do ponto consultado; toldos sem colisão própria podem não bloquear chuva ou neve.


## Compatibilidade da reconstrução de rios

A malha GLB de `OW_Terrain` pode omitir um pequeno número de vértices da grade regular quando triângulos degenerados são removidos na exportação. O gerador de água preenche lacunas esparsas usando alturas vizinhas ponderadas, antes de amostrar o leito dos rios. Se uma lacuna não tiver vizinhos válidos após as passagens de preenchimento, a reconstrução da água é cancelada com um aviso, evitando uma superfície de rio inválida.
