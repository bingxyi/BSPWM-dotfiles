# Auditoria · 2026-10-29

## Correções nas cópias versionadas

- Zsh: `cde` usa `engagement_path`, sem alterar a variável especial `path`/`PATH`;
  cria o cache antes de `compinit`, usa `$HOME` e trata bootstrap local ausente.
- sxhkd: emojis em `Super+Alt+period`, sem colisão com troca de monitor.
- Monitores: outputs distintos na autodetecção, um único snapshot de RandR,
  modos nativos, centralização vertical, rotação normal em tela única e
  fallback sem desligar outros outputs. Overrides locais ficam fora do Git.
- Inicialização: espera os retângulos reais de bspwm após RandR antes de
  definir desktops; cria o diretório de logs antes do watcher do mouse.
- Barra/compositor: locks para partidas concorrentes, `--start` idempotente,
  readiness via `eww ping`, sem reiniciar picom já ativo. A geração inicial
  do tint2 usa `--render-only`, evitando um restart recursivo da barra.
- Bloqueio: fallback i3lock recebe hexadecimal sem `#`.
- Temas: lock de aplicação, temporários exclusivos, erros propagados e
  renderização sem serviços gráficos. Templates tint2 usam `{{home}}`;
  o backend de mídia entrega um placeholder relativo ao usuário atual.
- Shell: remove processos `basename` em inicializações frequentes, lê estado
  e paletas com builtins, elimina consultas repetidas no seletor de desktops,
  remove variável de dependências não utilizada e evita crescimento do PATH.
- Instalador: Stow sem folding; backup de conflitos/links quebrados;
  proteção de diretórios ancestrais ligados a outros locais; rollback;
  inventário para remover links de fontes excluídas; preservação de estado
  mutável e recusa de restauração sobre edições posteriores.
- Scripts opcionais de sistema: usuário dinâmico e sudoers parametrizado;
  instalador principal desses helpers faz backup e gera restauração.

## Evidências locais

- `python3 scripts/check.py`: sintaxe de 57 arquivos shell, Lua/Python,
  117 combinações de teclas sem duplicação, caminhos dos scripts de atalhos,
  permissões do bspwmrc, 10 templates e padrões locais de secrets.
- `python3 -m unittest discover -s tests -v`: 16 testes, 15 passaram,
  1 ignorado por falta de GNU Stow. Transações usam um adaptador de Stow nos
  testes unitários; o teste de integração separado exige o executável real.
- Regressões executadas em homes temporários: engagement válido, PATH estável,
  fallback com dois monitores distintos, centralização, tela única, modo
  inválido, inicialização concorrente da barra, cor do i3lock e renderização
  sem X11. Serviços externos e RandR são simulados nesses testes.
- `.gitignore` verificado com `.env`, chaves, credenciais AWS, histórico,
  swap, temporários e avatar; `offsec/env` e defaults públicos continuam incluídos.
- `install.sh --dry-run` produziu o plano para o home atual sem modificá-lo.

## Pendências de ambiente

- X11 e socket do bspwm estão inacessíveis no sandbox; não há validação visual
  de compositor, struts, janelas, hotkeys ou troca real de monitores.
- GNU Stow e ShellCheck não estão instalados. `sudo -n pacman -S ...` exigiu
  senha, e o download sem privilégios falhou por resolução DNS. A integração
  real com Stow, ShellCheck e instalação no home ficam pendentes até liberar
  essas dependências/permissões. A tentativa de execução elevada também foi
  rejeitada pela política do sandbox (`sandbox_approval: false`); os dotfiles
  ativos no home original permanecem sem essas correções.
- O envio ao Aikido foi rejeitado pela revisão automática por envolver código
  local privado e um serviço externo sem autorização específica. Nenhum
  resultado desse serviço é usado como evidência; a checagem local não equivale
  a uma auditoria completa de segurança.
- `pacman -Qdtq` apontou `go`, `python-build`, `python-installer`,
  `qemu-system-aarch64` e `sassc`. São candidatos a órfãos segundo o banco do
  pacman, não prova de desuso pessoal; não foram removidos. Go, QEMU e Sass
  podem continuar sendo usados fora do gerenciador de dependências.

## Ativação e verificação no host

```sh
cd ~/Documents/offsec-dotfiles
sudo pacman -S --needed stow shellcheck
python3 scripts/check.py
python3 -m unittest discover -s tests -v
./install.sh --dry-run
./install.sh
systemctl --user daemon-reload
systemctl --user enable --now offsec-notification-retention.service
# Depois de revisar o backup e encerrar trabalhos sensíveis à troca de layout:
bspc wm -r
# Super+Escape recarrega o sxhkd.
bspc query -M --names
bspc wm --dump-state
xrandr --query
```

O instalador imprime o caminho de backup e o comando exato para restaurá-lo.
