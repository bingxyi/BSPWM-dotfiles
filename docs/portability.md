# Portabilidade do notebook para o desktop

Auditoria de 2026-11-08 (UTC). Este documento descreve a distribuição do rice;
a instalação no desktop de destino ainda deve ser feita nesse equipamento.

## Ambiente verificado

| Camada | Evidência atual |
| --- | --- |
| Sistema/GPU | Arch Linux, kernel 7.2.14.arch1-1, Mesa 26.2.6; notebook Intel Iris Xe documentado |
| Sessão | X11, BSPWM 0.9.12, sxhkd 0.6.3; teclado br/abnt2 |
| Monitores | Somente eDP-1 ativo, 1920×1080 a 120,21 Hz; HDMI-1 desconectado |
| Desktops | 1–10 na tela interna, padding esquerdo de 46 px |
| Visual | Ember Crimson, Nyx/tint2 17.0.2; Eww disponível, sem popup aberto |
| Compositor | FT-Labs `vgit-df4c6`, processo com configuração gerada; marcador de recuperação ausente |
| Terminal/editor | Kitty 0.49.2, fish 4.9.3, Zsh 5.9.2, Neovim 0.12.6 |
| Áudio/rede | PipeWire, pipewire-pulse, WirePlumber, Bluetooth e NetworkManager ativos; saída padrão sem mudo |
| Configurações | 234 fontes estáticas comparadas byte a byte com os arquivos instalados: nenhuma divergência ou ausência |

A versão executada do Eww é 0.5.0 (commit d87c2fd), embora o banco pacman
registre 0.6.0-1.3. Para reproduzir comportamentos, confira tanto o executável
quanto o pacote. `xinput` funciona por um executável local, sem pacote
`xorg-xinput` registrado: instale o pacote no destino, não copie esse binário.
Inter não está instalado no notebook; `fc-match Inter` resolve para Noto Sans.
As fontes Nerd e Papirus estão instaladas.

## O que vai para o GitHub

São distribuídos scripts, templates, paletas, Eww, Rofi, tint2, Kitty, Picom,
binds, sessão X11, Zsh e Neovim. A atualização inclui as correções locais de
animações, fallback de recuperação, lock do painel e ambiente do lançador.
O instalador verifica fish, pois Kitty usa `/usr/bin/fish`. Um config inicial
em `defaults/.config/fish/config.fish` fornece Starship e os aliases de terminal
quando as ferramentas estão disponíveis, preservando um config já existente.

O fish local também contém integração antiga com Quickshell/Hyprland. Ela não
é necessária ao BSPWM e não foi distribuída. Variáveis universais/histórico do
fish, arquivos congelados gerados pelo próprio fish, helpers antigos de Kitty
sem referência na configuração e plugins Neovim legados fora da distribuição
não foram incorporados. Os templates continuam sendo a fonte das cores geradas.

Preferências de monitores, mouse, binds pessoais, eventos, animações, avatar,
VPN, credenciais, engagements, caches e backups ficam locais. Para copiar
escolhas pessoais, compare e transfira apenas os arquivos desejados por canal
privado. Não copie o diretório `~/.config` inteiro sobre o desktop.

## Instalação no desktop

1. Confira os pacotes da tabela de [dependências](../README.md#dependencies).
   Instale fish e as ferramentas de sessão, áudio, rede e Bluetooth usadas.
   Eww com X11 é necessário para a central de controle também no perfil Nyx.
   O instalador não instala pacotes, habilita serviços ou altera drivers.
2. Clone o repositório, ou confira o diff do checkout já existente antes de
   atualizá-lo. Em checkout limpo, use `git pull --ff-only`.
3. Execute os checks e veja o plano antes de instalar:

   ```sh
   git clone https://github.com/bingxyi/BSPWM-dotfiles.git ~/rice
   cd ~/rice
   python3 -B scripts/check.py
   python3 -B -m unittest discover -s tests -v
   ./install.sh --dry-run
   ./install.sh
   ```

   O dry-run não instala no HOME, mas abre `.install.lock` no checkout e não
   substitui a verificação de dependências feita na instalação real.
   A instalação usa arquivos reais, backup e inventário de hashes; imprime o
   comando de restauração da transação. Se houver edições locais protegidas,
   reconcilie-as antes de atualizar, sem adicionar `--overwrite-local` por rotina.
4. Entre em BSPWM pelo display manager ou `startx`. Confira `xrandr --query`,
   `bspc query -D --names`, `setxkbmap -query`, Kitty/fish, Super+D, Super+C,
   Super+A, áudio e bloqueio. Esses testes físicos no destino permanecem a cargo
   de quem realiza a migração.

Não transporte o override HDMI/eDP do notebook. O controlador detecta as saídas
do desktop e mantém os dez desktops. Se quiser uma ordem física específica,
edite uma cópia de `examples/monitors.local.sh` com os nomes reais do destino.
`--adopt-monitor-layout` captura primária/ordem lógica de uma sessão existente;
não deduz a posição física dos monitores.

Picom escolhe FT-Labs por capacidade, moderno por versão, ou configuração básica
como fallback. Mesmos efeitos exigem um engine compatível; o resultado visual em
outra GPU/driver precisa ser verificado no destino. Não é necessário substituir
um compositor funcional apenas para igualar o nome do pacote do notebook.
As preferências pessoais de animação não são copiadas: o padrão distribuído
ativa animações, VSync e teto de 60 FPS; isso não altera o refresh dos monitores.
Um marcador de recuperação existente deve ser preservado.

## Validação e limites

O checker valida sintaxes shell/Python/Lua/fish, 119 binds e dez templates.
Shellcheck não está instalado e esse passo é explicitamente ignorado.
A suíte passou com 95 testes e usa HOME temporário; cobre instalação completa por cópias reais,
rollback, proteção de edições, fish existente, migração de links, monitores
simulados, animações e lock do painel. Não aplica layouts na sessão real.

A auditoria consultou a sessão real fora da sandbox para evitar falsos erros de
X11/socket. Serviços ativos e volume não comprovam reprodução audível. Não houve
teste físico de hotplug, suspensão, bloqueio ou renderização no desktop de destino.
Nenhum pacote foi instalado, processo reiniciado ou layout aplicado no notebook.
Snapshot bruto e diff anterior ficam privados em
`~/.local/state/rice/audits/portability-20261108/`.
