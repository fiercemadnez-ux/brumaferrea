# Salvamento e continuação — Brumaférrea

O projeto usa um único slot de campanha em `user://brumaferrea_campaign_save.json`, na pasta de dados do Godot do usuário.

## Como usar

- **CONTINUAR** no menu carrega o último slot válido. O botão fica desativado quando não há um salvamento.
- **SALVAR JOGO** aparece no menu de pausa.
- **F5** grava a campanha durante o jogo.
- A campanha também é salva automaticamente a cada 90 segundos enquanto a aventura está ativa e ao fechar o jogo.
- **NOVA JORNADA** começa uma campanha limpa quando a criação de personagem é confirmada; ela substitui o slot anterior.

O slot contém os dados do personagem (atributos, nível, experiência, ouro, vida, mana, recursos, armas, armaduras, magias e posição), relógio, fase lunar, estado regional, descobertas, tarefas e snapshots da sociedade de NPCs e do armazenamento da casa. O estado da cripta é reconstruído a partir da seed da campanha.

Os arquivos auxiliares `npc_society_state.json` e `player_home_storage.json` são snapshots de trabalho usados pelos sistemas existentes. Ao continuar, seus conteúdos são restaurados a partir do slot principal antes da criação dos NPCs. Ao começar uma nova jornada, os dois arquivos e o slot anterior são limpos para evitar a herança de memórias, relações, morte da bruxa ou itens guardados da campanha velha.

Este é um único slot local; não há slots múltiplos ou sincronização em nuvem.
