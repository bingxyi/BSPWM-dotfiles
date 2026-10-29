local opt = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.termguicolors = true
opt.showmode = false
opt.laststatus = 3
opt.cmdheight = 1
opt.pumheight = 12
opt.pumblend = 8
opt.winblend = 0
opt.splitbelow = true
opt.splitright = true
opt.splitkeep = "screen"
-- Cada campo de fillchars aceita EXATAMENTE um caractere. Vazio levanta
-- E1511 no neovim 0.12, e o erro aborta este arquivo inteiro — o que
-- derrubava junto o require("config.lazy") do init.lua e deixava a
-- instalacao de plugins sem nunca acontecer.
opt.fillchars = {
  eob = " ",
  fold = " ",
  foldsep = " ",
  foldopen = "󰅀",
  foldclose = "󰅂",
}

opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.smartindent = true
opt.breakindent = true

opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"
opt.hlsearch = true

opt.undofile = true
opt.undolevels = 10000
opt.swapfile = false
opt.backup = false
opt.updatetime = 200
opt.timeoutlen = 400
opt.confirm = true

opt.clipboard = "unnamedplus"
opt.mouse = "a"
opt.completeopt = { "menu", "menuone", "noselect" }
opt.shortmess:append({ W = true, I = true, c = true, C = true })

opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldlevelstart = 99

opt.list = true
opt.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }

-- Segurança básica ao abrir amostras de engagement: nada de modeline arbitrária
opt.modeline = false
opt.secure = true

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
