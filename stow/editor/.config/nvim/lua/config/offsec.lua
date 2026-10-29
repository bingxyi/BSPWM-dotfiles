-- BSPWM-dotfiles :: AppSec workflow commands
-- Semgrep quickfix results, active engagement, and journal. Loaded by init.lua.

local M = {}

function M.setup()
    local function engagement_path()
      local file = vim.env.HOME .. "/.local/share/offsec/engagement"
      local fd = io.open(file, "r")
      if not fd then
        return nil
      end
      local path = fd:read("*l")
      fd:close()
      if path == nil or path == "" then
        return nil
      end
      return path
    end

    vim.api.nvim_create_user_command("OffsecEngagement", function()
      local path = engagement_path()
      if not path then
        vim.notify("No active engagement (Super+O → engagement)", vim.log.levels.WARN)
        return
      end
      vim.cmd.cd(path)
      vim.cmd("Neotree reveal dir=" .. vim.fn.fnameescape(path))
    end, { desc = "Open active engagement" })

    vim.api.nvim_create_user_command("OffsecNote", function(cmd)
      local path = engagement_path()
      if not path then
        vim.notify("No active engagement", vim.log.levels.WARN)
        return
      end
      local journal = path .. "/notes/journal.md"
      if cmd.args ~= "" then
        local fd = io.open(journal, "a")
        if fd then
          fd:write(string.format("- **%s** %s\n", os.date("%d/%m %H:%M"), cmd.args))
          fd:close()
          vim.notify("Note saved to journal")
          return
        end
      end
      vim.cmd.edit(journal)
    end, { nargs = "*", desc = "Write to engagement journal" })

    vim.api.nvim_create_user_command("OffsecSemgrep", function(cmd)
      if vim.fn.executable("semgrep") ~= 1 then
        vim.notify("semgrep is not in PATH (pipx install semgrep)", vim.log.levels.ERROR)
        return
      end

      local config = cmd.args ~= "" and cmd.args or "auto"
      vim.notify("semgrep --config " .. config .. " …")

      vim.system(
        { "semgrep", "--config", config, "--json", "--quiet", "." },
        { text = true },
        vim.schedule_wrap(function(result)
          if result.code ~= 0 and result.stdout == "" then
            vim.notify("semgrep failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
            return
          end

          local ok, decoded = pcall(vim.json.decode, result.stdout)
          if not ok or type(decoded) ~= "table" or not decoded.results then
            vim.notify("Could not parse semgrep output", vim.log.levels.ERROR)
            return
          end

          local items = {}
          for _, finding in ipairs(decoded.results) do
            table.insert(items, {
              filename = finding.path,
              lnum = finding.start and finding.start.line or 1,
              col = finding.start and finding.start.col or 1,
              text = string.format(
                "[%s] %s",
                (finding.extra and finding.extra.severity) or "INFO",
                (finding.extra and finding.extra.message) or finding.check_id
              ),
            })
          end

          vim.fn.setqflist({}, "r", { title = "semgrep", items = items })
          if #items > 0 then
            vim.cmd("copen")
          end
          vim.notify(string.format("semgrep: %d findings", #items))
        end)
      )
    end, { nargs = "?", desc = "Run semgrep and populate quickfix with findings" })

    vim.keymap.set("n", "<leader>xg", "<cmd>OffsecSemgrep<CR>", { desc = "Run semgrep on project" })
    vim.keymap.set("n", "<leader>xe", "<cmd>OffsecEngagement<CR>", { desc = "Open active engagement" })
    vim.keymap.set("n", "<leader>xn", "<cmd>OffsecNote<CR>", { desc = "Engagement journal" })
end

return M
