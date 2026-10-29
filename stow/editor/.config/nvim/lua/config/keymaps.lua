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
