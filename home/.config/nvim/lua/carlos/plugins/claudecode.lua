local function send_and_focus_claude()
  vim.cmd("ClaudeCodeSend")
  local pane = vim.fn.system(
    "tmux list-panes -F '#{pane_index}:#{pane_current_command}' | grep -i claude | cut -d: -f1 | head -1 | tr -d '\n'"
  )
  if pane == "" then
    pane = vim.fn.system(
      "tmux list-panes -F '#{pane_index}:#{pane_current_command}' | grep -iv 'nvim\\|vim' | cut -d: -f1 | head -1 | tr -d '\n'"
    )
  end
  if pane ~= "" then
    vim.fn.system("tmux select-pane -t " .. pane)
  end
end

return {
  "coder/claudecode.nvim",
  lazy = false,
  enable = false,
  config = function()
    require("claudecode").setup({
      auto_start = false,
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
    { "<leader>cs", send_and_focus_claude, mode = "v", desc = "Send to Claude" },
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
