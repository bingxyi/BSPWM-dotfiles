return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function() require("config.treesitter").setup() end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = { select = { lookahead = true }, move = { set_jumps = true } },
    config = function(_, opts)
      require("nvim-treesitter-textobjects").setup(opts)
      local selections = {
        af = "@function.outer", ["if"] = "@function.inner",
        ac = "@class.outer", ic = "@class.inner",
        aa = "@parameter.outer", ia = "@parameter.inner",
      }
      for keys, capture in pairs(selections) do
        vim.keymap.set({ "x", "o" }, keys, function()
          require("nvim-treesitter-textobjects.select").select_textobject(capture, "textobjects")
        end, { desc = "Select " .. capture })
      end
      local motions = {
        ["]f"] = { "goto_next_start", "@function.outer" },
        ["[f"] = { "goto_previous_start", "@function.outer" },
        ["]c"] = { "goto_next_start", "@class.outer" },
        ["[c"] = { "goto_previous_start", "@class.outer" },
      }
      for keys, motion in pairs(motions) do
        vim.keymap.set({ "n", "x", "o" }, keys, function()
          require("nvim-treesitter-textobjects.move")[motion[1]](motion[2], "textobjects")
        end, { desc = "Move to " .. motion[2] })
      end
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim",
      {
        "L3MON4D3/LuaSnip",
        build = "make install_jsregexp",
        dependencies = { "rafamadriz/friendly-snippets" },
        config = function()
          require("luasnip.loaders.from_vscode").lazy_load()
          require("luasnip.loaders.from_snipmate").lazy_load({
            paths = { vim.fn.stdpath("config") .. "/snippets" },
          })
        end,
      },
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        completion = { completeopt = "menu,menuone,noinsert" },
        window = {
          completion = cmp.config.window.bordered({ border = "rounded" }),
          documentation = cmp.config.window.bordered({ border = "rounded" }),
        },
        mapping = cmp.mapping.preset.insert({
          -- Tab accepts the suggestion, as in VS Code. Navigate with arrows
          -- or C-n/C-p; Tab confirms. Without an open completion menu,
          -- Tab retains its normal indentation behavior.
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              if cmp.get_selected_entry() then
                cmp.confirm({ select = false })
              else
                -- completeopt includes noinsert: the first item is selected but not inserted.
                -- select = true accepts that item.
                cmp.confirm({ select = true })
              end
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<Down>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
          ["<Up>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip", priority = 750 },
          { name = "path", priority = 500 },
        }, {
          { name = "buffer", priority = 250, keyword_length = 3 },
        }),
        formatting = {
          fields = { "kind", "abbr", "menu" },
          format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "…",
            menu = {
              nvim_lsp = "[lsp]",
              luasnip = "[snip]",
              buffer = "[buf]",
              path = "[path]",
            },
          }),
        },
        experimental = { ghost_text = { hl_group = "Comment" } },
      })

      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })

      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
      })
    end,
  },

  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        desc = "Format file",
      },
    },
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format", "black", stop_after_first = true },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        json = { "jq" },
        yaml = { "prettierd", "prettier", stop_after_first = true },
        html = { "prettierd", "prettier", stop_after_first = true },
        css = { "prettierd", "prettier", stop_after_first = true },
        markdown = { "prettierd", "prettier", stop_after_first = true },
        sh = { "shfmt" },
        bash = { "shfmt" },
        go = { "gofmt" },
        php = { "php_cs_fixer" },
      },
      format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return nil
        end
        return { timeout_ms = 1200, lsp_fallback = true }
      end,
      formatters = {
        shfmt = { prepend_args = { "-i", "4", "-ci" } },
      },
    },
    init = function()
      vim.api.nvim_create_user_command("FormatToggle", function()
        vim.g.disable_autoformat = not vim.g.disable_autoformat
        vim.notify("format on save: " .. (vim.g.disable_autoformat and "off" or "on"))
      end, { desc = "Toggle format on save" })
    end,
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        python = { "ruff", "semgrep" },
        javascript = { "eslint_d", "semgrep" },
        typescript = { "eslint_d", "semgrep" },
        javascriptreact = { "eslint_d", "semgrep" },
        typescriptreact = { "eslint_d", "semgrep" },
        php = { "semgrep" },
        go = { "semgrep" },
        java = { "semgrep" },
        ruby = { "semgrep" },
        yaml = { "yamllint" },
        dockerfile = { "hadolint" },
      }

      -- Run only tools found in PATH to avoid errors for missing executables.
      local function try_lint()
        local names = lint.linters_by_ft[vim.bo.filetype] or {}
        local available = {}
        for _, name in ipairs(names) do
          local linter = lint.linters[name]
          local cmd = type(linter) == "table" and linter.cmd or name
          if vim.fn.executable(cmd) == 1 then
            table.insert(available, name)
          end
        end
        if #available > 0 then
          lint.try_lint(available)
        end
      end

      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("rice_lint", { clear = true }),
        callback = try_lint,
      })

      vim.api.nvim_create_user_command("Lint", try_lint, { desc = "Run file type linters" })
    end,
  },
}
