# Casa natal do jogador

A criação de personagem reserva uma casa física no assentamento escolhido como cidade natal. O edifício mantém um ID derivado do cenário e é reservado antes da criação dos NPCs, para que a população não passe a ocupá-lo em carregamentos seguintes.

## Interações

- Entre no edifício identificado como **Casa de [nome do personagem]** usando `F` na entrada.
- Dentro, mire na cama e pressione `F` para dormir até as 06:00. A vida e a mana são restauradas; o salto de tempo também é sincronizado com o relógio da simulação social.
- Mire no baú pessoal e pressione `F` para abrir a interface de armazenamento.
- Selecione uma arma ou armadura para transferi-la individualmente. Poções e materiais são movidos em pilhas completas. O equipamento base do jogador não pode ser guardado.

## Persistência

O conteúdo do baú e o vínculo entre a cidade natal e a casa física são gravados em `user://player_home_storage.json`. O jogo guarda um ID de edifício, não o nome mostrado na interface, para manter a mesma casa associada à cidade mesmo quando os nomes exibidos mudam.
