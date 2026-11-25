# Proficiência por uso — Os Cânticos dos Sete: Brumaférrea

O sistema está conectado a `scripts/player.gd`. O progresso é mantido na sessão e sobrevive a uma nova tentativa após a morte; iniciar uma sessão nova reinicia as proficiências.

## Marcos de proficiência

`PROFICIENCY_THRESHOLDS` define os marcos: 0, 10, 25, 50 e 100. Magias ganham um ponto por conjuração válida; armas corpo a corpo ganham um ponto por inimigo atingido.

## Força das habilidades

- `MAGIC_PROFICIENCY_MULTIPLIERS`: multiplicadores de potência mágica por grau: 1.00×, 1.12×, 1.27×, 1.47× e 1.75×.
- `WEAPON_PROFICIENCY_MULTIPLIERS`: multiplicadores de dano corpo a corpo: 1.00×, 1.04×, 1.08×, 1.14× e 1.22×.

Relâmpago, Bola de Fogo e Cura Menor evoluem separadamente. Os projéteis ofensivos também aumentam de tamanho e intensidade luminosa conforme o grau, em `scripts/magic_projectile.gd`. A interface de proficiências fica na aba **Perícias** do inventário (`I`), e as informações de cada magia aparecem em sua própria ficha.
