# Sistema musical de Os Cânticos dos Sete: Brumaférrea

A música é controlada por `scripts/game.gd`. As faixas têm funções diferentes:

- `Main Theme.mp3`: música do menu principal, em repetição. Para quando começa a exploração.
- `The Morning.mp3`: jingle reproduzido uma vez quando o relógio cruza 06:00, no nascer do sol.
- `Noon.mp3`: jingle reproduzido uma vez quando o relógio cruza 12:00.
- `Nightfall.mp3`: jingle reproduzido uma vez quando o relógio cruza 18:00, no pôr do sol/começo do anoitecer.

As três vinhetas do mundo não são música ambiente e não ficam em loop. O controlador acompanha a hora do mundo e detecta a passagem pelos marcos do relógio; entrar no mundo às 10:00, por exemplo, não toca retroativamente `The Morning`. A vinheta da manhã toca no próximo nascer do sol.

O tema e as vinhetas de horário ficam em `assets/sound/music/`. O loop fica ativado apenas para o tema do menu; as vinhetas temporais e as faixas de cidade são reproduzidas sem repetição.


## Música de cidades (eventos aleatórios)

- `assets/music/sound/town/town1.mp3` e `assets/music/sound/town/town2.mp3` são eventos musicais pontuais. Não tocam automaticamente ao entrar numa cidade, não ficam em loop e nunca são reproduzidos ao mesmo tempo.
- O jogo escolhe aleatoriamente entre as faixas carregadas. Quando há mais de uma, evita escolher a mesma faixa duas vezes seguidas. Existe apenas um `AudioStreamPlayer` para a música de cidade, o que impede sobreposição entre as duas.
- O primeiro disparo ocorre após um atraso aleatório de 75 a 180 segundos acumulados em zonas urbanas. Os próximos eventos ficam separados por 300 a 540 segundos de presença urbana. Trocar de cidade ou sair e retornar não provoca uma reprodução instantânea. Fora da zona urbana, o temporizador de novos eventos fica pausado.
- Quando uma vinheta de horário (`The Morning.mp3`, `Noon.mp3` ou `Nightfall.mp3`) começa durante uma música de cidade, o volume da faixa urbana é silenciado (`-80 dB`) para a vinheta tocar sozinha. A faixa urbana continua avançando em silêncio e volta a `-2 dB` quando a vinheta termina, desde que a faixa ainda esteja tocando. Se a música da cidade terminar durante a vinheta, não será reiniciada.
- Se um evento musical de cidade ficar elegível enquanto uma vinheta estiver tocando, ele espera a vinheta terminar. Assim, jingles e faixas urbanas não se sobrepõem.
- Para adicionar novas faixas urbanas, inclua seus caminhos em `TOWN_MUSIC_PATHS`; o controlador as sorteia usando o mesmo canal exclusivo de música de cidade.

## Atualização das gravações (18/10/2026)

As gravações mais recentes substituem as versões anteriores sem alterar suas funções no jogo. `Main Theme.mp3` continua como tema em loop do menu; `The Morning.mp3`, `Noon.mp3` e `Nightfall.mp3` continuam como jingles de disparo único nos marcos do relógio. Os arquivos importados em cache foram removidos deste pacote para que o Godot os regenere a partir dos MP3 atualizados na primeira abertura. As faixas de cidade e os SFX não foram alterados.
