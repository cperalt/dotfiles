return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-neotest/neotest-jest",
  },
  -- Loaded on first use (keymaps below); it pulled in nvim-nio, plenary and the
  -- jest adapter at startup otherwise.
  keys = {
    {
      "<leader>tr",
      function()
        require("neotest").run.run()
      end,
      desc = "Run nearest test",
    },
    {
      "<leader>tf",
      function()
        require("neotest").run.run(vim.fn.expand("%"))
      end,
      desc = "Run current file",
    },
    {
      "<leader>ts",
      function()
        require("neotest").summary.toggle()
      end,
      desc = "Toggle test summary",
    },
    {
      "<leader>to",
      function()
        require("neotest").output.open({ enter = true })
      end,
      desc = "Show test output",
    },
    {
      "<leader>tp",
      function()
        require("neotest").output_panel.toggle()
      end,
      desc = "Toggle test output panel",
    },
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
        return file_path:match("[_%.]test%.[jt]sx?$") ~= nil or file_path:match("[_%.]spec%.[jt]sx?$") ~= nil
      end,
    })
  end,
}
