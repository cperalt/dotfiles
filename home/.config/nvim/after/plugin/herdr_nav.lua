-- Inside herdr, load the Neovim side of vim-herdr-navigation straight from the
-- installed plugin so `herdr plugin update` keeps it current. Lives in
-- after/plugin so its <C-h/j/k/l> maps win over nvim-tmux-navigation's.
-- The herdr keybinds live in herdr/.config/herdr/config.toml.
if not vim.env.HERDR_PANE_ID or vim.env.HERDR_PANE_ID == "" then
  return
end

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
