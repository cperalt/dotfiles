return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-neotest/neotest-jest",
  },
  config = function()
    local neotest = require("neotest")

    neotest.setup({
      adapters = {
        require("neotest-jest")({
          jestCommand = "npm test --",
          jestConfigFile = "jest.config.js",
          env = { CI = true },
          cwd = function()
            return vim.fn.getcwd()
          end,
        }),
      },
      -- Only scan files that look like test files; prevents neotest from
      -- trying to parse XML stubs and other non-JS/TS files in __tests__ dirs
      -- which causes a tight error loop (high CPU + memory leak).
      is_test_file = function(file_path)
        return file_path:match("[_%.]test%.[jt]sx?$") ~= nil
          or file_path:match("[_%.]spec%.[jt]sx?$") ~= nil
      end,
    })

    local keymap = vim.keymap

    keymap.set("n", "<leader>tr", function()
      neotest.run.run()
    end, { desc = "Run nearest test" })

    keymap.set("n", "<leader>tf", function()
      neotest.run.run(vim.fn.expand("%"))
    end, { desc = "Run current file" })

    keymap.set("n", "<leader>ts", function()
      neotest.summary.toggle()
    end, { desc = "Toggle test summary" })

    keymap.set("n", "<leader>to", function()
      neotest.output.open({ enter = true })
    end, { desc = "Show test output" })

    keymap.set("n", "<leader>tp", function()
      neotest.output_panel.toggle()
    end, { desc = "Toggle test output panel" })
  end,
}
