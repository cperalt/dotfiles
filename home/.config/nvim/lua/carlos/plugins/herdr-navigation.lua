-- Neovim side of vim-herdr-navigation, loaded straight from the copy herdr
-- installs so `herdr plugin update` keeps it current. <C-h/j/k/l> move between
-- splits and, inside herdr, cross into the neighbouring pane at a split edge.
-- Only enabled inside Herdr; in Rex, rex.nvim owns these keys.
-- The herdr keybinds live in herdr/.config/herdr/config.toml.
if vim.env.HERDR_PANE_ID == nil then
  return {}
end
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
