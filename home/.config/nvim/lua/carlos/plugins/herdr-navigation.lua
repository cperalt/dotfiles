-- Neovim side of vim-herdr-navigation, loaded straight from the copy herdr
-- installs so `herdr plugin update` keeps it current. <C-h/j/k/l> move between
-- splits and, inside herdr, cross into the neighbouring pane at a split edge.
-- The herdr keybinds live in herdr/.config/herdr/config.toml.
local matches = vim.fn.glob(vim.fn.expand("~/.config/herdr/plugins/github/vim-herdr-navigation-*"), false, true)
if #matches == 0 then
  vim.notify("vim-herdr-navigation not installed; run `herdr plugin update`", vim.log.levels.WARN)
  return {}
end

local dir = matches[#matches]
return {
  name = "vim-herdr-navigation",
  dir = dir,
  lazy = false,
  config = function()
    dofile(dir .. "/editor/nvim.lua")
  end,
}
