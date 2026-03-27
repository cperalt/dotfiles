return {
  "alexghergh/nvim-tmux-navigation",
  config = function()
    local nav = require("nvim-tmux-navigation")
    nav.setup({ disable_when_zoomed = true })
    vim.keymap.set({ "n", "v", "x" }, "<C-h>", nav.NvimTmuxNavigateLeft)
    vim.keymap.set({ "n", "v", "x" }, "<C-j>", nav.NvimTmuxNavigateDown)
    vim.keymap.set({ "n", "v", "x" }, "<C-k>", nav.NvimTmuxNavigateUp)
    vim.keymap.set({ "n", "v", "x" }, "<C-l>", nav.NvimTmuxNavigateRight)
  end,
}
