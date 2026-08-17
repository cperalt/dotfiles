return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local lint = require("lint")

    lint.linters_by_ft = {
      javascript = { "eslint_d" },
      typescript = { "eslint_d" },
      javascriptreact = { "eslint_d" },
      typescriptreact = { "eslint_d" },
      svelte = { "eslint_d" },
      python = { "pylint" },
    }

    local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      group = lint_augroup,
      callback = function(args)
        local bufnr = args.buf

        if vim.bo[bufnr].buftype ~= "" then
          return
        end

        if vim.bo[bufnr].filetype == "python" then
          -- Search upward from buffer file to find a venv pylint only for Python buffers
          local bufdir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":h")
          local venv_pylint = vim.fn.findfile(".venv/bin/pylint", bufdir .. ";")
          if venv_pylint ~= "" then
            lint.linters.pylint.cmd = vim.fn.fnamemodify(venv_pylint, ":p")
          else
            lint.linters.pylint.cmd = "pylint"
          end
        end

        lint.try_lint(nil, { ignore_errors = true })
      end,
    })

    vim.keymap.set("n", "<leader>l", function()
      lint.try_lint()
    end, { desc = "Trigger linting for current file" })
  end,
}
