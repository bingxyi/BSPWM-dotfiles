-- offsec-dotfiles :: neovim
-- Objetivo: comodidade de IDE (completar com Tab, diagnósticos, refactor, debug)
-- sem abrir mão da velocidade. Tudo carregado sob demanda pelo lazy.nvim.

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("config.theme").setup()
require("config.offsec").setup()
