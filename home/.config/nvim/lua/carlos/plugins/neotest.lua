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

    -- This is an Nx monorepo: each project has its own jest config and env is
    -- provided by mise. Resolve the workspace root and the project-local jest
    -- config from the spec file so one adapter works across all projects/worktrees.
    local function ws_root(file)
      local nx = vim.fs.find({ "nx.json" }, { upward = true, path = file })[1]
      return nx and vim.fs.dirname(nx) or vim.fn.getcwd()
    end

    local function nearest_jest_config(file)
      local root = ws_root(file)
      for _, cfg in ipairs(vim.fs.find({ "jest.config.ts", "jest.config.js" }, { upward = true, path = file })) do
        if vim.fs.dirname(cfg) ~= root then
          return cfg
        end
      end
      return root .. "/jest.config.ts"
    end

    neotest.setup({
      adapters = {
        require("neotest-jest")({
          -- Call the jest binary directly through mise instead of `npm test`/`nx test`:
          -- mise supplies the managed node + .env (POSTGRES_*), and bypassing the nx
          -- wrapper avoids its arg-schema rejection of jest flags (e.g. --testLocationInResults).
          jestCommand = "mise exec -- node_modules/.bin/jest",
          jestConfigFile = nearest_jest_config,
          env = { CI = "true" },
          cwd = ws_root,
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
