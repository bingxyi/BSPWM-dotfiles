-- Neovim 0.12: native highlighting/selection with the main parser manager.
local M = {}

function M.setup()
  local ts = require('nvim-treesitter')
  ts.setup({ install_dir = vim.fn.stdpath('data') .. '/site' })
  local available = require('nvim-treesitter.parsers')
  vim.treesitter.language.register('json', 'jsonc')
  local pending = {}
  local group = vim.api.nvim_create_augroup('offsec_treesitter', { clear = true })

  local function attach(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then return end
    local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
    if not lang then return end
    local ok = pcall(vim.treesitter.language.add, lang)
    if ok then
      vim.treesitter.start(buf, lang)
      if available[lang] then
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
      vim.keymap.set({ 'n', 'x' }, '<C-Space>', function()
        vim.treesitter.select('parent')
      end, { buffer = buf, desc = 'Expandir seleção sintática' })
      vim.keymap.set('x', '<BS>', function()
        vim.treesitter.select('child')
      end, { buffer = buf, desc = 'Reduzir seleção sintática' })
    elseif available[lang] and not pending[lang] then
      pending[lang] = true
      ts.install({ lang }, { max_jobs = 2 }):await(function()
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) then attach(buf) end
        end)
      end)
    end
  end

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    callback = function(event) attach(event.buf) end,
  })
end

return M
