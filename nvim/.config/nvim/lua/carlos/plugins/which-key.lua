return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 500
  end,
  opts = {
    plugins = {
      marks = true,
      registers = true,
      presets = {
        operators = false,
        motions = false,
        text_objects = false,
        windows = false,
        nav = false,
        z = true,
        g = false,
      },
    },
    spec = {
      { "<leader>c", group = "Code" },
      { "<leader>d", group = "Diagnostics" },
      { "<leader>e", group = "Explorer" },
      { "<leader>f", group = "Find" },
      { "<leader>g", group = "Git" },
      { "<leader>h", group = "Hunk" },
      { "<leader>l", group = "Lint" },
      { "<leader>m", group = "Format" },
      { "<leader>r", group = "Refactor" },
      { "<leader>s", group = "Split" },
      { "<leader>t", group = "Test" },
      { "<leader>w", group = "Session" },
      { "<leader>x", group = "Trouble" },
      { "<leader><Tab>", group = "Tabs" },
    },
  },
}
