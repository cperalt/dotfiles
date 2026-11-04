-- Neovim inside Rex: <C-h/j/k/l> across splits and panes, :Rex to drop the
-- current file/selection reference into the agent's prompt.
-- omp side: ~/.omp/agent/extensions/rex-nvim.ts (loads ~/code/rex.nvim/omp/rex-nvim.ts).
-- Rex side: ctrl+h/j/k/l passthrough in ~/.config/rex/init.lua (vim_focus).
return {
  "cperalt/rex.nvim",
  dev = true,
  enabled = vim.env.REX_BLOCK ~= nil, -- outside Rex, pi-nvim / herdr-navigation take over
  lazy = false,
  main = "rex-nvim",
  opts = {
    keymaps = false, -- the <leader>p* keys below instead of the plugin's <leader>r*
    live_context = {
      enabled = true,
      include_buffer_text = false,
    },
  },
  keys = {
    { "<leader>pa", ":Rex<CR>", mode = { "n", "v" }, silent = true, desc = "Rex: add context" },
    { "<leader>pq", ":RexAdd<CR>", mode = { "n", "v" }, silent = true, desc = "Rex: queue context" },
    { "<leader>pf", ":RexFlush<CR>", mode = "n", silent = true, desc = "Rex: flush queue" },
    { "<leader>pp", ":RexPing<CR>", mode = "n", silent = true, desc = "Rex: ping omp" },
  },
}
