return {
  "tpope/vim-dadbod",
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
    },
    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
    },
    init = function()
      -- Optional: customize UI settings
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_winwidth = 40
      vim.g.db_ui_show_help = 0
    end,
  },
}
