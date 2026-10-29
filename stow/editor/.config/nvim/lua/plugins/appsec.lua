-- Plugins e comandos que só existem porque a máquina é de application security.
return {
  -- cliente HTTP dentro do editor: .http versionado junto do engagement
  {
    "mistweaverco/kulala.nvim",
    ft = { "http", "rest" },
    opts = {
      default_view = "body",
      default_env = "dev",
      debug = false,
      icons = { inlay = { loading = "⏳", done = "✅", error = "❌" } },
    },
    keys = {
      { "<leader>hs", function() require("kulala").run() end, desc = "enviar request", ft = "http" },
      { "<leader>ha", function() require("kulala").run_all() end, desc = "enviar todas", ft = "http" },
      { "<leader>hn", function() require("kulala").jump_next() end, desc = "próxima request", ft = "http" },
      { "<leader>hp", function() require("kulala").jump_prev() end, desc = "request anterior", ft = "http" },
      { "<leader>ht", function() require("kulala").toggle_view() end, desc = "body/headers", ft = "http" },
      { "<leader>hc", function() require("kulala").copy() end, desc = "copiar como curl", ft = "http" },
    },
  },

  -- inspeção de binários sem sair do nvim
  {
    "RaafatTurki/hex.nvim",
    cmd = { "HexDump", "HexAssemble", "HexToggle" },
    config = true,
    keys = {
      { "<leader>xH", "<cmd>HexToggle<CR>", desc = "alternar visão hexadecimal" },
    },
  },

  -- relatórios e notas em markdown com render decente
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "codecompanion" },
    cmd = { "RenderMarkdown" },
    keys = {
      { "<leader>mp", "<cmd>RenderMarkdown preview<CR>", desc = "Markdown: prévia ao lado", ft = "markdown" },
      { "<leader>mt", "<cmd>RenderMarkdown buf_toggle<CR>", desc = "Markdown: alternar visualização", ft = "markdown" },
    },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      enabled = true,
      render_modes = { "n", "c", "t" },
      heading = { sign = false, position = "inline" },
      code = { style = "full", width = "block", left_pad = 1, right_pad = 1 },
      checkbox = { unchecked = { icon = "󰄱 " }, checked = { icon = "󰱒 " } },
    },
  },

  -- debug (útil para PoC em Python/Go/Node)
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
      "theHamsta/nvim-dap-virtual-text",
    },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "continuar" },
      { "<leader>di", function() require("dap").step_into() end, desc = "step into" },
      { "<leader>do", function() require("dap").step_over() end, desc = "step over" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "step out" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "terminar" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "painel de debug" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()
      require("nvim-dap-virtual-text").setup({})

      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
      dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

      vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapStopped", { text = "", texthl = "DiagnosticWarn" })
    end,
  },

}
