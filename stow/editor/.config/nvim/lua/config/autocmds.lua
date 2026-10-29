local augroup = vim.api.nvim_create_augroup("offsec", { clear = true })

-- destaque ao copiar
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

-- volta para a última posição no arquivo
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  callback = function(event)
    local exclude = { "gitcommit", "gitrebase" }
    if vim.tbl_contains(exclude, vim.bo[event.buf].filetype) then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(event.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(event.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- remove espaços em branco no fim das linhas ao salvar
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  pattern = "*",
  callback = function()
    local view = vim.fn.winsaveview()
    pcall(function()
      vim.cmd([[silent! %s/\s\+$//e]])
    end)
    vim.fn.winrestview(view)
  end,
})

-- fecha janelas utilitárias com q
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "help", "qf", "man", "lspinfo", "checkhealth", "startuptime", "notify" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true })
  end,
})

-- cria diretórios que ainda não existem ao salvar
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  callback = function(event)
    if event.match:match("^%w%w+://") then
      return
    end
    local file = vim.uv and vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file or event.match, ":p:h"), "p")
  end,
})

-- tipos de arquivo comuns em teste de aplicação
vim.filetype.add({
  extension = {
    http = "http",
    nmap = "text",
    gnmap = "text",
  },
  pattern = {
    [".*%.har"] = "json",
    [".*/burp/.*%.txt"] = "http",
  },
})

-- terminal sem número de linha
vim.api.nvim_create_autocmd("TermOpen", {
  group = augroup,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
  end,
})

-- sudoedit edita uma CÓPIA temporária com sufixo aleatório de 8 caracteres:
--   /etc/fstab            -> /var/tmp/fstab.a1B2c3D4
--   /etc/nginx/nginx.conf -> /var/tmp/nginx.a1B2c3D4.conf
-- Nos arquivos sem extensão (fstab, hosts, PKGBUILD, sudoers, crontab) o nvim
-- detecta o tipo PELO NOME, e o sufixo quebra a detecção — abre sem realce
-- nenhum. Reconstituímos o nome original só para decidir o filetype; o buffer
-- continua apontando para o temporário, que é o que o sudoedit copia de volta.
local function sudoedit_original(basename)
  -- nginx.a1B2c3D4.conf -> nginx.conf
  local stem, extension = basename:match("^(.+)%.%w%w%w%w%w%w%w%w(%.[^.]+)$")
  if stem then
    return stem .. extension
  end
  -- fstab.a1B2c3D4 -> fstab
  return basename:match("^(.+)%.%w%w%w%w%w%w%w%w$")
end

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup,
  pattern = { "/var/tmp/*", "/tmp/*" },
  callback = function(event)
    local original = sudoedit_original(vim.fn.fnamemodify(event.match, ":t"))
    if not original then
      return
    end
    -- Alguns nomes (hosts, sudoers, crontab) o nvim só reconhece pelo caminho
    -- inteiro, não pelo nome solto. Como o sudoedit não revela a origem e a
    -- esmagadora maioria dos alvos mora em /etc, tentamos lá como segunda via.
    local detected = vim.filetype.match({ filename = original, buf = event.buf })
      or vim.filetype.match({ filename = "/etc/" .. original, buf = event.buf })
    if detected then
      vim.bo[event.buf].filetype = detected
    end
  end,
})
