/* gerado por theme.sh — não editar à mão */
* {
    bg:          {{bg}};
    bg-alt:      {{bg_alt}};
    bg-dim:      {{bg_dim}};
    surface:     {{surface}};
    overlay:     {{overlay}};
    muted:       {{muted}};
    fg:          {{fg}};
    fg-dim:      {{fg_dim}};
    accent:      {{accent}};
    accent-alt:  {{accent_alt}};
    urgent-col:  {{urgent}};
    green-col:   {{green}};
    yellow-col:  {{yellow}};
    blue-col:    {{blue}};

    /* rofi nao aceita variavel em parte de propriedade composta
       (rofi-theme(5): "cannot be used for a subpart of the property"),
       entao 'highlight' precisa do valor inteiro em uma variavel. */
    hl-accent:     bold {{accent}};
    hl-accent-alt: bold {{accent_alt}};
    hl-bg:         bold {{bg}};
}
