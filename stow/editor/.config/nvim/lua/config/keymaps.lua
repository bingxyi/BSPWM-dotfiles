local map = vim.keymap.set

-- básico
map("i", "jk", "<Esc>", { desc = "sair do modo insert" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "limpar busca" })
map("n", "<C-s>", "<cmd>write<CR>", { desc = "salvar" })
map("i", "<C-s>", "<Esc><cmd>write<CR>", { desc = "salvar" })
map("n", "<leader>qq", "<cmd>qa<CR>", { desc = "sair de tudo" })

-- movimento entre janelas (mesma lógica do bspwm)
map("n", "<C-h>", "<C-w>h", { desc = "janela à esquerda" })
map("n", "<C-j>", "<C-w>j", { desc = "janela abaixo" })
map("n", "<C-k>", "<C-w>k", { desc = "janela acima" })
map("n", "<C-l>", "<C-w>l", { desc = "janela à direita" })
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "aumentar altura" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "diminuir altura" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "diminuir largura" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "aumentar largura" })

-- splits
map("n", "<leader>-", "<cmd>split<CR>", { desc = "split horizontal" })
map("n", "<leader>|", "<cmd>vsplit<CR>", { desc = "split vertical" })

-- buffers
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "buffer anterior" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "próximo buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "fechar buffer" })
map("n", "<leader>bo", "<cmd>%bd|e#|bd#<CR>", { desc = "fechar os outros buffers" })

-- mover linhas: Alt+setas (igual ao VS Code) e Alt+j/k para quem prefere hjkl.
-- Move a linha inteira sem alterar o conteúdo; o '==' reindenta no destino.
map("n", "<A-Down>", "<cmd>m .+1<CR>==", { desc = "mover linha abaixo" })
map("n", "<A-Up>", "<cmd>m .-2<CR>==", { desc = "mover linha acima" })
map("i", "<A-Down>", "<Esc><cmd>m .+1<CR>==gi", { desc = "mover linha abaixo" })
map("i", "<A-Up>", "<Esc><cmd>m .-2<CR>==gi", { desc = "mover linha acima" })
map("v", "<A-Down>", ":m '>+1<CR>gv=gv", { desc = "mover seleção abaixo" })
map("v", "<A-Up>", ":m '<-2<CR>gv=gv", { desc = "mover seleção acima" })

map("n", "<A-j>", "<cmd>m .+1<CR>==", { desc = "mover linha abaixo" })
map("n", "<A-k>", "<cmd>m .-2<CR>==", { desc = "mover linha acima" })
map("i", "<A-j>", "<Esc><cmd>m .+1<CR>==gi", { desc = "mover linha abaixo" })
map("i", "<A-k>", "<Esc><cmd>m .-2<CR>==gi", { desc = "mover linha acima" })
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "mover seleção abaixo" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "mover seleção acima" })
map("v", "<", "<gv", { desc = "desindentar mantendo seleção" })
map("v", ">", ">gv", { desc = "indentar mantendo seleção" })

-- centralizar ao navegar
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- colar sem perder o registro
map("v", "p", '"_dP', { desc = "colar sem sobrescrever o registro" })
map({ "n", "v" }, "<leader>d", '"_d', { desc = "deletar sem copiar" })

-- diagnósticos
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "diagnóstico anterior" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "próximo diagnóstico" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "detalhe do diagnóstico" })

-- appsec: utilidades de payload direto no editor
map("v", "<leader>xb", ":!base64 -w0<CR>", { desc = "base64 encode da seleção" })
map("v", "<leader>xB", ":!base64 -d<CR>", { desc = "base64 decode da seleção" })
map("v", "<leader>xu", ":!jq -sRr @uri<CR>", { desc = "url encode da seleção" })
map("v", "<leader>xj", ":!jq .<CR>", { desc = "formatar JSON da seleção" })
map("n", "<leader>xJ", "<cmd>%!jq .<CR>", { desc = "formatar o arquivo JSON inteiro" })
map("v", "<leader>xh", ":!xxd<CR>", { desc = "hexdump da seleção" })
map("v", "<leader>xs", ":!sort -u<CR>", { desc = "ordenar e deduplicar" })
