# Conversas autônomas entre NPCs — Os Cânticos dos Sete: Brumaférrea

## O que foi adicionado

- Traço de personalidade estável por identidade: curioso, desconfiado, bem-humorado, reservado, fofoqueiro ou prático.
- Conversas de três turnos com balões temporários, iniciadas quando dois habitantes da mesma cidade estão próximos; eles podem ser interrompidos durante passeios públicos.
- Assuntos escolhidos com base em parentesco, profissão/local de trabalho, guarda, horário, clima e ameaça regional.
- Memória local limitada de avistamentos e combates com monstros. Apenas NPCs suficientemente próximos do acontecimento recebem essa memória.
- Boatos podem ser compartilhados com outro NPC, mas o mesmo par não repete o mesmo acontecimento a cada encontro.
- A simulação usa regras e texto local; não chama serviços externos nem adiciona dependências de IA.

## Limites desta versão

- A memória dos acontecimentos é de sessão e curta; não é uma simulação social persistente entre partidas.
- Para preservar o desempenho, a busca de conversas se concentra nos habitantes visíveis próximos do jogador. Caminhadas públicas podem ser interrompidas, mas deslocamentos para casa, trabalho e transições de porta são preservados.
- Os acontecimentos registrados nesta etapa são avistamentos e derrotas de monstros perto dos habitantes; a próxima ampliação natural seria acrescentar crimes, missões, mortes de NPCs, festas e notícias locais.
- A fala aparece em balão 3D temporário, não em áudio.


## Identidade individual e pausa de conversa

- Cada NPC conserva traços estáveis próprios: estilo de fala, interesse pessoal, objetivo, sociabilidade e curiosidade, além da personalidade geral, profissão, família e memória de eventos.
- O assunto pessoal aparece também como opção própria no diálogo com o jogador. Assim, NPCs da mesma profissão podem oferecer assuntos e respostas diferentes.
- As falas usam variações de voz e um histórico individual recente para evitar repetição literal pelo mesmo habitante. Respostas podem citar os interesses ou objetivos daquele NPC.
- Conversas entre habitantes avaliam pares próximos reais, favorecendo familiares, colegas e pessoas mais sociáveis. Um NPC caminhando por uma atividade pública pode interromper o passeio; destinos de casa, trabalho e transições de porta não são interrompidos.
- Durante a conversa, ambos cancelam a rota atual e ficam parados até o último turno. A rotina só lhes atribui outra atividade depois da pausa, evitando que voltem a caminhar entre cada fala.
- A “mente” é uma simulação local por regras e memória, não um modelo de linguagem externo. Traços de identidade são persistidos; o histórico recente de frases e os acontecimentos conhecidos continuam sendo de sessão.
