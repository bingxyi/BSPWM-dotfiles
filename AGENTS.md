# BSPWM rice — contexto do projeto

## Fonte e orientação inicial

Este checkout é `~/rice`, repositório `bingxyi/BSPWM-dotfiles`. O desktop atual
é Arch Linux/X11/BSPWM; há adaptações locais de notebook não commitadas.
Leia `docs/environment-context.md` e a skill pessoal
`/home/bingxyi/.agents/skills/linux-debug-wm/SKILL.md` quando o trabalho envolver
o desktop, monitores, bindings, aparência, compositor, painéis ou a instalação.
Esses documentos são snapshots de 2026-11-04: versões, processos, tema e posições
físicas precisam de verificação viva, sem reinstalar para “alinhar” a memória.

## Preservação e escopo

- Inspecione Git, tipo dos arquivos, dependências e sessão antes de editar.
  O runtime atual usa cópias reais em ~/.config; edite-as diretamente quando
  solicitado. ~/rice contém as fontes de distribuição, sem sincronização implícita. Preserve o
  diff atual; não faça reset, pull/stash/commit ou limpeza automática de legado.
- Preserve a aparência, os efeitos compatíveis, a latência e o workflow AppSec.
  Não remova blur, transparência, sombras ou animações só para simplificar.
- Preserve binds upstream e alias `super + apostrophe` para ABNT2. Kitty usa
  fish; os dotfiles Zsh também existem e não são a configuração fish.
- Um pedido de diagnóstico não autoriza aplicar monitores, recarregar/matar
  processos, trocar tema, instalar pacotes ou reiniciar. Execute correções
  concretas já autorizadas sem confirmações redundantes.
- Dados pessoais ficam fora de Git: local.sh, monitors.local.sh, mouse/profile,
  credenciais, VPN, engagement/evidências, avatar e preferências mutáveis.

## Estrutura e linguagens

- `install.sh` → `scripts/install.py`: Python, cópias reais, staging de templates e inventário schema3 com bases de merge,
  backups transacionais e restauração. `update.sh` valida upstream em worktree,
  usa fast-forward e merge de três vias no runtime com bases schema3.
  `sync.sh` mantém o updater estrito anterior.
- `stow/desktop`: bspwmrc, sxhkd, Kitty, Picom, Rofi, Eww e rice/bin Bash/Python.
- `stow/shell`: .profile, .xprofile, .xinitrc, .zprofile, .zshrc (POSIX sh/Zsh).
- `stow/editor`: Neovim/Lua/Lazy e integração de notas/engagement/Semgrep.
- `defaults`: defaults mutáveis copiados; `themes/*.conf` e `templates/*.tpl`
  controlam cores. Não altere apenas arquivos renderizados para mudanças duráveis.
- Eww usa Yuck/SCSS; Rofi usa Rasi; Picom usa libconfig; Kitty/tint2 têm configs
  próprias. Leia a sintaxe e a versão do componente antes de copiar opções.

## Regras de monitores e composição

- `monitors.sh` carrega override privado e chama `monitor-layout.py`.
  `monitor-sync.py` sincroniza geometria, ordem, padding e restack da barra.
- Mantenha desktops 1–10, 1–6 no principal/barra e 7–10 nas demais; uma tela
  recebe todos. Transfira desktops/janelas antes de remover tela desconectada.
- Preferências HDMI/eDP são opcionais; não exija HDMI conectado nem force
  resolução, refresh ou retrato do desktop em outro usuário/notebook.
- Watcher usa eventos RandR + safety check15s, debounce.4s e locks. Evite loops
  ocupados e dois escritores de layout. Perfil autorandr só vale se detectado.
- O instalador agora instala monitors.sh portátil por padrão; --keep-monitors
  preserva script pessoal e exclui o watcher. --adopt-monitor-layout cria override
  privado apenas se ausente. As duas opções são incompatíveis.
- Distinga picom.conf moderno de picom-basic.conf ativo. `vgit-*` não informa
  major para o parser atual. Fading, presets Picom, SCSS/Eww e cursor Kitty são
  camadas distintas. Comentários NVIDIA não provam hardware NVIDIA.
- `lock.sh` pode desligar secundários; há uma hipótese documentada de corrida
  com o watcher/marker lock_monitors_off. Investigue com evidência, sem supor
  correção já feita nem testar bloqueio da sessão inadvertidamente.

## Testes e operações

- Rode `python3 -B scripts/check.py` e
  `python3 -B -m unittest discover -s tests -v` para mudanças de código.
- O checker valida sintaxes, binds, executáveis e templates; declare skips de
  shellcheck/luac. Teste o instalador com cópias reais em HOME temporário; Stow não é dependência.
  Mudanças diretas são protegidas por hashes. --overwrite-local exige intenção
  explícita e backup; não o adicione automaticamente para contornar conflitos.
- `--dry-run` não instala em HOME, mas abre `.install.lock` no checkout.
  Getters Bash que source lib.sh podem criar STATE_DIR. Consultas não são
  automaticamente sem efeitos só porque o nome começa com --get/--status.
- Backup: `~/.local/state/rice/backups/<timestamp>/manifest.json`;
  inventário `~/.local/state/rice/managed.json`. Preserve o restore impresso.
  Ele recusa sobrescrever mudanças posteriores; reconcilie, não burle o check.
- Logs comuns: `~/.local/share/rice/`; monitores:
  `~/.local/state/rice-monitors.log`; locks em XDG_RUNTIME_DIR.
- Instalação e recarga são ações diferentes. `bspc wm -r` pode regenerar IDs
  internos de desktops; compare nomes e as janelas, além dos IDs.
- Verifique X11/socket de verdade. Falha de sandbox não prova tela quebrada;
  não revele cookies X11, tokens, notas, conteúdo de targets ou chaves.

## Evidência histórica

Migração aplicada com backup
`~/.local/state/rice/backups/20261104T171438Z-cnxqd0d1/` e auditoria
`~/.local/state/rice/audits/20261104T170505Z/`. Na aplicação: 28 testes passaram,
118 binds foram conferidos; três janelas permaneceram nos mesmos desktops.
Hotplug foi simulado, não testado retirando fisicamente o cabo.
O xinput local está documentado na memória: não confunda presença em PATH com
pacote instalado no pacman. Refresque todos esses fatos antes de novas ações.

## Estado final da adaptação de 2026-11-04

Configurações reais/editáveis substituíram links por pedido do usuário. Backup:
`~/.local/state/rice/backups/20261104T183003Z-1_zilqss/`, com conteúdo de links
antigos em resolved/. O HDMI fica fisicamente à esquerda: override privado
`RICE_MONITOR_LAYOUT=ordered`, ordem HDMI-1 eDP-1. Essa ordem física é independente
da tela principal e prevalece sobre geometrias antigas/perfis autorandr nesse
modo. Preserve é o padrão portátil.35testes e118binds foram validados.

## Procedimento padrão solicitado pelo usuário — 2026-11-04

Ao concluir uma intervenção autorizada neste ambiente BSPWM, sincronize o código
e a documentação correspondentes com `~/rice` e registre o contexto relevante
na memória. Esta preferência foi solicitada explicitamente pelo usuário.
Para memórias, use pequenas notas em
`~/.codex/memories/extensions/ad_hoc/notes/`, respeitando as regras do runtime;
não edite MEMORY.md diretamente nem armazene credenciais ou dados pessoais.
Preferências mutáveis continuam locais quando apropriado. Repositório atualizado
não significa commit/push: só execute esses passos quando o usuário pedir.
