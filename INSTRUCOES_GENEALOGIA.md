# Brumaférrea — patch de genealogia e ciclo de vida dos NPCs

Este pacote contém apenas os arquivos alterados. Ele deve ser aplicado sobre a raiz do projeto `Os Cânticos dos Sete: Brumaférrea` (Godot 4.6).

## Aplicação

1. Faça uma cópia de segurança do projeto e dos saves.
2. Feche o Godot.
3. Extraia este ZIP na raiz do projeto, mantendo a estrutura de pastas e permitindo substituir os arquivos existentes.
4. Abra o projeto normalmente no Godot 4.6.

Arquivos incluídos:

- `scripts/npc_society.gd`
- `scripts/npc.gd`
- `scripts/overworld.gd`
- `docs/npc_society_system.md`

Não há mudança em `project.godot` nem novos assets: os sprites `boy.png` e `girl.png` já existentes são reutilizados.

## O que esta versão implementa

- Um registro genealógico persistente por NPC, com IDs de mãe, pai, filhos, parceiros, uniões, geração, idade e sobrenome familiar.
- União registrada quando uma relação social chega ao estágio `partner`; saves antigos com parceiros são migrados.
- Verificação de parentesco para impedir relações entre ancestrais/descendentes, irmãos e pessoas com pais ou avós em comum.
- Concepção e nascimento processados pelo relógio do mundo, sem exigir a presença do jogador.
- Crianças com IDs próprios, nome e sobrenome herdado, vínculo com os pais e sprite infantil.
- Restauração dos filhos em carregamentos seguintes e atualização para sprite adulto aos 16 anos simulados.
- APIs internas para consultar o registro individual, montar um recorte de árvore familiar e obter estatísticas da genealogia.

## Regras provisórias de simulação

- 30 dias do calendário do mundo equivalem a um ano de idade.
- A gestação ocupa 9 meses desse calendário.
- A concepção só é considerada depois de 6 dias de união; a checagem ocorre a cada 3 dias.
- A chance por checagem é de 14% quando os requisitos são atendidos.
- A mãe precisa ter entre 18 e 40 anos simulados; o pai, pelo menos 18.
- Limite provisório de 3 filhos por mãe e 6 moradores por residência.
- Os pais precisam estar na mesma cidade e a mãe precisa ter uma residência registrada.

Esses valores são constantes no início de `scripts/npc_society.gd` e podem ser ajustados após testes de ritmo.

## Ainda não incluído

- Cerimônia de casamento, separação ou divórcio.
- Morte natural e registro de causa de morte.
- Herança de casas, lojas, profissões ou bens.
- Adoção.
- Mudança autônoma de residência dos filhos quando adultos.
- Tela visual para navegar pela árvore genealógica.
- Progressão demográfica enquanto o jogo está fechado.

## Salvamento e validação

O estado social passa a gravar o campo `genealogy` e usa a versão 8 do arquivo `user://npc_society_state.json`. Os campos anteriores continuam sendo lidos; não apague o save existente antes de testar e mantenha uma cópia de segurança.

Os arquivos foram revisados estaticamente nesta sessão, mas não foi possível executar o projeto no editor/runner do Godot porque não há um executável Godot disponível no ambiente. Faça o primeiro teste em uma cópia do projeto e confira a aba **Debugger** para detectar erros de GDScript ou de integração.
