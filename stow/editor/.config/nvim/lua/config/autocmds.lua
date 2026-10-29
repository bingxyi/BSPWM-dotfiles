local augroup = vim.api.nvim_create_augroup("offsec", { clear = true })

-- Highlight copied text.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

-- Restore the last cursor position in the file.
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

-- Remove trailing whitespace when saving.
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

-- Close utility windows with q.
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "help", "qf", "man", "lspinfo", "checkhealth", "startuptime", "notify" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true })
  end,
})

-- Create missing parent directories when saving.
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

-- File types commonly used in application security testing.
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

-- Hide line numbers in terminals.
vim.api.nvim_create_autocmd("TermOpen", {
  group = augroup,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
  end,
})

-- sudoedit edits a temporary copy with a random eight-character suffix:
--   /etc/fstab            -> /var/tmp/fstab.a1B2c3D4
--   /etc/nginx/nginx.conf -> /var/tmp/nginx.a1B2c3D4.conf
-- For extensionless files (fstab, hosts, PKGBUILD, sudoers, crontab), Neovim
-- detects file type by name. The suffix breaks detection and highlighting.
-- Reconstruct the original name only to select the file type; keep the buffer
-- pointing at the temporary file that sudoedit will copy back.
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
    -- Neovim recognizes some files (hosts, sudoers, crontab) only by full path.
    -- sudoedit does not expose the original path; most targets live in /etc,
    -- so try that directory as a fallback.
    local detected = vim.filetype.match({ filename = original, buf = event.buf })
      or vim.filetype.match({ filename = "/etc/" .. original, buf = event.buf })
    if detected then
      vim.bo[event.buf].filetype = detected
    end
  end,
})
