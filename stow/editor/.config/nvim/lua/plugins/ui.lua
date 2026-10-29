return {
  -- temas: os quatro do theme.sh ficam disponíveis para troca instantânea
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = false,
      integrations = {
        cmp = true,
        gitsigns = true,
        neotree = true,
        telescope = { enabled = true },
        treesitter = true,
        which_key = true,
        mason = true,
        native_lsp = { enabled = true, underlines = { errors = { "undercurl" } } },
      },
    },
  },
  { "folke/tokyonight.nvim", lazy = false, priority = 900, opts = { style = "night" } },
  { "sainnhe/gruvbox-material", lazy = false, priority = 900 },
  { "rose-pine/neovim", name = "rose-pine", lazy = false, priority = 900 },
  { "nyoom-engineering/oxocarbon.nvim", lazy = false, priority = 900 },

  { "nvim-tree/nvim-web-devicons", lazy = true },
  { "MunifTanjim/nui.nvim", lazy = true },
  { "nvim-lua/plenary.nvim", lazy = true },

  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      local function offsec_target()
        local path = vim.env.HOME .. "/.local/share/offsec/target"
        local fd = io.open(path, "r")
        if not fd then
          return ""
        end
        local target = fd:read("*l")
        fd:close()
        if not target or target == "" then
          return ""
        end
        return "  " .. target
      end

      return {
        options = {
          theme = "auto",
          globalstatus = true,
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = { statusline = { "alpha", "neo-tree" } },
        },
        sections = {
          lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
          lualine_b = { "branch", "diff" },
          lualine_c = {
            { "filename", path = 1, symbols = { modified = " ●", readonly = " " } },
            { "diagnostics", symbols = { error = " ", warn = " ", info = " ", hint = " " } },
          },
          lualine_x = { offsec_target, "filetype" },
          lualine_y = { "progress" },
          lualine_z = { { "location", separator = { right = "" }, left_padding = 2 } },
        },
        extensions = { "neo-tree", "lazy", "trouble", "toggleterm" },
      }
    end,
  },

  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        mode = "buffers",
        separator_style = "slant",
        show_close_icon = false,
        diagnostics = "nvim_lsp",
        always_show_bufferline = false,
        offsets = {
          { filetype = "neo-tree", text = "explorer", highlight = "Directory", separator = true },
        },
      },
    },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "código" },
        { "<leader>f", group = "buscar" },
        { "<leader>g", group = "git" },
        { "<leader>m", group = "Markdown" },
        { "<leader>h", group = "http (kulala)" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "terminal/teste" },
        { "<leader>u", group = "toggles" },
        { "<leader>x", group = "appsec/payloads" },
        { "<leader>d", group = "debug" },
      },
    },
    keys = {
      { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "atalhos do buffer" },
    },
  },

  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        [[ ██████╗ ███████╗███████╗███████╗███████╗ ██████╗ ]],
        [[██╔═══██╗██╔════╝██╔════╝██╔════╝██╔════╝██╔════╝ ]],
        [[██║   ██║█████╗  █████╗  ███████╗█████╗  ██║      ]],
        [[██║   ██║██╔══╝  ██╔══╝  ╚════██║██╔══╝  ██║      ]],
        [[╚██████╔╝██║     ██║     ███████║███████╗╚██████╗ ]],
        [[ ╚═════╝ ╚═╝     ╚═╝     ╚══════╝╚══════╝ ╚═════╝ ]],
        [[                                                  ]],
        [[            a p p s e c   w o r k b e n c h        ]],
      }

      dashboard.section.buttons.val = {
        dashboard.button("f", "  buscar arquivo", "<cmd>Telescope find_files<CR>"),
        dashboard.button("g", "  buscar texto", "<cmd>Telescope live_grep<CR>"),
        dashboard.button("r", "  recentes", "<cmd>Telescope oldfiles<CR>"),
        dashboard.button("e", "  engagement ativo", "<cmd>OffsecEngagement<CR>"),
        dashboard.button("n", "  nova nota", "<cmd>enew<CR>"),
        dashboard.button("c", "  configuração", "<cmd>e ~/.config/nvim/init.lua<CR>"),
        dashboard.button("l", "󰒲  lazy", "<cmd>Lazy<CR>"),
        dashboard.button("q", "  sair", "<cmd>qa<CR>"),
      }

      dashboard.section.footer.val = "tema: " .. (vim.g.offsec_theme or "catppuccin-mocha")
      dashboard.opts.layout[1].val = 6
      alpha.setup(dashboard.opts)
    end,
  },

  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    opts = { timeout = 2500, stages = "fade", render = "compact", top_down = false },
    config = function(_, opts)
      local notify = require("notify")
      notify.setup(opts)
      vim.notify = notify
    end,
  },
}
