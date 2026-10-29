-- BSPWM-dotfiles :: neovim
-- IDE conveniences (Tab completion, diagnostics, refactoring, debugging)
-- with fast startup. lazy.nvim loads everything on demand.

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("config.theme").setup()
require("config.offsec").setup()
