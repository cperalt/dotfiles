require("carlos.core")
require("carlos.lazy")
require("nvim-ts-autotag").setup({
  opts = {
    -- Defaults
    enable_close = true, -- Auto close tags
    enable_rename = true, -- Auto rename pairs of tags
    enable_close_on_slash = false, -- Auto close on trailing </
  },
})

-- Set up word wrap settings similar to VSCode
vim.opt.textwidth = 80 -- Maximum line length (equivalent to VSCode's text-width)
vim.opt.wrap = true -- Enable line wrapping (equivalent to VSCode's word-wrap)
vim.opt.linebreak = true -- Wrap at word boundaries (optional, but recommended)
-- vim.opt.breakat = true -- Break lines at punctuation characters (optional, but recommended)
vim.opt.breakindent = true -- Indent wrapped lines (equivalent to VSCode's wrap indent)
vim.opt.formatoptions:append("t") -- Allow text wrapping in formatting functions
