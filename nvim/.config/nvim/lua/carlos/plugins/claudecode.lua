return {
  "coder/claudecode.nvim",
  lazy = false,
  config = function()
    require("claudecode").setup({
      auto_start = true,
      terminal = {
        provider = "none",
      },
      track_selection = true,
      diff_opts = {
        auto_close_on_accept = true,
      },
    })
  end,
  keys = {
    { "<leader>c", nil, desc = "Claude Code" },
    { "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    { "<leader>cs", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    {
      "<leader>cs",
      "<cmd>ClaudeCodeTreeAdd<cr>",
      desc = "Add file",
      ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
    },
    { "<leader>ca", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    { "<leader>cd", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
  },
}
