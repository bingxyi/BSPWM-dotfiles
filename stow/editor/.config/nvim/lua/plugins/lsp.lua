return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      {
        "mason-org/mason.nvim",
        cmd = "Mason",
        keys = { { "<leader>cm", "<cmd>Mason<CR>", desc = "mason" } },
        opts = { ui = { border = "rounded" } },
      },
      "mason-org/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local servers = {
        "lua_ls",
        "bashls",
        "pyright",
        "ts_ls",
        "gopls",
        "jsonls",
        "yamlls",
        "html",
        "cssls",
        "dockerls",
        "marksman",
        "intelephense",
        "rust_analyzer",
        "clangd",
      }

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      if ok_cmp then
        capabilities = vim.tbl_deep_extend("force", capabilities, cmp_lsp.default_capabilities())
      end

      -- Native Neovim 0.11+ API: configure all servers at once.
      vim.lsp.config("*", { capabilities = capabilities })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            workspace = {
              checkThirdParty = false,
              -- Without the Neovim runtime library, lua_ls knows Lua but not the Neovim
              -- API, so vim. has no completions. Declaring vim as a global only silences
              -- diagnostics; it does not teach the server the API.
              library = vim.api.nvim_get_runtime_file("", true),
            },
            diagnostics = { globals = { "vim" } },
            completion = { callSnippet = "Replace" },
            telemetry = { enable = false },
            hint = { enable = true },
          },
        },
      })

      vim.lsp.config("pyright", {
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
            },
          },
        },
      })

      -- HOME is a dotfiles git repo, not a Markdown workspace.
      vim.lsp.config("marksman", {
        root_markers = {},
        root_dir = function(bufnr, on_dir)
          local file = vim.api.nvim_buf_get_name(bufnr)
          local root = vim.fs.root(file, { ".marksman.toml", ".git" })
          local home = vim.uv.fs_realpath(vim.env.HOME) or vim.fs.normalize(vim.env.HOME)
          local resolved = root and (vim.uv.fs_realpath(root) or vim.fs.normalize(root))
          local temporary_root = vim.fs.normalize(vim.env.TMPDIR or "/tmp")
          if resolved == home or resolved == "/" or resolved == temporary_root then
            root = nil
          end
          on_dir(root) -- nil selects Marksman's single-file mode.
        end,
      })

      require("mason-lspconfig").setup({
        ensure_installed = servers,
        automatic_enable = true,
      })

      for _, server in ipairs(servers) do
        pcall(vim.lsp.enable, server)
      end

      vim.diagnostic.config({
        virtual_text = { spacing = 4, prefix = "●", source = "if_many" },
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = " ",
            [vim.diagnostic.severity.HINT] = " ",
          },
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("offsec_lsp", { clear = true }),
        callback = function(event)
          local function map(keys, func, desc, mode)
            vim.keymap.set(mode or "n", keys, func, { buffer = event.buf, desc = "lsp: " .. desc })
          end

          map("gd", "<cmd>Telescope lsp_definitions<CR>", "Go to definition")
          map("gr", "<cmd>Telescope lsp_references<CR>", "References")
          map("gI", "<cmd>Telescope lsp_implementations<CR>", "Implementations")
          map("gy", "<cmd>Telescope lsp_type_definitions<CR>", "Type definition")
          map("gD", vim.lsp.buf.declaration, "Declaration")
          map("K", vim.lsp.buf.hover, "Documentation")
          map("<C-k>", vim.lsp.buf.signature_help, "Signature help", "i")
          map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "code action", { "n", "v" })
          map("<leader>cl", "<cmd>LspInfo<CR>", "Server information")

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method("textDocument/inlayHint") then
            map("<leader>uh", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }), { bufnr = event.buf })
            end, "inlay hints")
          end

          if client and client:supports_method("textDocument/documentHighlight") then
            local group = vim.api.nvim_create_augroup("offsec_lsp_highlight", { clear = false })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer = event.buf,
              group = group,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer = event.buf,
              group = group,
              callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })
    end,
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    event = "VeryLazy",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "stylua",
        "shfmt",
        "shellcheck",
        "prettier",
        "black",
        "ruff",
        "hadolint",
        "yamllint",
        "jq",
      },
      run_on_start = true,
      auto_update = false,
    },
  },
}
