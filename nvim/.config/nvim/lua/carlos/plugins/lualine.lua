return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local lualine = require("lualine")
    local lazy_status = require("lazy.status") -- to configure lazy pending updates count
    local C = require("catppuccin.palettes").get_palette("mocha")

    local custom_catppuccin = {
      normal = {
        a = { bg = C.blue, fg = C.mantle, gui = "bold" },
        b = { bg = C.surface0, fg = C.blue },
        c = { bg = C.mantle, fg = C.text },
      },
      insert = {
        a = { bg = C.green, fg = C.base, gui = "bold" },
        b = { bg = C.surface0, fg = C.green },
      },
      terminal = {
        a = { bg = C.green, fg = C.base, gui = "bold" },
        b = { bg = C.surface0, fg = C.green },
      },
      command = {
        a = { bg = C.peach, fg = C.base, gui = "bold" },
        b = { bg = C.surface0, fg = C.peach },
      },
      visual = {
        a = { bg = C.mauve, fg = C.base, gui = "bold" },
        b = { bg = C.surface0, fg = C.mauve },
      },
      replace = {
        a = { bg = C.red, fg = C.base, gui = "bold" },
        b = { bg = C.surface0, fg = C.red },
      },
      inactive = {
        a = { bg = C.mantle, fg = C.blue },
        b = { bg = C.mantle, fg = C.surface1, gui = "bold" },
        c = { bg = C.mantle, fg = C.overlay0 },
      },
    }

    lualine.setup({
      options = {
        theme = custom_catppuccin,
        component_separators = { left = "│", right = "│" },
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_c = {
          { "filename", path = 1 },
        },
        lualine_x = {
          {
            function()
              local ok, claude = pcall(require, "claudecode")
              if ok and claude.is_claude_connected() then
                return "Claude"
              end
              return ""
            end,
            cond = function()
              local ok, claude = pcall(require, "claudecode")
              return ok and claude.is_claude_connected()
            end,
            color = { fg = C.mauve },
          },
          {
            lazy_status.updates,
            cond = lazy_status.has_updates,
            color = { fg = C.peach },
          },
          { "encoding" },
          { "fileformat" },
          { "filetype" },
        },
      },
      inactive_sections = {
        lualine_c = {
          { "filename", path = 1 },
        },
      },
    })
  end,
}
