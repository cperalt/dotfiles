-- Load the Neovim side of vim-herdr-navigation straight from the installed
-- plugin so `herdr plugin update` keeps it current. <C-h/j/k/l> move between
-- splits and, inside herdr, cross into the neighbouring pane at a split edge.
-- The herdr keybinds live in herdr/.config/herdr/config.toml.
local matches = vim.fn.glob(
  vim.fn.expand("~/.config/herdr/plugins/github/vim-herdr-navigation-*/editor/nvim.lua"),
  false,
  true
)
if #matches == 0 then
  vim.notify("vim-herdr-navigation: editor/nvim.lua not found; run `herdr plugin update`", vim.log.levels.WARN)
  return
end
dofile(matches[#matches])
