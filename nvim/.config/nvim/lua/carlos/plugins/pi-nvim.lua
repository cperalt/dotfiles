return {
  dir = "/tmp/pi-nvim",
  config = function()
    require("pi-nvim").setup({
      context_format = "reference", -- send @file:L1-L10 refs instead of embedding contents
      show_popup = false,           -- no floating dialog, just notifications
    })
  end,
  keys = {
    { "<leader>pa", ":Pi<CR>", mode = "n", silent = true, desc = "Pi: add file context" },
    { "<leader>pa", ":Pi<CR>", mode = "v", silent = true, desc = "Pi: add selection context" },
    { "<leader>pp", ":PiPing<CR>", mode = "n", silent = true, desc = "Pi: ping session" },
  },
}
