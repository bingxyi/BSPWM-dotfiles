# Atualizar com merge das configurações locais

```sh
cd ~/rice
./update.sh --dry-run
./update.sh
```

O update usa o remoto/upstream configurado da branch atual. Busca commits,
exige histórico fast-forward, cria uma worktree temporária e roda o checker e
a suíte da versão recebida. Em seguida, prepara todas as cópias e merges em
staging. Somente após esse preflight atualiza o checkout e instala os arquivos
com o mecanismo transacional de backup/restauração. O instalador repete o
preflight antes de aplicar, inclusive se o HOME mudou durante os testes.

O merge usa três conteúdos: a fonte distribuída na instalação anterior, o
arquivo instalado atual e a nova fonte recebida. Por exemplo: editar um alias
local e receber uma correção em outra parte do mesmo script conserva ambas as
mudanças. Até atualizações posteriores preservam a edição pessoal já mesclada.
Templates são mesclados antes de gerar cores; edições diretas nos arquivos
gerados também passam pelo merge quando existe uma base exata.

## Opções

| Comando | Efeito |
| --- | --- |
| `./update.sh` | Busca, valida, mescla e instala |
| `./update.sh --dry-run` | Busca e valida, imprime o plano; mantém checkout e arquivos instalados |
| `./update.sh --no-fetch` | Usa o upstream já buscado, sem rede |
| `./update.sh --target /caminho/home` | Usa HOME existente alternativo para teste/migração |
| `./update.sh --keep-monitors` | Preserva um `monitors.sh` pessoal |

O dry-run escreve metadados de fetch/worktree e `.install.lock` no Git, além de
temporários de teste. Não instala no HOME. Pacotes do sistema e drivers não são
atualizados; os processos da sessão não são reiniciados. Aplicações usam os
arquivos conforme os releem; uma nova sessão carrega todas as mudanças.

## Preservação e conflitos

O update não cria commits nem stashes automáticos, não reseta branches e não
publica suas configurações locais. Um checkout com mudanças pendentes ou
histórico divergente para antes de instalar. Reconcilie seu trabalho no Git e
execute novamente. O merge automático descrito aqui é dos arquivos instalados
com as fontes recebidas; a branch é atualizada somente por fast-forward.

Edições sobrepostas, binários alterados nos dois lados, arquivos excluídos
localmente, symlinks e bases ausentes/corrompidas interrompem o preflight. A
mensagem lista os caminhos e a causa. Compare o arquivo instalado e a fonte
correspondente em `stow/`, resolva a intenção da mudança e repita o update.
Marcadores de conflito nunca são instalados. Um merge textual limpo também
precisa passar no checker da distribuição; isso não comprova toda a semântica
de uma personalização arbitrária.

No preflight inicial, um conflito mantém tanto o checkout quanto o HOME. Se um
arquivo mudar depois desse preflight, a verificação final pode recusar instalar
quando o checkout já avançou. Corrija o conflito e rode o mesmo comando de novo.
Falhas durante a cópia usam rollback da transação do instalador.

Preferências mutáveis existentes (tema, perfil, mouse, fish inicial), hooks
pessoais e preferências privadas de monitor continuam preservados. Um arquivo
removido upstream só é removido localmente quando coincide com a base upstream;
um arquivo com edição pessoal permanece local e sai do gerenciamento.

## Bases e instalações anteriores

O inventário schema3 em `~/.local/state/rice/managed.json` guarda hashes do
conteúdo instalado e das bases upstream. As bases ficam em
`~/.local/state/rice/bases/<sha256>`, com permissão0600, e participam da mesma
transação de backup/restauração. Preserve esse estado ao migrar uma instalação
existente. Bases antigas são mantidas para os inventários recuperados por restore.

No schema2 anterior só existiam hashes. Se o arquivo está intacto ou já coincide
com a nova fonte, ele pode atualizar diretamente. Para uma edição local, o
instalador procura no histórico Git os bytes correspondentes ao hash antigo.
Se a base não existir nesse histórico (inclusive clone shallow) ou for um
arquivo gerado sem base salva, ele pede reconciliação explícita. Não inventa
uma base nem usa `--overwrite-local` para contornar esse caso.

Cada instalação imprime seu backup e comando exato de restore. Use esse
comando para reverter os arquivos instalados; restore não altera o histórico Git
e recusa sobrescrever edições posteriores. `sync.sh` continua disponível com o
comportamento antigo e estrito. Para merge local, prefira `update.sh`.
