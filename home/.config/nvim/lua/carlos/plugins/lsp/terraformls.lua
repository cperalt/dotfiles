return {
  "neovim/nvim-lspconfig",
  config = function()
    -- terraform-ls logs its routine activity to stderr, which Neovim records as
    -- ERROR lines in lsp.log (the bulk of a 145 MB log). Send it nowhere.
    vim.lsp.config("terraformls", {
      cmd = { "terraform-ls", "serve", "-log-file=/dev/null" },
    })
  end,
}
