return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local lint = require("lint")

    -- JS/TS linting comes from the eslint language server (mason), which lints
    -- as you type and offers fix-all/disable-rule code actions. Running eslint_d
    -- here as well doubled every diagnostic and cost ~160ms per buffer switch.
    lint.linters_by_ft = {
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
