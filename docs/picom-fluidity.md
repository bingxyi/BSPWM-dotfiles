# Fluidez do Picom e workspace — 2026-11-05

## Estado confirmado

Runtime e fonte são cópias reais independentes, sincronizadas apenas nos três
arquivos desta intervenção: `rice/bin/motion.py`, `rice/bin/animation_settings.py`
e `picom/picom-ftlabs.conf` dentro de `.config`. Preferências pessoais em
`~/.config/rice/animations.json` não foram versionadas. Trabalho anterior no Git,
inclusive staging, foi preservado; nenhum commit, pull ou instalação.

Picom ativo: FT-Labs `vgit-df4c6`, Mesa Intel Iris Xe acelerada. Fonte pública
obtida em `/tmp/rice-picom-research`, HEAD completo
`df4c6a3d9b11e14ed7f3142540babea4c775ddb1`, correspondente ao sufixo do binário
(não é uma prova de reprodutibilidade do pacote). HDMI principal1080p60Hz à
esquerda de eDP1080p120,21Hz. Nenhuma mudança de layout ou refresh.
Marcador compositor-safe-mode ausente antes da intervenção; animações já ativas.

## Causas e escolhas

A integração de molas está em `src/picom.c:918-1096` do FT-Labs. Este engine
usa stiffness, massa e amortecimento, não `open_ms`/`close_ms`/`geometry_ms` da
interface moderna. O preset local continua maximize/slide-down/slide-up.
O conjunto250/220, massa0,6 e damping24 deixava uma cauda longa até a tolerância
1e-9. A simulação da integração real, com distância normalizada e frames
uniformes, leva cerca de1,4–1,6s para convergir a60/120Hz. Isso é um modelo,
não uma medição de FPS ou de duração percebida de uma janela real.

Novo conjunto: stiffness400 para ambas as molas, massa0,5, damping20 e clamp no
destino. A mesma simulação atinge o destino em cerca de125–167ms a120/60Hz,
sem desenhar overshoot. Os testes cobrem60/120/144Hz; o integrador do fork não
oferece garantia universal sob travamentos longos ou taxas muito baixas.

Workspace continua slide-fade e agora dura140ms (antes180ms). O serviço GTK
captura a imagem apenas na troca, converte-a em superfície Cairo uma vez por
transição e a reutiliza. Em vez de aguardar50ms, executa a ação após o primeiro
`after-paint` do overlay. Este sinal confirma submissão GTK, não apresentação
física pelo monitor. Expiração, overlay sem entrada, cancelamento e fallback
continuam ativos. Não há polling ocioso adicional. O FrameGate usa deadlines
com tolerância0,5ms, evitando a queda sistemática para aproximadamente40FPS
quando um teto60 encontra ticks120,21Hz. A preferência local continua sem teto;
a correção também cobre usuários que ativam o limite na interface.

VSync, frame pacing nativo, use-damage, blur dual_kawase3, sombras18, raios12,
transparências e exclusões AppSec foram preservados. Não foi ativado preload
nem instalado outro fork. Não se desativou frame pacing por recomendação
universal: o manual admite stutter em alguns casos, mas não houve evidência
suficiente para atribuir o problema desta sessão a esse mecanismo. Telas com
refresh diferente compartilham a composição X11; FPS ilimitado não garante
cadência independente perfeita nos dois monitores.

FT-Labs declara suporte de tags para phyOS-dwm; em BSPWM a transição usada é o
serviço motion. Seus controles de workspace não devem ser confundidos com os
parâmetros de tags do compositor.

## Validação

`python3 -B scripts/check.py`:57scripts shell,119binds e10templates; shellcheck
indisponível. `python3 -B -m unittest discover -s tests -v`:92testes passaram.
Inclui regressão do FrameGate em59,97/60/120/120,21/144Hz e convergência da mola.

O mesmo probe real realizou seis trocas entre dois desktops da mesma tela e
abriu/fechou quatro janelas GTK temporárias, restaurando o desktop original.
Comparação de IDs de clientes, desktops e monitores passou antes e depois.

| Medida do probe | Antes | Depois |
|---|---:|---:|
| Mediana até foco do desktop, incluindo processo Python e consultas BSPWM |149,92ms|111,80ms|
| CPU acumulada do Picom |0,90s|0,52s|
| Duração total do cenário |7,43s|7,25s|

Redução observada de25% na latência mediana e42% no tempo de CPU neste cenário
curto, sem repetição estatística. Não é uma medição de FPS, GPU, energia ou
frame times. O usuário deve avaliar a percepção visual no uso habitual.
Picom passou preflight diagnostics, iniciou com a configuração gerada esperada
e possuiu a seleção de composição X11; motion iniciou e atendeu o probe.
Logs novos não mostraram exceções; avisos de depreciação GTK são preexistentes.

Evidência local (não publicar capturas ou dados de sessão):
`~/.local/state/rice/changes/animation-fluidity-20261105T181711Z/`
contém before.json, after.json, arquivos anteriores e diff prévio. Backup de
preferências adicional: `~/.local/state/rice/animation-backups/20261105T151843-353273/`.

## Reversão

Feche a interface de animações e execute:

```sh
python3 ~/.local/state/rice/changes/animation-fluidity-20261105T181711Z/restore.py
```

O script verifica fingerprints posteriores antes de restaurar os arquivos
originais de runtime/fonte e preferências. Recusa mudanças posteriores em vez
de sobrescrevê-las. Recarrega apenas Picom/motion; não reinicia BSPWM.
O documento novo permanece como registro histórico; seu snapshot descreve
aplicação, não garante que o patch continue ativo depois de uma reversão.

## Pesquisa primária

- [Manual oficial do Picom](https://picom.app/): VSync, frame pacing, damage,
  fading e diferenças das animações modernas.
- [Fonte do integrador FT-Labs](https://github.com/FT-Labs/picom/blob/df4c6a3d9b11e14ed7f3142540babea4c775ddb1/src/picom.c).
- [Configuração e ressalva de WM do FT-Labs](https://github.com/FT-Labs/picom/blob/df4c6a3d9b11e14ed7f3142540babea4c775ddb1/picom.sample.conf).
- [Limites de transições de workspace discutidos pelo mantenedor](https://github.com/yshui/picom/discussions/1372).
- [Investigação upstream de frame pacing/stutter](https://github.com/yshui/picom/issues/1072).
