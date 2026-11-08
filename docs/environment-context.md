## Auditoria e portabilidade — 2026-11-08

Sessão revalidada: eDP-1 único, 1080p/120,21Hz, desktops1–10, br/abnt2,
Ember Crimson/Nyx. FT-Labs ativo com config gerada; safe-mode ausente.
As234fontes estáticas coincidem com runtime; áudio/rede/Bluetooth ativos.
Fish passa a ser dependência explícita, com config inicial preservável.
Procedimento de migração, versões, exclusões privadas e limites:
[portability.md](portability.md). Snapshots abaixo são históricos.

## Fluidez de animações — 2026-11-05

Patch aplicado e sincronizado em runtime e fonte. FT-Labs df4c6 confirmado por
capacidade e processo; Iris Xe acelerada; HDMI60Hz e eDP120,21Hz preservados.
Molas400/400, massa0,5, damping20, clamping=true; workspace140ms. Efeitos,
blur3, sombras, opacidade, VSync e preferência local sem limite FPS preservados.
Motion aguarda after-paint em vez de50ms fixos, reutiliza superfície Cairo e
corrige o teto de frames em refresh fracionário. Evidências, limites, fontes
e reversão: [picom-fluidity.md](picom-fluidity.md).92testes passaram; shellcheck ausente.

## Emergência de tela preta — 2026-11-04 21:15 UTC

ESTADO HISTÓRICO: modo de recuperação observado em 2026-11-04, posterior à entrega da GUI de animações.
Em 2026-11-05 o marcador estava ausente e FT-Labs/motion já estavam ativos; veja picom-fluidity.md.
Usuário relatou tela toda preta; Picom com config gerada ainda estava em execução,
portanto a causa desta recorrência não foi provada como encerramento do aplicador.
Recuperação: fechar Eww, encerrar motion, iniciar Picom diretamente com
`~/.config/picom/picom-basic.conf` sem FPS preload e atualizar a janela Kitty.
O usuário confirmou que o desktop/terminal voltaram.

`~/.config/rice/compositor-safe-mode` é o marcador local persistente.
O launcher seleciona basic e chama `setsid picom --config ...` diretamente;
`motion.py --serve` sai sem iniciar; a GUI bloqueia Apply nesse modo.
Preferências locais: enabled=false, limit_fps=false, workspace_enabled=false,
tabs_enabled=false. Originais preservados em
`~/.local/state/rice/changes/emergency-display-20261104T211558Z/animations-before.json`.
Não reativar automaticamente as animações/limitador ao retomar outra tarefa.
O código da GUI continua no checkout para revisão; testes anteriores não provam
estabilidade visual suficiente para reativar esses componentes nesta máquina.

## Animation settings — 2026-11-04

SUPER + A abre `desktop_ui.py animations`; shortcuts (SUPER + slash) mostra
`animation settings`. A GUI usa `animation_ui.py`, com preferências validadas em
`animation_settings.py`. Padrão: animações ligadas, limite de 60 FPS e VSync.
Configurações locais: `~/.config/rice/animations.json`; backups de aplicação:
`~/.local/state/rice/animation-backups/`; configs derivadas e biblioteca de limite:
`~/.cache/rice/animations/`. As bases Picom preservam aparência e exclusões.
O limite GLX/EGL é compilado de `rice/lib/picom-frame-limit.c` com cc; é carregado
somente no Picom e não altera refresh/resolução. Medição real: 59,364 FPS.
O renderizador motion lê as mesmas escolhas para workspace e Kitty.

Regressão de tela preta na central foi diagnosticada como ausência do compositor.
`picom-launch.sh` usa setsid para sobreviver ao encerramento do aplicador;
`panel.sh` verifica a seleção X11 de composição antes de criar backdrops de tela
inteira. Sem compositor, abre apenas o painel com Escape, evitando tela preta.
Testes: 87 passaram; 57 scripts, 119 binds e 10 templates verificados.
Procedimento solicitado: sincronizar runtime/~/rice e registrar contexto em
notas de memória ao concluir alterações autorizadas; não presumir commit/push.

## Validação das melhorias — 2026-11-04

Barra: corrigidos caminhos de staging deixados nos executors gerados e glifos
vazios; tint2 e Eww compartilham o mapa de ícones/estados de workspace. O leitor
permanece aquecido e consulta um snapshot por evento. Benchmark local: mediana
55,65 ms antes e 1,53 ms por atualização no leitor aquecido.

Animações: launcher detecta FT-Labs por recurso; `motion.py --serve` oferece
transição de workspace/Kitty curta, sem capturar entrada e sem arquivos de
screenshot. Serviço ocioso aguarda socket; expira efeitos sem commit e cancela
antes do lock. Kitty mantém ações originais, com fallback sem o serviço.
Testados dois terminais, swap, criação/troca/reordenação de abas e split.

Bind Saver: testados captura em GTK real, SUPER obrigatório, salvamento, execução
pelo sxhkd, edição e remoção. Recargas muito próximas foram reproduzidas saindo
por SIGUSR1 (-10); helper agora serializa, aguarda handler registrado e recupera
principal ausente. Super+Escape usa esse mesmo helper. O daemon permaneceu
estável após o teste completo e recargas consecutivas.

Calendário: CRUD de evento temporário e bolinha/Hoje observados no Eww aberto;
evento removido após teste. Bluetooth: abrir preserva energia, scan inicia/para,
lista pareados; esquecer usa confirmação + BlueZ RemoveDevice, testado em fixture
para não destruir um pareamento pessoal. Os três popups foram inspecionados e
centralizados no monitor principal. Dados pessoais seguem fora do checkout.

## Atualização de controles e bloqueio — 2026-11-04

Runtime e fonte continuam em cópias independentes. A central agora despacha
as ações por `control_action.py`, com prazo explícito, estado de ocupado,
erro visível e atualização conjunta de rótulos/estados. `qs_tile` usa `selected`
para indicar estado visual; `active` é a propriedade de interação do Eww.
Foram testados cliques reais consecutivos em Keep awake, DND, energia e Wi-Fi,
e alternâncias reais de áudio/microfone, restaurando os estados anteriores.
Menus foram abertos e cancelados sem mudar preferências.

O `lock.sh` foi simplificado: mantém os monitores ativos, não chama xrandr,
não recompila imagens ao bloquear, serializa invocações e mantém fallback para
i3lock em foreground. Wallpaper já prepara cache fora do caminho do bloqueio.
Os testes automatizados de bloqueio usam lockers simulados. Em seguida, o
usuário realizou lock/unlock e confirmou: “Sem apagão ou flash do desktop”. Trechos históricos abaixo
que descrevem monitors_off/restauração são anteriores a essa correção.

# Memória geral do ambiente BSPWM de bingxyi

Snapshot verificado em 2026-11-04. Estado final: cópias reais em ~/.config, HDMI à esquerda.
Reconfirme a sessão antes de alterar. ~/rice continua sendo o checkout de distribuição.

## Índice

- [Estado, monitores e instalação](#estado-monitores-e-instalação)
- [Aparência, animações e desempenho](#aparência-animações-e-desempenho)
- [Arquitetura e catálogo de scripts](#arquitetura-e-catálogo-de-scripts)
- [Mapa completo de binds](#mapa-completo-de-binds)
- [Diagnóstico e recuperação](#diagnóstico-e-recuperação)

Skill especializada: `/home/bingxyi/.agents/skills/linux-debug-wm/SKILL.md`.
Esta documentação não concede autorização permanente para aplicar mudanças.

## Estado, monitores e instalação


### Identidade e autoridade

- Usuário: bingxyi; HOME observado `/home/bingxyi`; Arch Linux rolling, BSPWM/X11.
- Checkout efetivo: `/home/bingxyi/rice` (`~/rice`), remoto público
  `https://github.com/bingxyi/BSPWM-dotfiles.git`.
- HEAD observado: `e1814f910108ba05485babff87fa326a9d8cc97c` (Update monitors.sh).
  Há mudanças locais substanciais da adaptação do notebook, sem commit/push.
  Reconfirme Git antes de editar. O conteúdo remoto não contém automaticamente
  o que foi alterado localmente nesta sessão.
- Caminho anterior `~/BSPWM-dotfiles` deixou de existir. Downloads/offsec-dotfiles
  e `~/.config/offsec/` pertencem à instalação anterior; não são a fonte atual.
- Estado final: configs instaladas são arquivos reais, editáveis diretamente
  em `~/.config/`; `~/rice/stow/...` é fonte de distribuição, sem vínculo automático.
  Os links da primeira migração foram convertidos com backup. A skill fica em `~/.agents/skills/linux-debug-wm/`.
- A evidência viva e os arquivos atuais prevalecem sobre snapshots antigos.

### Estado observado e variação real

| Componente | Observação de 2026-11-04 |
|---|---|
| GPU | Intel Alder Lake-UP3 GT2 / Iris Xe [8086:46a8] |
| BSPWM | 0.9.12 |
| sxhkd | 0.6.3 |
| Kitty | 0.49.2, shell `/usr/bin/fish` |
| Eww | 0.5.0, commit d87c2fdbfdc012e76d229e4e9ea3325bc0f23e89 |
| Picom | `vgit-df4c6`; processo usa `picom-basic.conf` |
| Tema | Ember Crimson (`ember-crimson`) |
| Perfil | nyx; tint2 vertical, Eww daemon para centro de controle |
| Teclado | ABNT2, layout `br` |
| Tela interna | eDP-1, 1920×1080, 120,21 Hz |
| Externa | HDMI-1, 1920×1080, 60 Hz, principal |
| Ordem bspwm | HDMI-1 (desktops 1–6), eDP-1 (7–10) |
| Padding | esquerdo 46 px no HDMI; zero nos demais lados/tela interna |
| Locale disponível | C, C.utf8, POSIX, pt_BR.utf8; en_US não gerado |
| Idioma dos dotfiles | `LANG=${RICE_LANG:-C.UTF-8}`, LANGUAGE=en_US:en |

Posições NÃO são invariantes: no primeiro apply HDMI estava em +0+0 e eDP em
+1920+0; na verificação da memória, eDP estava em +0+0 e HDMI em +1920+0.
Isso confirma a necessidade de consultar xrandr, sem forçar o posicionamento
antigo. A ordem lógica do bspwm pode diferir da ordem física.

Preferências privadas atuais em `~/.config/bspwm/monitors.local.sh`:
```sh
RICE_MONITOR_PRIMARY=HDMI-1
RICE_MONITOR_ORDER='HDMI-1 eDP-1'
```
São preferências com fallback, não requisitos de saídas conectadas.

### Atualização posterior solicitada pelo usuário

O usuário confirmou que o HDMI fica fisicamente à esquerda. A inversão estava
sendo preservada pela política de manter geometrias ativas. O override final
adiciona `RICE_MONITOR_LAYOUT=ordered`; a ordem `HDMI-1 eDP-1` agora determina
esquerda→direita independentemente do monitor principal. Verificação real final:
HDMI-1 principal em +0+0/60Hz e eDP-1 em +1920+0/120.21Hz, ambos1080p.
Foram preservados os IDs dos desktops e as três janelas sem recarregar o WM.

Novo modelo de instalação, por pedido explícito: **cópias reais** em vez de
links. O diretório fonte ainda se chama stow por compatibilidade do layout do
repo, mas GNU Stow deixou de ser dependência e não é chamado. Inventário schema2
com hashes detecta edições diretas e recusa sobrescrevê-las numa atualização;
`--overwrite-local` substitui apenas explicitamente e com backup. Templates são
renderizados em staging antes de tocar o HOME; execução copia com permissão
preservada e troca atômica. Arquivos de sessão em HOME e lançadores em .local
continuam nos caminhos do sistema. Edições locais não fazem commit/push em ~/rice.

Backup final da conversão + preferência física:
`~/.local/state/rice/backups/20261104T183003Z-1_zilqss/` (223 arquivos + override).
Além dos links antigos, há `resolved/` com conteúdo materializado para recuperação.
Auditoria: `~/.local/state/rice/audits/20261104T182532Z-copy-and-layout/`.
35 testes passaram, incluindo migração, rollback, proteção de edições e ordem
física independente da primária. O backup de 17:14 abaixo é histórico da primeira
instalação; use a transação correspondente ao estado a restaurar.

### Monitores e notebook

`~/.config/bspwm/monitors.sh` carrega o override privado e chama
`../rice/bin/monitor-layout.py`. O controlador usa Python stdlib + libX11/libXrandr
via ctypes; não depende de pip/PyPI. `monitor-sync.py` alinha ordem e padding
com as geometrias que o bspwm efetivamente recebeu e restack do tint2.

- Prefere modo nativo e maior frequência anunciada; em falha de combinação de
  saídas/taxas, tenta `--auto`, sem desligar telas conectadas úteis.
- Preserva posições/rotação de um layout ativo completo nas resoluções nativas;
  compõe extensões lado a lado quando é necessário um novo layout.
- Só aplica autorandr quando existe perfil detectado; a presença do comando,
  por si só, não basta. Perfis salvos podem definir retrato/espelho/empilhamento.
- Respeita tampa fechada com tela externa; uma tela recebe desktops 1–10.
  Com várias: 1–6 principal; 7–10 distribuídos nas demais; mantém extras pessoais.
- Move desktops por ID e suas janelas; remove apenas placeholders `Desktop`
  vazios e monitores antigos depois da migração.
- Watcher `--watch`: lock de instância, eventos RandR, debounce 0,4 s,
  verificação de segurança de 15 s para tampa e lock separado para aplicar layout.
- Atualiza barra/wallpaper nas mudanças de topologia; não cria loop ocupado.

`~/.config/bspwm/local.sh` é um hook privado preservado. O nome de variável
`OFFSEC_BIN` ainda existe, mas aponta para `$HOME/.config/rice/bin`.
Define `xset s 600 600`, `xset dpms 720 780 840`, xss-lock e alertas de bateria
em 20/10/5%. A chamada antiga `autorandr --change --default default &` foi
substituída por um comentário/no-op para não concorrer com o controlador.
Não confunda o comentário herdado offsec com uma dependência atual desse caminho.

### Instalação, dependências e backups

- Entradas: `install.sh`, `sync.sh`; implementação `scripts/install.py`.
- Grupos de fontes (diretórios historicamente Stow): `desktop`, `shell`, `editor`; shell inclui `.profile`, `.xprofile`,
  `.xinitrc`, `.zprofile`, `.zshrc`; editor inclui Neovim. `.xinitrc` inicia bspwm.
- Pré-checagem no HOME real: bash, bspwm/bspc, sxhkd, xrandr, picom,
  rofi, kitty, jq, dunst, zsh, nvim, xsettingsd, flock, xinput; tint2 ou Eww.
- O instalador não instala pacotes do sistema nem reinicia sessão/serviços.
- Backups movem conflitos (inclusive links quebrados), geram manifest e restore.
  `managed.json` schema2 rastreia hashes de cópias (schema1 rastreava links); templates são arquivos regulares gerados.
- Preserva defaults mutáveis existentes (tema/profile/mouse). `--adopt-monitor-layout`
  não substitui override privado já existente. `--keep-monitors` é a alternativa
  explícita para manter um controlador pessoal.
- `sync.sh` exige árvore limpa e fast-forward; não faça pull sobre esta adaptação
  local. Mudanças em symlink afetam a fonte; a aplicação depende do processo.

Transação aplicada e verificada:
`~/.local/state/rice/backups/20261104T171438Z-cnxqd0d1/`.
40 conflitos foram guardados; links gerenciados foram conferidos; o SHA-256 do
monitors.sh antigo coincide com a cópia da auditoria. Restore dessa transação:
```sh
~/rice/install.sh --restore ~/.local/state/rice/backups/20261104T171438Z-cnxqd0d1
```
Auditoria adicional: `~/.local/state/rice/audits/20261104T170505Z/`, com cópias
anteriores, plano de instalação, xrandr, estados BSPWM e verification.json.
Não publique esses estados brutos: podem conter informação de janelas.

`xorg-xinput` estava ausente e sudo exigiu senha. A dependência foi instalada
sem root: `~/.local/bin/xinput` aponta para
`~/.local/lib/rice-deps/xorg-xinput/1.6.4-2/xinput`.
O executável veio do pacote Arch com SHA-256
`fd960ed39d95f417186c2ade78acc1b5dc01d25ba7224a5893fc89ad0e8e0dfc`,
verificado contra o banco local pacman. A proveniência fica em
`audits/20261104T170505Z/user-dependency.json`. Não é um pacote registrado como
instalado no pacman; prefira `xorg-xinput` do sistema quando houver autorização e
sudo disponível, reconciliando o link local para não mascarar a versão nova.

### Validação histórica e limites

- Na migração: 28 testes passaram, com Stow real em HOME temporário; checker
  verificou 57 shell files, 118 hotkeys e 10 templates. Shellcheck não disponível.
- Três janelas originais permaneceram nos mesmos desktops; desktops 1–10
  preservados. IDs foram preservados no apply de layout; `bspc wm -r` regenerou
  IDs internos, comportamento que deve ser separado do teste do controlador.
- Foram detectados cinco dispositivos pelo mouse-settings; ausência de novos
  erros foi conferida. Não transforme esse número de snapshot em requisito.
- O daemon legado `python3 -m offsec_panel daemon` foi encerrado na migração.
  Os arquivos legados não foram apagados.
- Testes de retirar/reconectar cabo foram simulados; não houve teste físico de
  cabo durante a migração. Não declare cobertura universal de todo driver/dock.
- Na leitura atual existe um registro XIO antigo no log de monitores, enquanto
  um watcher novo está ativo. Logs persistem entre sessões: correlate PID e
  timestamps antes de concluir que o controlador está falhando agora.

## Aparência, animações e desempenho


### Fontes de verdade

Tema ativo: `~/.config/rice/current-theme.conf` (mutável, arquivo regular).
Paletas: `~/rice/stow/desktop/.config/rice/themes/*.conf`.
Templates: `~/rice/stow/desktop/.config/rice/templates/*.tpl`.
Aplicação: `theme.sh`; perfil: `profile.sh`; wallpaper: `wallpaper.sh`/`wallgen.sh`.
Confira o estado atual antes de usar os valores de 2026-11-04 abaixo.

Paletas encontradas: abyss-teal, catppuccin-mocha, ember-crimson, everforest-dark,
gruvbox-material, matrix-green, noir-violet, rose-pine-moon, tokyonight-night.

### Visual observado: Ember Crimson / Nyx

| Token/elemento | Valor configurado |
|---|---|
| Background | #1b1215 |
| Background alternativo / dim | #150d10 / #0f090b |
| Surface / overlay | #2a1c21 / #3a272d |
| Foreground / dim | #f2d7d9 / #c9a9ae |
| Accent / alternativo | #e0505a / #ff8c5a |
| Borda focada / normal | #e0505a / #2a1c21 |
| Urgente | #ff6b6b |
| Ícones | Papirus-Dark |
| GTK configurado | catppuccin-mocha-red-standard+default; confira instalação/fallback real |
| Neovim scheme | catppuccin-mocha (com integração da paleta) |
| Wallpaper configurado | ember-crimson.png; existência/arquivo aplicado devem ser verificados |

BSPWM: borda 2 px, gap 8 px, split_ratio 0.52, monocle sem gap/borda,
focus_follows_pointer e pointer_follows_monitor ativados, pointer_modifier mod4,
mouse1 move, mouse2 resize_side, mouse3 resize_corner. Padding da barra apenas
no monitor principal; não restaure o antigo layout de Polybar horizontal.

Nyx usa tint2 vertical à esquerda, largura 46 px, panel_monitor=primary,
panel_layer=bottom, autohide=0, transparência real e taskbar single_desktop.
Fontes dos executors: JetBrainsMono Nerd Font; launcher usa Kitty, Firefox,
Thunar e rice-menu. `ws-tint2.sh` entrega atualizações contínuas por assinatura.
Vesper usa a barra Eww, largura 54 px; Eww fornece também centro de controle
nos dois perfis. O daemon aquecido reduz o atraso de abertura.

Rofi: `~/.config/rofi/config.rasi`, temas rice/menu/grid/power.rasi, cores
renderizadas em colors.rasi. JetBrainsMono Nerd Font 10–12; janelas com borda
2 px e raios aproximadamente 16–18 px, elementos internos 10–12 px.

### Três camadas de animação diferentes

#### 1. Picom moderno — disponível na fonte, não ativo no snapshot

`~/.config/picom/picom.conf` declara backend GLX, vsync=true, use-damage=true,
xrender-sync-fence=true, unredir-if-possible=true. Raios 12 px; sombra raio 18,
opacidade .45, offset (-18,-14). Blur dual_kawase strength=3.

Animações nativas declaradas:
- open/show: preset appear, duration 0.18 s, scale 0.94;
- close/hide: disappear, 0.15 s, scale 0.94;
- geometry: geometry-change, 0.20 s.

Rules: unfocused .94 de opacidade e .06 dim; docks/desktop sem sombra/blur/raio;
lock e fullscreen opacos; ferramentas Burp/ZAP/JADX/Ghidra/Wireshark opacas e
sem blur, navegadores e Kitty opacos. Preservar essas regras protege a
legibilidade de evidências e não é mero detalhe estético.

#### 2. Picom básico — processo efetivamente observado

`picom --version` retorna `vgit-df4c6`. `picom_major()` procura `v[0-9]+`,
logo não identifica major nesse formato. `pick_config()` seleciona
`picom-basic.conf`; o processo foi confirmado com esse caminho.
Isso NÃO prova que o binário seja antigo nem incapaz de animações nativas:
prova que o launcher caiu no ramo conservador por versão não identificada.
Não troque pacotes nem force a sintaxe moderna sem verificar compatibilidade.

Fallback: GLX, vsync e use-damage true; unredir-if-possible=false; raio12;
sombra18/.45/(-18,-14); blur dual_kawase strength=5. Não há bloco de presets
nativos, mas há fading: true, fade-in-step=.06, fade-out-step=.06,
fade-delta=5; portanto, não diga simplesmente “nenhuma animação”.

`picom-launch.sh` trava `rice-picom.lock`, mantém um compositor já existente,
registra falhas em `~/.local/share/rice/picom.log` e tenta fallback se o moderno
não inicia. Rodar o launcher novamente pode não mudar nada no processo vivo.
Não inicie dois compositores e não mate o atual em um diagnóstico somente leitura.

Os comentários sobre NVIDIA nas duas configs são genéricos; o notebook usa
Intel Iris Xe na verificação. Não prescreva opções/drivers NVIDIA por comentário.

#### 3. Eww/GTK e Kitty — independentes de presets Picom

Os números abaixo vêm das fontes configuradas. Processo Eww ativo não comprova
por si só que uma revisão específica do SCSS foi recarregada; confirme quando
a queixa for sobre a aparência efetiva.

Em `~/.config/eww/eww.scss`, `.cc-panel` tem background quase opaco,
border-radius 26 px e slide/fade:
- margin 240 ms cubic-bezier(0.32, 0.72, 0, 1);
- opacity 200 ms ease-out;
- fechado: margin-left=460 px, margin-right=-448 px, opacity=0;
- aberto: margin-left=0, opacity=1.
Botões/cards usam transições de aproximadamente 160–200 ms. O controller
`control.sh`/`panel.sh` altera estado e captura Escape/clique externo;
`popup-keys.sxhkd` pode ter um segundo processo sxhkd legítimo.
A presença desses efeitos não comprova animações nativas do Picom.

Kitty: JetBrainsMono Nerd Font 11.5, padding14/16, background_opacity .92,
background_blur0, borda própria0, janela1200×720, cursor beam1.8,
blink .5 ease-in-out, cursor_trail3, decay .08/.35, threshold8.
scrollback20000, wheel4, touch2, sync_to_monitor=yes, repaint_delay8,
input_delay2. `allow_remote_control=no`; não dependa de `kitty @` para
inspeção ou mutação sem primeiro conferir a configuração.

### Desempenho: investigar sem descaracterizar o rice

- Separe GPU/compositor, CPU de polling, layout, render de fontes e latência de
  teclado. Meça processos, versões e logs antes de reduzir efeitos.
- O watcher de monitores usa eventos RandR com safety check15 s e debounce.4 s;
  não substitua isso por `while true` consultando xrandr a cada frame.
- `mouse-settings.py --watch` usa polling3 s e requer xinput. O pré-check do
  instalador e o guard de startup evitam o erro repetido por dependência ausente.
- Eww usa deflisten/eww-poll e polls condicionais `:run-while cc_visible`;
  não elimine essas condições nem faça work caro com painel escondido.
- Mantenha locks de barra/popups/notificações/monitores. Uma segunda invocação
  pode ser intencional e idempotente; prove duplicação antes de encerrar processos.
- Preserve render-only no theme.sh: gerar templates não deve exigir X11.
- O blur básico está em strength5, o moderno em3. Não apresente o fallback
  como invariavelmente mais leve em todas as dimensões.
- `unredir-if-possible` difere entre configs: investigue fullscreen, stacking e
  cliques na barra antes de alterar. Use `restack-tint2.sh` como parte da cadeia.
- Este pedido de memória não autoriza “otimizar” o desktop. Documente pendências
  de compatibilidade sem modificar o runtime.

## Arquitetura e catálogo de scripts


Pesquisa somente de leitura no checkout `/home/bingxyi/rice`, em 2026-11-04. Nenhum script de UI, instalação ou alteração de sessão foi executado. Caminhos abaixo referem-se ao checkout; o equivalente instalado retira `stow/desktop`, `stow/shell` ou `stow/editor`. A existência no checkout não prova que o runtime tem o mesmo conteúdo: verificar tipo/hash do arquivo em ~/.config e o processo ativo antes de corrigir.

**Modelo final:** o runtime usa arquivos reais em ~/.config, copiados pelo
instalador Python com staging, hashes, proteção de edições e backup. O checkout
~/rice é fonte de distribuição; suas alterações não chegam ao runtime sem
deployment. Diretórios chamados stow permanecem no repo por histórico/layout,
mas GNU Stow não é executado. Consulte environment.md para as duas migrações.

### Índice

- [Arquitetura e riscos de diagnóstico](#arquitetura-e-riscos-de-diagnóstico)
- [Monitores, entrada, composição e bloqueio](#monitores-entrada-composição-e-bloqueio)
- [Barra, Eww e Rofi](#barra-eww-e-rofi)
- [Tema e arquivos derivados](#tema-e-arquivos-derivados)
- [Kitty, fish e Zsh: divergência concreta](#kitty-fish-e-zsh-divergência-concreta)
- [Neovim e workflow](#neovim-e-workflow)
- [Dados, logs e persistência](#dados-logs-e-persistência)
- [Instalação, backup, rollback e armadilhas](#instalação-backup-rollback-e-armadilhas)
- [Comandos úteis com classificação explícita](#comandos-úteis-com-classificação-explícita)
- [Catálogo verificável de todos os scripts Bash em rice/bin](#catálogo-verificável-de-todos-os-scripts-bash-em-ricebin)
- [Inventário de plugins por arquivo (extração literal)](#inventário-de-plugins-por-arquivo-extração-literal)

### Arquitetura e riscos de diagnóstico

- `install.sh` delega a `scripts/install.py`; `sync.sh` chama instalação com `--update`. O instalador copia `desktop`, `shell`, `editor` para os destinos padrão, sem links. O inventário schema2 guarda fingerprints; mudanças locais abortam atualização sem overwrite explícito.
- `stow/desktop/.config/rice/env` é ambiente comum de `.xprofile`, bspwmrc e `.zshrc`; define XDG, editores, Kitty, Firefox, PATH, Java X11 não reparenting e interface inglesa C.UTF-8. Não fazer `source` como diagnóstico neutro: modifica ambiente do shell.
- `lib.sh` concentra temas, state_get/state_set atômico, notificações e Rofi. Seu `STATE_DIR` é **XDG_DATA_HOME/rice**, não XDG_STATE_HOME. Executa `mkdir -p` no carregamento: comandos aparentemente apenas de leitura podem criar diretório. `--help` nem sempre sai zero. Preferir ler os arquivos, não executá-los para descobrir opções.
- Não há `terminal.sh` nem `panel-media.py` no bin atual. Nunca reaproveitar pressupostos sobre `~/.config/offsec/bin`. A migração do instalador substitui essa string em `bspwm/local.sh`, quando é arquivo regular; também desativa a invocação legada exata de autorandr para evitar corrida.

### Monitores, entrada, composição e bloqueio

`stow/desktop/.config/bspwm/monitors.sh` carrega `monitors.local.sh` privado com exportação e delega a `../rice/bin/monitor-layout.py`. O override é código shell; sua execução não é leitura estrita. `monitor-layout.py --plan` só consulta xrandr e imprime argv JSON; o wrapper pode executar o override. Aplicação normal modifica xrandr e bspwm, tenta perfil autorandr detectado, escolhe modo preferido e maior taxa anunciada e reintenta com taxa automática se falhar. Mantém posições/rotação quando layout completo já tem resoluções nativas. Tampa fechada com externo disponível exclui painel interno. Valida saída conectada antes da mutação, preserva desktops ao desabilitar remoção automática de monitores, migra desktops e janelas sem resetar IDs. `--watch` usa libX11/libXrandr via ctypes, eventos e verificação da tampa; debounce .4s. Locks `rice-monitors.lock` e `rice-monitor-apply.lock` em XDG_RUNTIME_DIR ou `/tmp/rice-UID`.

`monitor-sync.py` **sempre altera estado**: espera retângulos RandR/bspwm convergirem por até 3s, ordena monitores e zera padding dos quatro lados de todos, exceto left_padding do monitor da barra (Nyx 46, Vesper 54, override RICE_BAR_WIDTH 1..200). Chama restack-tint2.sh. Atenção: preferência RICE_BAR_MONITOR precisa estar ativa; fallback ao primário xrandr. Não chamar para apenas consultar.

`mouse-settings.py`: `--list` consulta xinput e imprime JSON; sem argumentos abre GUI GTK com prévia ao vivo; `--restore`, `--watch`, `--set-speed V` alteram xinput. Preferências por nome+Device Product ID em XDG_CONFIG_HOME/rice/mouse.json, gravação temporária + os.replace. Controles de aceleração, perfil, natural scroll, canhoto, middle emulation, scroll horizontal/distância e alta resolução. `apply()` valida limites, verifica resultado e reverte em falha; GUI tem defaults/undo/commit, portanto abrir GUI já permite mutações antes de salvar. Watch usa lock rice-mouse-UID.lock e hotplug.

`picom-launch.sh`: mantém picom já ativo, serializa com flock; versão >=12 seleciona picom.conf, outras picom-basic.conf; fallback básico se moderno morrer no início. `--check` só relata seleção, mas source lib.sh pode criar diretório. Log picom.log. Configuração atualizada só é lida quando picom inicia/recarrega; não matar compositor como primeira medida.

`lock.sh` pode desligar saídas secundárias e restaura pelo controlador em trap EXIT/INT/TERM/HUP; `--keep-monitors` evita desligamento. Marker `lock_monitors_off` é lido apenas pelo próprio lock.sh para controlar restauração. O watcher atual não consulta esse marker; possível disputa entre hotplug/RandR e desligamento de monitores durante lock deve ser investigada, não presumida resolvida. Traps não cobrem SIGKILL/falha de energia. Ler antes de rodar; lock é alteração de sessão.

### Barra, Eww e Rofi

Nyx usa tint2; Vesper usa Eww, ambos usam controle Eww. `profile.sh --set` grava `.config/rice/profile`, altera padding e reinicia barra. `bar.sh` escolhe backend por perfil e tem fallback, serializa reinício com rice-bar.lock. Fecha popups antes de parar tint2/poll; mantém daemon Eww quente. Descritores 9/8 são fechados nos subprocessos duradouros para não prender locks. `restack-tint2.sh` baixa tint2 e depois janelas InputOnly root/Bspwm: baixar a barra ao fundo absoluto sem tratar InputOnly mantém visibilidade mas perde cliques. Nunca enviar RTMIN+3 ao tint2: termina o processo.

Fontes: `stow/desktop/.config/eww/eww.yuck`, `eww.scss`, scripts `workspaces.sh`, `sysinfo.sh`, `notif-json.sh`. SCSS importa colors.scss gerado. Janelas Yuck: bar, control, media, cc_backdrop; widgets launcher, ws, engagement_block, sysinfo, tray_block, clock_block, bar_layout, qs_tile, cc_header/tiles/sliders/engagement/calendar/notifications, control_center, cc_backdrop_area e media_center. Polls de controle usam `:run-while cc_visible`; workspaces usam deflisten em bspc subscribe; CPU/mem/temperatura e relógio possuem intervalos próprios. A árvore usa comandos rice/bin para ações, não lógica autônoma de NetworkManager/PipeWire.

`panel.sh` coordena **control e media** mutuamente, flock rice-popup.lock, anima reveal e close, abre backdrops em todos os monitores, popup no primário, inicia sxhkd temporário com `.config/rice/popup-keys.sxhkd`; Escape e clique externo fecham. PID validado por /proc/PID/cmdline antes de kill. Flags cc_visible/cc_reveal/media_reveal podem divergir da existência da janela em falha; conferir active-windows. `control.sh` e `media.sh` são fachadas. `eww-poll.sh` atualiza variáveis; --watch é daemon mutante, não diagnóstico passivo.

Mídia real: `media-state.py` via `/usr/bin/python` e gi Playerctl/GdkPixbuf/GLib, JSON por deflisten enquanto widget usa stream. Seleciona preferência explícita, tocando, Spotify, primeiro. Arte cacheada por SHA256; HTTP(S) valida host público inclusive redirects. Não executar watch para diagnóstico estritamente sem escrita: cria cache/estado e pode baixar arte. `media.sh` executa playerctl da instância em rice-media.json; seek recebe percentagem e converte pela duração. Volume usa wpctl e é áudio do sistema.

Rofi: `.config/rofi/config.rasi`, temas rice/menu/grid/power.rasi, colors.rasi gerado. Modos drun/run/window/filebrowser, terminal Kitty, fuzzy/fzf, fontes Nerd Font e Papirus. O arquivo limpa kb-remove-to-eol e kb-accept-entry antes de reassociar Ctrl+j/k: conflito de bindings pode desabilitar conjunto inteiro, inclusive setas. launcher.sh alterna launcher com pkill rofi; clipboard/emoji alteram clipboard; cheatsheet deriva comentários de sxhkdrc. Menus não são leitura: escolhas executam ações.

### Tema e arquivos derivados

`theme.sh` aplica paleta em `.config/rice/themes/*.conf`, copia para current-theme.conf, renderiza templates e recarrega bspwm, Kitty (SIGUSR1), Dunst, GTK, Neovim RPC e barra, restaurando wallpaper; lock rice-theme.lock. `--render-only` **escreve arquivos**, apenas evita manipular sessão. Alterar fonte/template, não o derivado: kitty/current-theme.conf, rofi/colors.rasi, dunst/dunstrc, tint2/tint2rc, eww/colors.scss, nvim/lua/rice-theme.lua, gtk-3.0/settings.ini, xsettingsd/xsettingsd.conf, starship.toml, betterlockscreenrc. wallpaper.sh mantém escolhas por tema, variantes portrait e cache wallfit por dimensões/identidade. wallgen.sh gera imagens com ImageMagick e trap EXIT para temporários; não gerar imagens em investigação inicial.

### Kitty, fish e Zsh: divergência concreta

`stow/desktop/.config/kitty/kitty.conf` fixa `shell /usr/bin/fish`. O checkout **não contém configuração fish** nem terminal.sh. Há configuração Zsh em `stow/shell/.zshrc` e `.zprofile`, mas abrir Kitty não garante carregar aliases/funções Zsh. Validar shell do processo (`ps`) e configuração fish pessoal antes de atribuir falhas aos dotfiles Zsh. `kitty --debug-config` exige verificar capacidades da versão; para prova mínima ler config e processo. Kitty desabilita remote control, inclui current-theme.conf e tem Ctrl+Shift+F5 load_config_file, Ctrl+Shift+Enter split, Ctrl+Shift+T nova aba cwd, Ctrl+Shift+O overlay nvim do scrollback.

Zsh carrega rice/env, plugins do sistema autosuggestions/syntax-highlighting, starship/zoxide/fzf. Histórico XDG_STATE_HOME/zsh/history, cache XDG_CACHE_HOME/zsh. Aliases eng/tgt/px/vpn/shot/theme e funções cde/target compartilham engagement/target. `.zshrc.local` é override privado. Função sudo redireciona `sudo nvim|vim|vi` só com argumentos de caminhos para sudoedit; flags preservam chamada original. Não iniciar Zsh para ler config: inicialização pode criar arquivos, executar hooks e carregar extensões locais.

### Neovim e workflow

Fonte: `stow/editor/.config/nvim/init.lua` exige options, lazy, keymaps, autocmds, theme e rice. `lua/config/lazy.lua` instala lazy.nvim via git clone se ausente e verifica updates; carregar editor normalmente não é inspeção sem escrita/rede. `lazy-lock.json` registra versões; não chamar Lazy sync/update para diagnóstico.

- `lua/plugins/ui.lua`: Catppuccin/Tokyonight/Gruvbox/Rose Pine/Oxocarbon, lualine com alvo, bufferline, which-key, Alpha, notify.
- `lua/plugins/editor.lua`: Telescope (+ fzf/ui-select), Neo-tree, gitsigns, Trouble, todo-comments, Flash, Comment, autopairs, surround, indent, toggleterm/lazygit, Oil. Gitsigns stage/reset e Oil salvando diretório alteram disco/Git.
- `lua/plugins/coding.lua`: Treesitter/textobjects (config separada em config/treesitter.lua), cmp/LuaSnip/snippets, conform com format_on_save e toggle, nvim-lint. Abrir/salvar arquivo pode invocar formatadores/linters; inspecionar config antes de usar editor para preservar conteúdo.
- `lua/plugins/lsp.lua`: API Neovim 0.11+ vim.lsp.config/enable, Mason/mason-lspconfig e mason-tool-installer; ensure_installed de servidores e ferramentas pode instalar dependências. Servidores lua_ls/bashls/pyright/ts_ls/gopls/jsonls/yamlls/html/cssls/dockerls/marksman/intelephense/rust_analyzer/clangd. Marksman deliberadamente exclui HOME, / e tmp como raiz para evitar indexar home inteiro.
- `lua/plugins/appsec.lua`: Kulala para .http (executa requests), Hex, render-markdown e nvim-dap/ui/virtual-text; adaptadores requerem configuração própria. Não tratar essas ações como consulta local passiva.
- `lua/config/rice.lua`: RiceEngagement muda cwd e revela Neo-tree; RiceNote abre/anexa journal; RiceSemgrep executa semgrep --config auto ou argumento e carrega resultados JSON no quickfix. engagement.sh também cria ENGAGEMENT_ROOT em qualquer ação, inclusive --name/--current. Acesso de engagement e lualine ao alvo é hardcoded `~/.local/share/rice`, ao contrário de lib.sh que respeita XDG_DATA_HOME; override XDG pode quebrar integração.
- Teclas: líder Space e líder local barra invertida em options.lua; Ctrl+s salva, jk sai insert, Ctrl+h/j/k/l navega splits, Alt+setas move linhas, leader xe/xn/xg engagement/journal/semgrep, leader cr/ca rename/code action, gd/gr LSP, leader cf format, leader d* DAP. `RiceReloadTheme` recarrega Lua de tema via comando remoto; logs reais via `:LspLog`/`stdpath`, não presumir caminho fixo em XDG alternativo.

### Dados, logs e persistência

- `${XDG_DATA_HOME:-~/.local/share}/rice`: target, engagement, proxy state, caffeine_enabled/caffeine.pid, dnd_enabled, power_profile, GPU flags, wallpapers por tema; `picom.log`, `tint2.log`, `eww.log`, `mouse.log`, `screenshot.log`, `ffmpeg.log`; status.sh --cpu atualiza cpu-prev; notifications.json é **JSON por linha**, não um array JSON.
- `notification-retention.py`: lock notifications.lock, escrita atômica, limite 20 linhas, TTL 7200s para tratamento de recibos/DND; filtros de OSD; serviço `.config/systemd/user/rice-notification-retention.service` opcional. Ler campos/diagnosticar sem divulgar texto das notificações.
- `~/.local/state/rice-monitors.log`: watcher iniciado pelo bspwmrc; `${XDG_STATE_HOME}` pode mudar outros logs conforme fonte. Não confundir com ~/.local/share/rice.
- `XDG_RUNTIME_DIR` ou fallback: locks de tema/barra/picom/popup/sessão, rice-popup-keys.pid/log; monitor usa /tmp/rice-UID; mouse usa /tmp/rice-mouse-UID.lock; mídia `rice-media.json`, `rice-media-preferred`, fallback cache/rice/media.
- `${XDG_CACHE_HOME:-~/.cache}/rice/wallfit`, `/rice/media`; `.config/rice/profile`, `current-theme.conf`, `mouse.json`; `~/.config/bspwm/monitors.local.sh` privado; ~/.zshrc.local.
- Wallpapers `~/Pictures/wallpapers`, VPN `~/vpn`, engagements `${ENGAGEMENT_DIR:-~/engagements}` (subpastas de notas/evidências etc.), screenshots no engagement ativo ou Pictures; Burp profissional exige instalação licenciada preexistente em ~/Burpsuite-Professional. Não imprimir credenciais VPN, histórico de shell, certificados ou contexto de cliente em relatório aberto.

### Instalação, backup, rollback e armadilhas

`scripts/install.py`: fingerprint de symlink (destino), arquivo (SHA256) ou diretório; manifest JSON atômico; inventário `.local/state/rice/managed.json`. Conflitos incluindo links quebrados/ancestrais bloqueadores movidos a `.local/state/rice/backups/<timestamp...>/files/`; manifest marca installing/installed/restored, target/repo/moved/after. Try/except **BaseException** registra alterações parciais e chama restore em falha. Restore faz preflight de fingerprints antes de remover, recusa arquivos alterados após deploy; conserva backup em conflito. Isso não substitui backup externo nem protege edição concorrente sem rechecagem.

Stow --no-folding preserva conteúdo alheio, mas mover o checkout quebra symlinks. Defaults pessoais existentes (tema/perfil/mouse) são preservados; templates gerados são arquivos regulares. `--keep-monitors` preserva controlador pessoal e não pode combinar com --adopt-monitor-layout. Adoção cria override só se não existe e exige home real+X11. --target precisa ser diretório existente fora do repo e diferente de /. Instalação real no home confere dependências; não instala pacotes nem reinicia sessão.

**Armadilha:** `./install.sh --dry-run` abre `.install.lock` em modo append no **repositório** mesmo sem alterar home. Não executar quando requisito é leitura estrita. Dry-run não pode combinar com --update/--restore. `sync.sh` exige Git limpo, faz pull --ff-only e reexec do instalador atualizado: é atualização/deploy, não mera sincronização passiva.

Helpers de sistema são separados e não chamados por instalador principal: `.config/rice/system/install.sh` exige root via sudo, valida sudoers, cria /var/backups/rice-system.XXXXXXXX/restore.sh, copia helper root /usr/local/bin/rice-powerprofile, sudoers, SDDM Xsetup e regra Xorg. Trap EXIT limpa temporário; trap ERR roda rollback; valida visudo novamente e remove ERR no sucesso. `install-performance.sh`, `install-login.py`, `install-editor.sh` requerem revisão separada antes de executar: podem alterar sistema/boot/editor/login. Não usar como “conserto geral”.

### Comandos úteis com classificação explícita

LEITURA (nenhum executado aqui contra UI):
```bash
readlink -f ~/.config/bspwm/bspwmrc ~/.config/bspwm/monitors.sh ~/.config/rice/bin/lib.sh
rg --files --hidden /home/bingxyi/rice/stow
rg -n 'shell|include' ~/.config/kitty/kitty.conf
xrandr --query
xrandr --listmonitors
bspc query -M --names
bspc query -D --names
bspc wm --dump-state
xinput list --short
xinput list-props DEVICE_ID
pgrep -a -u "$UID" -x picom
pgrep -a -u "$UID" -x tint2
ps -o pid,ppid,args -C kitty -C fish -C zsh
systemctl --user status rice-notification-retention.service --no-pager
journalctl --user -u rice-notification-retention.service --no-pager -n 50
```
Exigem sessão X11/DBus correta. Não inventar DISPLAY=:0 ou copiar cookie Xauthority; localizar ambiente do usuário da sessão. Falha de conexão não prova falha do WM. `bspc wm --dump-state` expõe títulos/caminhos potencialmente privados: reduzir saída compartilhada.

CONSULTA COM POSSÍVEL EFEITO AUXILIAR: `~/.config/rice/bin/picom-launch.sh --check`, `theme.sh --current`, `profile.sh --current` e muitos --get/--status podem criar STATE_DIR; caffeine --status pode limpar PID inválido. `eww active-windows` consultar apenas se daemon já existe e comportamento da versão estiver conhecido. Preview direto `python3 .../monitor-layout.py --plan` evita código do override, mas não o considera; wrapper --plan considera override executável.

MUTAÇÃO DE SESSÃO/ARQUIVOS, somente após hipótese sustentada e dentro da autorização: `bspc wm -r`, `pkill -USR1 -x sxhkd`, `bar.sh --restart`, `profile.sh --set vesper`, `theme.sh --apply NOME`, `monitors.sh`, `mouse-settings.py --restore`, `panel.sh close-all`, `powerprofile.sh --set balanced`, `notifications.sh --clear`, `autorandr --save NOME`. --clear apaga histórico; autorandr --save sobrescreve perfil nomeado conforme ferramenta. `vpn.sh --down` usa sudo pkill -x openvpn (alcance global); proxy --toggle altera proxy do sistema e --cert instala CA; target menu pode iniciar resolução/reconhecimento de rede; screenshots capturam informações visíveis. Não invocar menus de AppSec para diagnosticar WM.

MUTAÇÃO DE DEPLOY/SISTEMA: `./install.sh`, `./sync.sh`, `./install.sh --restore /CAMINHO/EXATO`, `sudo bash .../system/install.sh`, `systemctl --user enable --now ...`; devem ter escopo próprio. Restore deve usar comando exato impresso pelo instalador, após leitura do manifest e conferência de mudanças; não apagar conflicts para forçar.

### Catálogo verificável de todos os scripts Bash em rice/bin

As descrições e interfaces abaixo são extraídas da fonte; opções de leitura não significam ausência de efeitos de inicialização. O corpo é a autoridade para confirmar defaults/efeitos.
#### bar.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/bar.sh`

## rice :: start the active profile sidebar
##   nyx    -> tint2 (lightweight native X11 vertical panel)
##   vesper -> eww   (GTK widgets with expandable panels)
## Fall back to the other backend if the selected one is unavailable.

Interface: usage: ${SCRIPT_NAME} [--restart|--start|--stop|--help]

Tokens de opções na fonte (inclui comandos internos): `--apply`, `--help`, `--listmonitors`, `--once`, `--render-only`, `--restart`, `--screen`, `--start`, `--stop`, `--watch`

Funções: usage, main, stop_bars, start_bar, start_tint2, start_eww

#### battery.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/battery.sh`

## rice :: laptop battery status
## On machines without a battery, every block is empty,
## so the bar hides the battery without reporting an error.

Interface: usage: ${SCRIPT_NAME} [--get|--status|--icon|--tooltip|--watch|--help]

Tokens de opções na fonte (inclui comandos internos): `--get`, `--help`, `--icon`, `--status`, `--tooltip`, `--watch`

Funções: usage, main, battery_path, battery_level, battery_status, battery_icon, battery_tooltip, watch_battery

#### brightness.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/brightness.sh`

## Purpose: brightnessctl with OSD; a no-op on desktops without a backlight
## Usage: brightness.sh --up | --down | --get

Interface: # Usage: brightness.sh --up | --down | --get; echo "usage: $(basename "$0") --up|--down|--get" >&2

Tokens de opções na fonte (inclui comandos internos): `--down`, `--get`, `--up`

Funções: 

#### caffeine.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/caffeine.sh`

## rice :: keep the system awake (disable automatic locking/blanking)
##
## Two layers cover different idle paths:
##   X11 — "xset s off -dpms" disables the screensaver and display power saving
##   systemd — systemd-inhibit holds an idle/sleep lock while running
##
## The preference persists; the PID tracks only this session's inhibitor.

Interface: usage: ${SCRIPT_NAME} [--toggle|--on|--off|--status|--icon|--restore|--help]

Tokens de opções na fonte (inclui comandos internos): `--help`, `--icon`, `--mode`, `--off`, `--on`, `--restore`, `--status`, `--toggle`, `--what`, `--who`, `--why`

Funções: usage, is_on, caffeine_on, caffeine_off, refresh, main

#### cheatsheet.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/cheatsheet.sh`

## Purpose: read sxhkdrc and show shortcut comments and keys in rofi
## Usage: cheatsheet.sh

Interface: # Usage: cheatsheet.sh

Tokens de opções na fonte (inclui comandos internos): 

Funções: 

#### clipboard.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/clipboard.sh`

## Purpose: clipboard history through greenclip and rofi
## Usage: clipboard.sh

Interface: # Usage: clipboard.sh

Tokens de opções na fonte (inclui comandos internos): 

Funções: 

#### control.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/control.sh`

## rice :: Eww control center on the right of the primary monitor
##
## Animation needs two steps: create the window before sliding the revealer.
## Opening and revealing at once would show the full panel immediately.
## Use open -> brief delay -> reveal to preserve the transition.
##
## Works with either profile: start the Eww daemon on demand,
## including in Nyx, where tint2 provides the bar.

Interface: usage: ${SCRIPT_NAME} [--toggle|--open|--close|--status|--glyph|--help]

Tokens de opções na fonte (inclui comandos internos): `--close`, `--glyph`, `--help`, `--open`, `--status`, `--toggle`

Funções: usage, print_glyph, main

#### emoji.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/emoji.sh`

## Purpose: pick glyphs/emoji for reports and notes, then copy to the clipboard
## Usage: emoji.sh

Interface: # Usage: emoji.sh

Tokens de opções na fonte (inclui comandos internos): 

Funções: 

#### engagement.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/engagement.sh`

## rice :: manage engagements (structure, notes, session context)
## The active engagement feeds the bar, shell prompt, and screenshot.sh.

Interface: usage: ${SCRIPT_NAME} [options]

Tokens de opções na fonte (inclui comandos internos): `--close`, `--current`, `--directory`, `--evidence`, `--help`, `--menu`, `--name`, `--new`, `--note`, `--switch`, `--terminal`, `--version`

Funções: usage, main, menu_engagement, new_engagement, write_readme, switch_engagement, load_target, current_path, print_name, open_terminal, open_files, quick_note, evidence_dir, close_engagement, refresh_bar

#### eww-poll.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/eww-poll.sh`

## rice :: synchronize Eww variables with the current state
## Called when the Vesper bar starts and optionally in a loop.

Interface: usage: ${SCRIPT_NAME} [--once|--watch [seconds]|--help]

Tokens de opções na fonte (inclui comandos internos): `--count`, `--get`, `--help`, `--name`, `--once`, `--status`, `--watch`

Funções: usage, main, push

#### launcher.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/launcher.sh`

## Purpose: application launcher (rofi drun) using the active theme
## Usage: launcher.sh

Interface: # Usage: launcher.sh

Tokens de opções na fonte (inclui comandos internos): 

Funções: 

#### lib.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/lib.sh`

## rice :: shared script library
## Usage: . "$HOME/.config/rice/bin/lib.sh"

Interface: # Usage: . "$HOME/.config/rice/bin/lib.sh"

Tokens de opções na fonte (inclui comandos internos): 

Funções: theme_get, state_get, state_set, state_clear, notify, rofi_menu, rofi_input, rofi_confirm, exit_on_missing_tools, active_profile

#### lock.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/lock.sh`

## rice :: lock the session using the active theme
##
## Turn off secondary monitors through xrandr while locked.
## The greeter draws only on the primary output; the portrait monitor stays
## black instead of displaying a stretched lock screen.
##
## Restore monitors through EXIT/INT/TERM/HUP traps if the locker exits,
## is killed, or the session ends. Always restore disabled outputs.

Interface: usage: ${SCRIPT_NAME} [--keep-monitors|--help]

Tokens de opções na fonte (inclui comandos internos): `--auto`, `--fx`, `--help`, `--keep-monitors`, `--lock`, `--nofork`, `--off`, `--output`, `--query`, `--update`

Funções: usage, primary_monitor, secondary_monitors, monitors_off, monitors_restore, do_lock, main

#### media.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/media.sh`



Tokens de opções na fonte (inclui comandos internos): `--close`, `--format`, `--glyph`, `--open`, `--player`, `--status`, `--toggle`

Funções: 

#### network.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/network.sh`

## rice :: network menu (nmcli) and bar status

Interface: usage: ${SCRIPT_NAME} [--menu|--status|--icon|--wifi-state|--wifi-name|--wifi-toggle|--help]

Tokens de opções na fonte (inclui comandos internos): `--active`, `--help`, `--icon`, `--menu`, `--rescan`, `--status`, `--wifi-name`, `--wifi-state`, `--wifi-toggle`

Funções: usage, main, menu_network, connect_wifi, wifi_state, wifi_name, wifi_toggle, print_status, print_icon

#### notif-log.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/notif-log.sh`

## Shared atomic history writer; the local receipt monitor adds DND deadlines.

Tokens de opções na fonte (inclui comandos internos): 

Funções: 

#### notifications.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/notifications.sh`

## rice :: notification center

Interface: usage: ${SCRIPT_NAME} [--toggle|--list|--clear|--dnd|--count|--status|--restore|--help]

Tokens de opções na fonte (inclui comandos internos): `--clear`, `--count`, `--dnd`, `--help`, `--list`, `--restore`, `--status`, `--toggle`

Funções: usage, main, toggle_center, list_rofi, build_list, clear_all, toggle_dnd, count_notifications, print_status, refresh_bar

#### panel.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/panel.sh`

## Shared popup lifetime: serialized switching, outside click, temporary Escape.

Tokens de opções na fonte (inclui comandos internos): `--id`, `--listmonitors`, `--screen`

Funções: ew, active, stop_keys, close_panels

#### picom-launch.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/picom-launch.sh`

## Purpose: start picom with a configuration suited to the installed version.
##   picom >= 12 -> picom.conf       (native animations, "rules" syntax)
##   picom <  12 -> picom-basic.conf (no animations, legacy syntax)
## If the selected configuration fails, try the basic one before giving up.
## Usage: picom-launch.sh [--check]

Interface: # Usage: picom-launch.sh [--check]; usage: ${SCRIPT_NAME} [--check|--help]

Tokens de opções na fonte (inclui comandos internos): `--check`, `--config`, `--help`, `--version`

Funções: usage, main, picom_major, pick_config, start_picom, report_choice, notify_user

#### powermenu.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/powermenu.sh`

## rice :: power menu with confirmation

Interface: usage: ${SCRIPT_NAME} [--help]

Tokens de opções na fonte (inclui comandos internos): `--help`

Funções: usage, main, confirm_and_run, run_suspend

#### powerprofile.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/powerprofile.sh`

## rice :: power profile (always readable; writable with a helper)
##
## Backend preference:
##   1. powerprofilesctl (power-profiles-daemon), authorized through polkit
##   2. /usr/local/bin/rice-powerprofile through sudo -n, with fixed arguments
##   3. read-only mode with instructions for installing the missing backend
##
## Reading never requires privileges: the bar always shows the current state.

Interface: usage: ${SCRIPT_NAME} [options]

Tokens de opções na fonte (inclui comandos internos): `--available`, `--cycle`, `--get`, `--gpu`, `--help`, `--icon`, `--label`, `--menu`, `--restore`, `--set`

Funções: usage, current_profile, can_write, set_profile, gpu_powermizer, gpu_blocked, announce, eww_refresh, icon_for, label_for, icon_name_for, cycle_profile, menu_profile, main

#### profile.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/profile.sh`

## rice :: switch between Nyx and Vesper without logging out

Interface: usage: ${SCRIPT_NAME} [--menu|--set <nyx|vesper>|--current|--help]

Tokens de opções na fonte (inclui comandos internos): `--current`, `--help`, `--menu`, `--names`, `--query`, `--restart`, `--set`

Funções: usage, main, menu_profile, set_profile

#### proxy.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/proxy.sh`

## rice :: interception proxy (Burp/ZAP/mitmproxy) and related tools

Interface: usage: ${SCRIPT_NAME} [options]

Tokens de opções na fonte (inclui comandos internos): `--burp`, `--cert`, `--class`, `--directory`, `--firefox`, `--help`, `--hold`, `--listen-port`, `--menu`, `--mitm`, `--no-remote`, `--proxy`, `--status`, `--toggle`, `--zap`

Funções: usage, main, menu_proxy, start_burp, start_zap, start_mitm, start_firefox, toggle_system_proxy, install_burp_cert, proxy_listening, proxy_status

#### resize.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/resize.sh`

## Purpose: move the node boundary in the requested direction (tiled or floating)
## Usage: resize.sh <west|south|north|east> [px] [node]
##
## Try the forward edge first to grow the window in the requested direction.
## If there is no neighbor, use the opposite edge to shrink it. Both cases
## move the boundary toward the arrow; floating windows use the first edge.

Interface: # Usage: resize.sh <west|south|north|east> [px] [node]; echo "usage: $(basename "$0") <west|south|north|east> [px] [node]" >&2

Tokens de opções na fonte (inclui comandos internos): 

Funções: 

#### restack-tint2.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/restack-tint2.sh`

## Keep tint2 below applications, but above bspwm's invisible input windows.

Tokens de opções na fonte (inclui comandos internos): `--class`, `--classname`, `--onlyvisible`

Funções: 

#### rice-menu.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/rice-menu.sh`

## rice :: AppSec hub (Super+O)
## Common application security tasks, one shortcut away.

Interface: usage: ${SCRIPT_NAME} [--help|--version]

Tokens de opções na fonte (inclui comandos internos): `--directory`, `--help`, `--hold`, `--list`, `--menu`, `--min-rate`, `--name`, `--set`, `--status`, `--title`, `--top-ports`, `--version`

Funções: usage, main, header, main_menu, require_target, scans_dir, run_in_terminal, recon_menu, run_ffuf, server_menu, utils_menu, clip_transform, hash_clipboard, lhost, copy_tun_ip, revshell_menu

#### screenshot.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/screenshot.sh`

## rice :: save screenshots directly to the engagement evidence directory

Interface: usage: ${SCRIPT_NAME} [--menu|--area|--full|--window|--record|--help]

Tokens de opções na fonte (inclui comandos internos): `--area`, `--clipboard`, `--dest`, `--evidence`, `--full`, `--help`, `--menu`, `--method`, `--object-path`, `--path`, `--record`, `--region`, `--session`, `--window`

Funções: usage, engagement_dir_preview, main, target_dir, filename, menu_shot, shot_area, flameshot_ready, ensure_flameshot, shot_full, shot_window, finish, toggle_record

#### session-restore.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/session-restore.sh`

## Restore only preferences explicitly selected by the user.

Tokens de opções na fonte (inclui comandos internos): `--restore`

Funções: 

#### status.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/status.sh`

## rice :: compact status blocks for tint2 executors
## Each block prints a few glyph lines to fit the 46px bar.

Interface: usage: ${SCRIPT_NAME} [--engagement|--network|--system|--volume|--notifications|--battery|--help]

Tokens de opções na fonte (inclui comandos internos): `--battery`, `--count`, `--engagement`, `--get`, `--help`, `--icon`, `--network`, `--notifications`, `--status`, `--system`, `--volume`

Funções: usage, main, span, block_engagement, block_network, network_online, block_system, cpu_usage, temperature, block_volume, block_notifications, block_battery

#### target.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/target.sh`

## rice :: active target for the bar, prompt, and $TARGET variable

Interface: usage: ${SCRIPT_NAME} [--menu|--set <target>|--get|--clear|--copy|--help]

Tokens de opções na fonte (inclui comandos internos): `--clear`, `--copy`, `--get`, `--help`, `--hold`, `--menu`, `--set`, `--top-ports`

Funções: usage, main, menu_target, set_target, persist_in_engagement, clear_target, copy_target, open_browser, quick_scan, refresh_bar

#### theme.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/theme.sh`

## rice :: theme engine
## Apply a palette from ~/.config/rice/themes/*.conf to kitty, rofi, dunst,
## tint2, Eww, Neovim, GTK, bspwm borders, and the lock screen in one command.

Interface: usage: ${SCRIPT_NAME} [--apply <theme>|--menu|--list|--current|--next|--help|--version]

Tokens de opções na fonte (inclui comandos internos): `--apply`, `--current`, `--help`, `--list`, `--menu`, `--next`, `--remote-send`, `--render-only`, `--restart`, `--restore`, `--server`, `--sync`, `--version`

Funções: usage, main, list_themes, menu_theme, next_theme, apply_theme, apply_theme_locked, render, reload_bspwm_colors, reload_kitty, reload_dunst, reload_gtk, reload_nvim, reload_bar, set_theme_wallpaper

#### volume.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/volume.sh`

## rice :: volume with OSD (wpctl/PipeWire)

Interface: usage: ${SCRIPT_NAME} [--up|--down|--toggle|--mic-toggle|--set <0-100>|--get|--icon|--help]

Tokens de opções na fonte (inclui comandos internos): `--down`, `--get`, `--help`, `--icon`, `--mic-toggle`, `--set`, `--toggle`, `--up`

Funções: usage, main, set_volume, get_volume, is_muted, volume_icon, osd, notify_osd, refresh_bar, exit_on_missing_tools

#### vpn.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/vpn.sh`

## rice :: lab VPN (OpenVPN/WireGuard) with bar status

Interface: usage: ${SCRIPT_NAME} [--menu|--up <file.ovpn>|--down|--status|--help]

Tokens de opções na fonte (inclui comandos internos): `--class`, `--config`, `--down`, `--help`, `--hold`, `--menu`, `--status`, `--up`

Funções: usage, main, menu_vpn, vpn_up, vpn_down, vpn_status, refresh_bar

#### wallgen.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/wallgen.sh`

## rice :: generate an abstract wallpaper from a theme palette
## Provide a default for themes without their own artwork.
## Usage: wallgen.sh <theme> [output.png] | --all | --force <theme>

Interface: # Usage: wallgen.sh <theme> [output.png] | --all | --force <theme>

Tokens de opções na fonte (inclui comandos internos): `--all`, `--force`, `--help`

Funções: color_of, glow, render_canvas, portrait_path, load_colors, generate, generate_portrait

#### wallpaper.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/wallpaper.sh`

## rice :: wallpaper picker with rofi grid previews

Interface: usage: ${SCRIPT_NAME} [--menu|--set <file>|--restore|--set-theme <file>|--random|--unpin|--help]

Tokens de opções na fonte (inclui comandos internos): `--bg-fill`, `--fx`, `--help`, `--menu`, `--no-fehbg`, `--random`, `--restore`, `--set`, `--set-theme`, `--unpin`, `--version`

Funções: usage, main, list_wallpapers, menu_wallpaper, wallpaper_key, migrate_wallpaper, xinerama_heads, portrait_variant, render_for_monitor, apply_wallpaper, set_wallpaper, unpin_wallpaper, restore_wallpaper, random_wallpaper

#### workspace.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/workspace.sh`

## rice :: focus/send workspaces with any monitors.sh layout
## Use numeric desktop names when available; otherwise use the desktop index
## on the focused monitor. Never write to monitors.sh.

Interface: usage: ${SCRIPT_NAME} [--focus|--send] <number>

Tokens de opções na fonte (inclui comandos internos): `--focus`, `--follow`, `--help`, `--names`, `--send`

Funções: usage, main, resolve_desktop

#### ws-tint2.sh

Fonte: `/home/bingxyi/rice/stow/desktop/.config/rice/bin/ws-tint2.sh`

## rice :: Nyx workspace column (tint2 executor)
## Always print exactly ten lines (execp_continuous = 10), one per workspace,
## with an icon for its role in the AppSec workflow.
## Do not rename desktops; monitors.sh owns their names.

Interface: usage: ${SCRIPT_NAME} [--menu|--once|--help]

Tokens de opções na fonte (inclui comandos internos): `--help`, `--menu`, `--names`, `--once`

Funções: usage, main, render, is_occupied, is_urgent, menu_workspaces

### Inventário de plugins por arquivo (extração literal)

- `/home/bingxyi/rice/stow/editor/.config/nvim/lua/plugins/appsec.lua`: MeanderingProgrammer/render-markdown.nvim, RaafatTurki/hex.nvim, body/headers, mfussenegger/nvim-dap, mistweaverco/kulala.nvim, nvim-neotest/nvim-nio, nvim-tree/nvim-web-devicons, nvim-treesitter/nvim-treesitter, rcarriga/nvim-dap-ui, theHamsta/nvim-dap-virtual-text
- `/home/bingxyi/rice/stow/editor/.config/nvim/lua/plugins/coding.lua`: L3MON4D3/LuaSnip, hrsh7th/cmp-buffer, hrsh7th/cmp-cmdline, hrsh7th/cmp-nvim-lsp, hrsh7th/cmp-path, hrsh7th/nvim-cmp, mfussenegger/nvim-lint, nvim-treesitter/nvim-treesitter, nvim-treesitter/nvim-treesitter-textobjects, onsails/lspkind.nvim, rafamadriz/friendly-snippets, saadparwaiz1/cmp_luasnip, stevearc/conform.nvim
- `/home/bingxyi/rice/stow/editor/.config/nvim/lua/plugins/editor.lua`: MunifTanjim/nui.nvim, akinsho/toggleterm.nvim, folke/flash.nvim, folke/todo-comments.nvim, folke/trouble.nvim, kylechui/nvim-surround, lewis6991/gitsigns.nvim, lukas-reineke/indent-blankline.nvim, numToStr/Comment.nvim, nvim-lua/plenary.nvim, nvim-neo-tree/neo-tree.nvim, nvim-telescope/telescope-fzf-native.nvim, nvim-telescope/telescope-ui-select.nvim, nvim-telescope/telescope.nvim, nvim-tree/nvim-web-devicons, stevearc/oil.nvim, windwp/nvim-autopairs
- `/home/bingxyi/rice/stow/editor/.config/nvim/lua/plugins/lsp.lua`: WhoIsSethDaniel/mason-tool-installer.nvim, hrsh7th/cmp-nvim-lsp, mason-org/mason-lspconfig.nvim, mason-org/mason.nvim, neovim/nvim-lspconfig, textDocument/documentHighlight, textDocument/inlayHint
- `/home/bingxyi/rice/stow/editor/.config/nvim/lua/plugins/ui.lua`: MunifTanjim/nui.nvim, Terminal/test, akinsho/bufferline.nvim, appsec/payloads, catppuccin/nvim, folke/tokyonight.nvim, folke/which-key.nvim, goolord/alpha-nvim, nvim-lua/plenary.nvim, nvim-lualine/lualine.nvim, nvim-tree/nvim-web-devicons, nyoom-engineering/oxocarbon.nvim, rcarriga/nvim-notify, rose-pine/neovim, sainnhe/gruvbox-material

## Mapa completo de binds


### Índice

- [sxhkd: mapa completo expandido](#sxhkd-mapa-completo-expandido)
- [Kitty](#kitty)
- [Neovim](#neovim)

### sxhkd: mapa completo expandido

Fonte: `~/rice/stow/desktop/.config/sxhkd/sxhkdrc` (distribuição) e `~/.config/sxhkd/sxhkdrc` (cópia ativa editável).
Super é Mod4. Listas foram expandidas e casadas com os comandos na mesma ordem.
Antes de editar, releia o arquivo atual e execute `scripts/check.py`.

| Teclas | Comando exato |
|---|---|
| `super + Escape` | `pkill -USR1 -x sxhkd && notify-send -a archlinux "sxhkd" "Shortcuts reloaded"` |
| `super + shift + r` | `bspc wm -r && notify-send -a archlinux "bspwm" "Session reloaded"` |
| `super + x` | `~/.config/rice/bin/powermenu.sh` |
| `super + shift + x` | `~/.config/rice/bin/lock.sh` |
| `super + slash` | `~/.config/rice/bin/cheatsheet.sh` |
| `super + Return` | `kitty` |
| `super + shift + Return` | `kitty --class scratchpad` |
| `super + ctrl + Return` | `~/.config/rice/bin/engagement.sh --terminal` |
| `super + d` | `~/.config/rice/bin/launcher.sh` |
| `super + shift + d` | `rofi -show run -theme ~/.config/rofi/themes/rice.rasi` |
| `super + Tab` | `rofi -show window -theme ~/.config/rofi/themes/rice.rasi` |
| `super + e` | `kitty --class yazi -e yazi` |
| `super + shift + e` | `thunar` |
| `super + n` | `kitty -e nvim` |
| `super + b` | `firefox` |
| `super + v` | `~/.config/rice/bin/clipboard.sh` |
| `super + alt + period` | `~/.config/rice/bin/emoji.sh` |
| `super + t` | `~/.config/rice/bin/theme.sh --menu` |
| `super + w` | `~/.config/rice/bin/wallpaper.sh --menu` |
| `super + shift + p` | `~/.config/rice/bin/profile.sh --menu` |
| `super + alt + n` | `~/.config/rice/bin/notifications.sh --toggle` |
| `super + c` | `~/.config/rice/bin/control.sh --toggle` |
| `super + shift + n` | `~/.config/rice/bin/control.sh --toggle` |
| `super + ctrl + m` | `~/.config/rice/bin/media.sh --toggle` |
| `super + shift + c` | `~/.config/rice/bin/rice-menu.sh` |
| `super + ctrl + c` | `~/.config/rice/bin/caffeine.sh --toggle` |
| `super + ctrl + p` | `~/.config/rice/bin/powerprofile.sh --cycle` |
| `super + ctrl + n` | `dunstctl close` |
| `super + o` | `~/.config/rice/bin/rice-menu.sh` |
| `super + shift + o` | `~/.config/rice/bin/target.sh --menu` |
| `super + shift + v` | `~/.config/rice/bin/vpn.sh --menu` |
| `super + shift + b` | `~/.config/rice/bin/proxy.sh --burp` |
| `super + shift + m` | `~/.config/rice/bin/engagement.sh --note` |
| `Print` | `~/.config/rice/bin/screenshot.sh --area` |
| `shift + Print` | `~/.config/rice/bin/screenshot.sh --full` |
| `ctrl + Print` | `~/.config/rice/bin/screenshot.sh --window` |
| `super + Print` | `~/.config/rice/bin/screenshot.sh --record` |
| `super + shift + s` | `~/.config/rice/bin/screenshot.sh --area` |
| `super + q` | `bspc node -c` |
| `super + shift + q` | `bspc node -k` |
| `super + shift + space` | `bspc node -t "~"floating` |
| `super + f` | `bspc node -t "~"fullscreen` |
| `super + shift + f` | `bspc node -t "~"pseudo_tiled` |
| `super + m` | `bspc desktop -l next` |
| `super + s` | `bspc node -g sticky` |
| `super + minus` | `bspc node -g hidden` |
| `super + shift + minus` | `bspc node "$(bspc query -N -d -n .hidden \| head -n1)" -g hidden=off` |
| `super + h` | `bspc node -f west` |
| `super + j` | `bspc node -f south` |
| `super + k` | `bspc node -f north` |
| `super + l` | `bspc node -f east` |
| `super + Left` | `bspc node -f west` |
| `super + Down` | `bspc node -f south` |
| `super + Up` | `bspc node -f north` |
| `super + Right` | `bspc node -f east` |
| `super + shift + h` | `bspc node -s west --follow` |
| `super + shift + j` | `bspc node -s south --follow` |
| `super + shift + k` | `bspc node -s north --follow` |
| `super + shift + l` | `bspc node -s east --follow` |
| `super + shift + Left` | `bspc node -s west --follow` |
| `super + shift + Down` | `bspc node -s south --follow` |
| `super + shift + Up` | `bspc node -s north --follow` |
| `super + shift + Right` | `bspc node -s east --follow` |
| `super + grave` | `bspc node -f last` |
| `super + apostrophe` | `bspc node -f last` |
| `super + r` | `bspc node @parent -R 90` |
| `super + shift + equal` | `bspc node @parent -B` |
| `super + alt + h` | `~/.config/rice/bin/resize.sh west 40` |
| `super + alt + j` | `~/.config/rice/bin/resize.sh south 40` |
| `super + alt + k` | `~/.config/rice/bin/resize.sh north 40` |
| `super + alt + l` | `~/.config/rice/bin/resize.sh east 40` |
| `super + alt + Left` | `~/.config/rice/bin/resize.sh west 40` |
| `super + alt + Down` | `~/.config/rice/bin/resize.sh south 40` |
| `super + alt + Up` | `~/.config/rice/bin/resize.sh north 40` |
| `super + alt + Right` | `~/.config/rice/bin/resize.sh east 40` |
| `super + ctrl + h` | `bspc node -p west` |
| `super + ctrl + j` | `bspc node -p south` |
| `super + ctrl + k` | `bspc node -p north` |
| `super + ctrl + l` | `bspc node -p east` |
| `super + ctrl + space` | `bspc node -p cancel` |
| `super + bracketleft` | `bspc config -d focused window_gap "$(($(bspc config -d focused window_gap) - 4))"` |
| `super + bracketright` | `bspc config -d focused window_gap "$(($(bspc config -d focused window_gap) + 4))"` |
| `super + 1` | `~/.config/rice/bin/workspace.sh --focus 1` |
| `super + 2` | `~/.config/rice/bin/workspace.sh --focus 2` |
| `super + 3` | `~/.config/rice/bin/workspace.sh --focus 3` |
| `super + 4` | `~/.config/rice/bin/workspace.sh --focus 4` |
| `super + 5` | `~/.config/rice/bin/workspace.sh --focus 5` |
| `super + 6` | `~/.config/rice/bin/workspace.sh --focus 6` |
| `super + 7` | `~/.config/rice/bin/workspace.sh --focus 7` |
| `super + 8` | `~/.config/rice/bin/workspace.sh --focus 8` |
| `super + 9` | `~/.config/rice/bin/workspace.sh --focus 9` |
| `super + 0` | `~/.config/rice/bin/workspace.sh --focus 10` |
| `super + shift + 1` | `~/.config/rice/bin/workspace.sh --send 1` |
| `super + shift + 2` | `~/.config/rice/bin/workspace.sh --send 2` |
| `super + shift + 3` | `~/.config/rice/bin/workspace.sh --send 3` |
| `super + shift + 4` | `~/.config/rice/bin/workspace.sh --send 4` |
| `super + shift + 5` | `~/.config/rice/bin/workspace.sh --send 5` |
| `super + shift + 6` | `~/.config/rice/bin/workspace.sh --send 6` |
| `super + shift + 7` | `~/.config/rice/bin/workspace.sh --send 7` |
| `super + shift + 8` | `~/.config/rice/bin/workspace.sh --send 8` |
| `super + shift + 9` | `~/.config/rice/bin/workspace.sh --send 9` |
| `super + shift + 0` | `~/.config/rice/bin/workspace.sh --send 10` |
| `super + ctrl + comma` | `bspc desktop -f prev.local` |
| `super + ctrl + period` | `bspc desktop -f next.local` |
| `super + comma` | `bspc monitor -f prev` |
| `super + period` | `bspc monitor -f next` |
| `super + shift + comma` | `bspc node -m prev --follow` |
| `super + shift + period` | `bspc node -m next --follow` |
| `XF86AudioRaiseVolume` | `~/.config/rice/bin/volume.sh --up` |
| `XF86AudioLowerVolume` | `~/.config/rice/bin/volume.sh --down` |
| `XF86AudioMute` | `~/.config/rice/bin/volume.sh --toggle` |
| `XF86AudioMicMute` | `~/.config/rice/bin/volume.sh --mic-toggle` |
| `XF86AudioPlay` | `playerctl play-pause` |
| `XF86AudioPrev` | `playerctl previous` |
| `XF86AudioNext` | `playerctl next` |
| `XF86MonBrightnessUp` | `~/.config/rice/bin/brightness.sh --up` |
| `XF86MonBrightnessDown` | `~/.config/rice/bin/brightness.sh --down` |
| `super + alt + m` | `~/.config/rice/bin/mouse-settings.py` |

### Kitty

Fonte: `stow/desktop/.config/kitty/kitty.conf`; Ctrl+Shift é separado dos binds Super.
Shell efetivo configurado: `/usr/bin/fish`.

| Teclas | Ação |
|---|---|
| `ctrl+shift+c` | `copy_to_clipboard` |
| `ctrl+shift+v` | `paste_from_clipboard` |
| `ctrl+shift+enter` | `launch --location=split --cwd=current` |
| `ctrl+shift+t` | `new_tab_with_cwd` |
| `ctrl+shift+w` | `close_window` |
| `ctrl+shift+h` | `show_scrollback` |
| `ctrl+shift+f5` | `load_config_file` |
| `ctrl+shift+equal` | `change_font_size all +1.0` |
| `ctrl+shift+minus` | `change_font_size all -1.0` |
| `ctrl+shift+0` | `change_font_size all 0` |
| `ctrl+shift+left` | `neighboring_window left` |
| `ctrl+shift+right` | `neighboring_window right` |
| `ctrl+shift+up` | `neighboring_window up` |
| `ctrl+shift+down` | `neighboring_window down` |
| `ctrl+shift+l` | `next_layout` |
| `ctrl+shift+o` | `launch --type=overlay --stdin-source=@screen_scrollback nvim -` |
| `ctrl+shift+e` | `open_url_with_hints` |
| `ctrl+shift+p>f` | `kitten hints --type path --program -` |
| `ctrl+shift+p>l` | `kitten hints --type line --program -` |
| `ctrl+shift+p>h` | `kitten hints --type hash --program -` |
| `ctrl+shift+p>i` | `kitten hints --type ip --program @` |
| `ctrl+shift+a>m` | `set_background_opacity +0.05` |
| `ctrl+shift+a>l` | `set_background_opacity -0.05` |
| `ctrl+shift+a>1` | `set_background_opacity 1` |

### Neovim

Fonte básica: `stow/editor/.config/nvim/lua/config/keymaps.lua`.
AppSec: `lua/config/rice.lua` e `lua/plugins/appsec.lua`. Leia modo e contexto de filetype.
Os trechos abaixo são fontes Lua, não comandos shell para executar.

```lua
local map = vim.keymap.set

-- Basics.
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlighting" })
map("n", "<C-s>", "<cmd>write<CR>", { desc = "Save" })
map("i", "<C-s>", "<Esc><cmd>write<CR>", { desc = "Save" })
map("n", "<leader>qq", "<cmd>qa<CR>", { desc = "Quit all" })

-- Window navigation, matching bspwm.
map("n", "<C-h>", "<C-w>h", { desc = "Focus left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Focus window below" })
map("n", "<C-k>", "<C-w>k", { desc = "Focus window above" })
map("n", "<C-l>", "<C-w>l", { desc = "Focus right window" })
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase width" })

-- splits
map("n", "<leader>-", "<cmd>split<CR>", { desc = "Horizontal split" })
map("n", "<leader>|", "<cmd>vsplit<CR>", { desc = "Vertical split" })

-- buffers
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Close buffer" })
map("n", "<leader>bo", "<cmd>%bd|e#|bd#<CR>", { desc = "Close other buffers" })

-- Move lines with Alt+arrows (as in VS Code) or Alt+j/k for hjkl navigation.
-- Move the full line without changing its contents; == reindents at the destination.
map("n", "<A-Down>", "<cmd>m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-Up>", "<cmd>m .-2<CR>==", { desc = "Move line up" })
map("i", "<A-Down>", "<Esc><cmd>m .+1<CR>==gi", { desc = "Move line down" })
map("i", "<A-Up>", "<Esc><cmd>m .-2<CR>==gi", { desc = "Move line up" })
map("v", "<A-Down>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-Up>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

map("n", "<A-j>", "<cmd>m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<CR>==", { desc = "Move line up" })
map("i", "<A-j>", "<Esc><cmd>m .+1<CR>==gi", { desc = "Move line down" })
map("i", "<A-k>", "<Esc><cmd>m .-2<CR>==gi", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
map("v", "<", "<gv", { desc = "Unindent and keep selection" })
map("v", ">", ">gv", { desc = "Indent and keep selection" })

-- Center the view while navigating.
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Paste without losing the register contents.
map("v", "p", '"_dP', { desc = "Paste without overwriting the register" })
map({ "n", "v" }, "<leader>d", '"_d', { desc = "Delete without copying" })

-- Diagnostics.
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Diagnostic details" })

-- AppSec: payload utilities directly in the editor.
map("v", "<leader>xb", ":!base64 -w0<CR>", { desc = "Base64 encode selection" })
map("v", "<leader>xB", ":!base64 -d<CR>", { desc = "Base64 decode selection" })
map("v", "<leader>xu", ":!jq -sRr @uri<CR>", { desc = "URL encode selection" })
map("v", "<leader>xj", ":!jq .<CR>", { desc = "Format selected JSON" })
map("n", "<leader>xJ", "<cmd>%!jq .<CR>", { desc = "Format entire JSON file" })
map("v", "<leader>xh", ":!xxd<CR>", { desc = "Hexdump selection" })
map("v", "<leader>xs", ":!sort -u<CR>", { desc = "Sort and deduplicate" })
```

#### Comandos e binds de integração AppSec

```lua
-- stow/editor/.config/nvim/lua/config/rice.lua
    vim.api.nvim_create_user_command("RiceEngagement", function()
    vim.api.nvim_create_user_command("RiceNote", function(cmd)
    vim.api.nvim_create_user_command("RiceSemgrep", function(cmd)
    vim.keymap.set("n", "<leader>xg", "<cmd>RiceSemgrep<CR>", { desc = "Run semgrep on project" })
    vim.keymap.set("n", "<leader>xe", "<cmd>RiceEngagement<CR>", { desc = "Open active engagement" })
    vim.keymap.set("n", "<leader>xn", "<cmd>RiceNote<CR>", { desc = "Engagement journal" })
-- stow/editor/.config/nvim/lua/plugins/appsec.lua
      { "<leader>hs", function() require("kulala").run() end, desc = "Send request", ft = "http" },
      { "<leader>ha", function() require("kulala").run_all() end, desc = "Send all requests", ft = "http" },
      { "<leader>hn", function() require("kulala").jump_next() end, desc = "Next request", ft = "http" },
      { "<leader>hp", function() require("kulala").jump_prev() end, desc = "Previous request", ft = "http" },
      { "<leader>ht", function() require("kulala").toggle_view() end, desc = "body/headers", ft = "http" },
      { "<leader>hc", function() require("kulala").copy() end, desc = "Copy as curl", ft = "http" },
      { "<leader>xH", "<cmd>HexToggle<CR>", desc = "Toggle hex view" },
      { "<leader>mp", "<cmd>RenderMarkdown preview<CR>", desc = "Markdown: side preview", ft = "markdown" },
      { "<leader>mt", "<cmd>RenderMarkdown buf_toggle<CR>", desc = "Markdown: toggle rendering", ft = "markdown" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
      { "<leader>di", function() require("dap").step_into() end, desc = "step into" },
      { "<leader>do", function() require("dap").step_over() end, desc = "step over" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "step out" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Debug panel" },
```

Esses comandos podem rodar Semgrep ou enviar requisições HTTP; documentar o bind não autoriza executá-los em alvos reais.

## Diagnóstico e recuperação


### Começo seguro

1. `git -C ~/rice status --short` e `git -C ~/rice rev-parse HEAD`.
2. Veja se o alvo instalado é arquivo real (estado atual) ou symlink legado.
   No modelo atual, edições em ~/.config não alteram ~/rice automaticamente.
3. Rode o coletor da skill (somente versões, configs permitidas e consultas).
4. Confirme acesso real a X11 e BSPWM. Erro de sandbox/socket não é evidência de
   falha de hardware. Não imprima conteúdo de XAUTHORITY nem use cookies no relatório.
5. Leia apenas os logs relevantes, respeitando dados privados e limites de saída.

### HDMI, docking, tampa e desktops

Consultas: `xrandr --query`, `bspc query -M --names`, `bspc query -D --names`,
`bspc wm --dump-state` (pode conter detalhes de janelas; use só localmente).
Fontes: **monitors.sh** (plural), monitor-layout.py,
monitor-sync.py, monitors.local.sh e local.sh. Não crie um `monitor.sh` paralelo.
O wrapper carrega os exports do override privado antes do Python.

Verifique: saída conectada vs ativa; geometria e rotação; preferência ausente;
modo preferido e taxas disponíveis; estado da tampa; perfil autorandr realmente
detectado; processo --watch único e log de monitores; concorrência de local.sh.
A ordem lógica é a da barra/primária, não necessariamente esquerda→direita.
O usuário confirmou HDMI à esquerda: `RICE_MONITOR_LAYOUT=ordered` +
`RICE_MONITOR_ORDER='HDMI-1 eDP-1'` corrige fisicamente esse caso. No padrão
preserve as geometrias ativas são mantidas. ordered ignora perfis autorandr para
que uma preferência física explícita não seja revertida por um perfil antigo.

`monitors.sh --plan` só descreve argv de xrandr do caminho automático e não
aplica layout. O apply pode escolher um perfil autorandr detectado; não trate o
plan como reprodução exata de todo efeito do perfil/controller/desktop.
Não execute `monitors.sh` sem --plan em um diagnóstico apenas de leitura.

Para corrigir, quando autorizado: copie antes os arquivos/estado; teste sem X11
com fixtures de saídas e modelo de desktops; teste single, dual, replug, três+,
retrato/coordenadas negativas, no-output, modo/taxa recusados e perfil salvo.
No apply real, compare clientes e desktops por nome/tela e foco. Não remova
monitores desconectados antes de transferir todos os desktops/janelas.

### Binds, ABNT2 e grabs

Fonte: sxhkdrc. Confirme teclas com `setxkbmap -query` e, se necessário, xev
interativo apenas quando autorizado. Diferencie uma keysym morta de um comando
que falha: `grave` não é a mesma tecla direta do alias `apostrophe` em ABNT2.

O mapa contém 118 combinações expandidas na data inicial; confirme o número via
scripts/check.py após mudanças. Preserve binds upstream e alias local. Para
identificar duplicatas, normalize modificadores e expanda as chaves na ordem;
comandos com listas devem casar com cada combinação, não fazer produto cartesiano.

`super+Escape` envia USR1 a sxhkd; é uma operação de recarga. Um sxhkd iniciado
com `-c ~/.config/rice/popup-keys.sxhkd` captura Escape de popup e pode coexistir
com o daemon principal. Identifique argv antes de matar/recarregar todos.
`cheatsheet.sh` pode abrir GUI; ler o arquivo não é executar o helper.

### Picom, blur, tearing, animação

Leia appearance-performance.md. Consulte `picom --version` e argv do processo;
confira picom-launch.sh, pick_config e o log. Um formato `vgit-*` não informa
major. Ausência de presets nativos no fallback é diferente de fading e das
transições GTK/Eww ou cursor do Kitty. Mantenha ferramentas AppSec opacas.

Em diagnóstico apenas leitura, não execute um segundo picom como “teste”. Se
for testar sintaxe/compatibilidade com execução, faça-o em display isolado ou
numa janela operacional autorizada, protegendo e recuperando o compositor atual.
Nunca remova automaticamente o fallback para “forçar” efeitos.

### Eww, tint2, painel que não abre/fecha

Fonte de perfil: ~/.config/rice/profile. Nyx=tint2; Vesper=barraEww; centro de
controleEww existe em ambos. Veja bar.sh, control.sh, panel.sh, eww.yuck/scss,
colors.scss gerado, popup keys, logs tint2/Eww e locks em XDG_RUNTIME_DIR.
`eww ... active-windows` é consulta; `open`, `close`, `update`, `kill` mudam UI.
Preserve backdrop/clique externo/Escape e click-through/restacking do tint2.

Antes de culpar CSS, confira dados JSON de deflisten, script de mídia e escaping
Yuck/JSON. Não substitua media-state.py por um inexistente panel-media.py.
Os polls ocultos precisam continuar desativados.

### Kitty/fish, Zsh e Neovim

Kitty fixa `/usr/bin/fish`; o repo também instala Zsh. Não “corrija” terminal
editando apenas .zshrc nem migre de shell sem pedido. Leia mapas do Kitty antes
de diagnosticar atalhos Ctrl+Shift; mapas do editor são Lua separados.

Neovim tem Lazy, config/rice.lua, RiceEngagement/RiceNote/RiceSemgrep e quickfix.
Não inicialize Neovim headless despreocupadamente se o teste puder disparar
bootstrap/download de plugins. Use luac quando disponível e fixtures/testes
isolados. Não rode scans/HTTP requests ou abra targets reais para testar atalhos.

### Instalar, restaurar e preservar trabalho

- Veja primeiro as mudanças locais, dependências e espaço. Não use sudo no
  instalador principal. Preserve o root real, os arquivos reais e o inventário schema2.
  Reconcile alterações diretas antes de atualizar; --overwrite-local é explícito
  e guarda backup, não deve ser usado automaticamente para passar um conflito.
- Simule com `./install.sh --adopt-monitor-layout --dry-run`; isso abre
  `.install.lock` no checkout. Não instala em HOME, mas não é zero escrita.
- `./install.sh --adopt-monitor-layout` é mutação: pede backup e aplicação já
  autorizados. Arquivos de shell/editor são substituídos também.
- `./sync.sh` chama update, exige Git limpo e --ff-only. Sem reset --hard, sem
  auto-commit, sem apagar overrides pessoais para satisfazer o update.
- Restore impresso pela transação usa manifest e recusa mudanças posteriores.
  Preserve essas mudanças, compare conteúdo/links e reconcilie; não remova a
  validação de fingerprints para fazer o restore “passar”.
- Não confunda backup de arquivos em HOME com histórico dos arquivos no
  checkout: se um symlink antigo apontava para fonte editada no mesmo repo,
  recuperar o link não desfaz as edições da fonte. Preserve diffs/cópias antes.
- Helpers que source lib.sh podem criar STATE_DIR mesmo com --get/--status.
  O coletor evita esses helpers. Não afirme que todo getter é estritamente read-only.

### Checks apropriados

No checkout: `python3 -B scripts/check.py` e
`python3 -B -m unittest discover -s tests -v`. O checker valida sintaxes, binds,
paths, executáveis, templates e padrões de segredos; pode usar shellcheck/luac
se presentes. A suite usa HOMEs temporários, mocks de sessão e cópias reais completas sem Stow.
Registre skips. Checks escrevem temporários/caches; não os apresente como
operações sem qualquer escrita. Reexecute depois de mudanças que afetem o alvo.



## Central de controle bloqueada — 2026-11-05

Falha confirmada ao abrir Super+Shift+N: `panel.sh` desistia silenciosamente
após dois segundos no flock. `lslocks` e `/proc/31162/fd/9` identificaram um
`calendar_state.py --watch` órfão (PPID 1, iniciado às 17:04) segurando
`/run/user/1000/rice-popup.lock`; o daemon Eww atual era posterior (17:07).
O wrapper `ew()` agora fecha o descritor 9 em todas as chamadas, pois até uma
consulta Eww pode iniciar daemon/listeners. Timeout do lock retorna erro 1 e
mensagem em stderr, em vez de sucesso silencioso. Runtime e fonte sincronizados;
backup em `~/.local/state/rice/changes/panel-lock-20261105T202200Z/`.
Somente o watcher órfão identificado foi encerrado. Abertura real confirmou
`control: control`, `cc_reveal=true` e lock livre. Não houve reinício de sessão.
Um teste com filho persistente reproduziu a retenção antes da correção.

Para diagnosticar recorrência no terminal da sessão:

```sh
~/.config/rice/bin/control.sh --open
eww -c ~/.config/eww active-windows
lslocks -o PID,COMMAND,TYPE,MODE,PATH
```

Se a abertura direta funcionar, comparar Super+C e Super+Shift+N e investigar
sxhkd. Se houver `popup lock busy`, identificar o detentor antes de recuperar;
não apagar o arquivo de lock (isso permite bloqueios concorrentes em inodes
diferentes), não usar pkill genérico e não reinstalar o rice. Essa falha prova
um problema de ciclo de vida de processos; não prova a causa de outros bugs.


## Áudio Bluetooth e aplicativos sem acesso à sessão — 2026-11-06

O H3 estava conectado, como saída padrão e sem mudo, mas o teste de áudio
não foi ouvido com A2DP/AAC. Após trocar para `a2dp-sink-sbc`, o usuário
confirmou ouvir o teste. Isso demonstra recuperação nesta conexão, sem provar
uma incompatibilidade permanente do codec AAC.

Firefox e BSPWM estavam sem `XDG_RUNTIME_DIR` e
`DBUS_SESSION_BUS_ADDRESS`. Uma consulta pactl usando o ambiente mínimo do
Firefox reproduziu `Connection refused`, enquanto a mesma consulta com o
runtime e o bus existentes funcionou. Spotify Flatpak registrava bus
`disabled:` nas tentativas anteriores; iniciado com o ambiente correto,
criou uma janela e um cliente/fluxo de áudio. O Firefox foi fechado normalmente,
reaberto com o ambiente corrigido e restauração única da sessão; passou a
aparecer como cliente no PipeWire. Confirmação auditiva do YouTube fica a cargo
do usuário, pois presença do cliente não comprova reprodução audível.

`launcher.sh` agora carrega `~/.config/rice/env` antes de abrir Rofi. Isso
permite às aplicações abertas pelo menu herdar runtime e bus, mesmo que o
BSPWM atual ainda tenha o ambiente anterior. A mudança foi sincronizada em
runtime e fonte. `~/.xprofile` já carrega esse arquivo para novas sessões;
não houve reinício do WM ou da sessão. O atalho direto de `rofi -show run`
não passa por `launcher.sh`, portanto esta correção não altera esse caminho.

Backup privado dos lançadores e dos arquivos da sessão do Firefox:
`~/.local/state/rice/changes/audio-apps-20261106T191020Z/`.
Para reverter somente o lançador, copiar `launcher-runtime` desse backup para
`~/.config/rice/bin/launcher.sh` e `launcher-source` para
`~/rice/stow/desktop/.config/rice/bin/launcher.sh`. Não restaurar a sessão do
Firefox sobre trabalho posterior. Nenhuma configuração de compositor ou
monitor foi alterada.
