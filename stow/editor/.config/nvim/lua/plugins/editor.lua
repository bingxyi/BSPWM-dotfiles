return {
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
      "nvim-telescope/telescope-ui-select.nvim",
    },
    keys = {
      { "<C-p>", "<cmd>Telescope find_files<CR>", desc = "buscar arquivos" },
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "buscar arquivos" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "grep no projeto" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "buffers" },
      { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "recentes" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "ajuda" },
      { "<leader>fk", "<cmd>Telescope keymaps<CR>", desc = "atalhos" },
      { "<leader>fd", "<cmd>Telescope diagnostics<CR>", desc = "diagnósticos" },
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", desc = "símbolos do arquivo" },
      { "<leader>fS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "símbolos do projeto" },
      { "<leader>fw", "<cmd>Telescope grep_string<CR>", desc = "grep da palavra sob o cursor" },
      { "<leader>fc", "<cmd>Telescope git_commits<CR>", desc = "commits" },
    },
    opts = function()
      local actions = require("telescope.actions")
      return {
        defaults = {
          prompt_prefix = "   ",
          selection_caret = "  ",
          path_display = { "truncate" },
          sorting_strategy = "ascending",
          layout_config = {
            horizontal = { prompt_position = "top", preview_width = 0.55 },
            width = 0.87,
            height = 0.8,
          },
          file_ignore_patterns = { "node_modules", "%.git/", "%.venv", "target/", "dist/" },
          mappings = {
            i = {
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
              ["<Esc>"] = actions.close,
            },
          },
        },
        pickers = {
          find_files = { hidden = true },
          live_grep = { additional_args = { "--hidden" } },
        },
        extensions = {
          ["ui-select"] = { require("telescope.themes").get_dropdown({}) },
        },
      }
    end,
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")
    end,
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle reveal<CR>", desc = "explorer" },
      { "<C-b>", "<cmd>Neotree toggle reveal<CR>", desc = "explorer" },
    },
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = true,
      window = {
        width = 34,
        mappings = {
          ["<space>"] = "none",
          ["l"] = "open",
          ["h"] = "close_node",
          ["Y"] = function(state)
            local node = state.tree:get_node()
            vim.fn.setreg("+", node.path, "c")
            vim.notify("copiado: " .. node.path)
          end,
        },
      },
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          never_show = { ".DS_Store", "__pycache__" },
        },
      },
      default_component_configs = {
        indent = { with_expanders = true },
        git_status = {
          symbols = {
            added = "",
            modified = "",
            deleted = "",
            renamed = "󰁕",
            untracked = "",
            ignored = "",
            unstaged = "󰄱",
            staged = "",
            conflict = "",
          },
        },
      },
    },
  },

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      current_line_blame = false,
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = buffer, desc = desc })
        end
        map("n", "]h", gs.next_hunk, "próximo hunk")
        map("n", "[h", gs.prev_hunk, "hunk anterior")
        map("n", "<leader>gs", gs.stage_hunk, "stage hunk")
        map("n", "<leader>gr", gs.reset_hunk, "reset hunk")
        map("n", "<leader>gp", gs.preview_hunk, "preview hunk")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "blame da linha")
        map("n", "<leader>gd", gs.diffthis, "diff")
      end,
    },
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = { focus = true },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", desc = "diagnósticos (projeto)" },
      { "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "diagnósticos (arquivo)" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<CR>", desc = "quickfix" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<CR>", desc = "location list" },
      { "<leader>xt", "<cmd>Trouble todo toggle<CR>", desc = "todos" },
    },
  },

  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      keywords = {
        VULN = { icon = " ", color = "error", alt = { "EXPLOIT", "PAYLOAD" } },
        FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "ISSUE" } },
        TODO = { icon = " ", color = "info" },
        HACK = { icon = " ", color = "warning" },
        NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
      },
    },
    keys = {
      { "<leader>st", "<cmd>TodoTelescope<CR>", desc = "todos/vulns no projeto" },
    },
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "flash treesitter" },
    },
  },

  {
    "numToStr/Comment.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = { check_ts = true, fast_wrap = {} },
  },

  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    opts = {},
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "▏" },
      scope = { enabled = true, show_start = false, show_end = false },
      exclude = { filetypes = { "help", "alpha", "neo-tree", "Trouble", "lazy", "mason", "notify" } },
    },
  },

  {
    "akinsho/toggleterm.nvim",
    keys = {
      { "<C-\\>", "<cmd>ToggleTerm<CR>", desc = "terminal" },
      { "<leader>tf", "<cmd>ToggleTerm direction=float<CR>", desc = "terminal flutuante" },
      { "<leader>tg", "<cmd>lua _lazygit_toggle()<CR>", desc = "lazygit" },
    },
    opts = {
      size = 16,
      open_mapping = [[<C-\>]],
      shade_terminals = true,
      direction = "horizontal",
      float_opts = { border = "rounded" },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)
      local Terminal = require("toggleterm.terminal").Terminal
      local lazygit = Terminal:new({ cmd = "lazygit", hidden = true, direction = "float" })
      function _lazygit_toggle()
        lazygit:toggle()
      end
      vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "sair do modo terminal" })
    end,
  },

  {
    "stevearc/oil.nvim",
    cmd = "Oil",
    keys = { { "-", "<cmd>Oil<CR>", desc = "editar o diretório como buffer" } },
    opts = {
      default_file_explorer = false,
      view_options = { show_hidden = true },
    },
  },
}
