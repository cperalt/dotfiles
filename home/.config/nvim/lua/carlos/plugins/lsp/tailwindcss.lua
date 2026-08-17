return {
  "neovim/nvim-lspconfig",
  config = function()
    local util = require("lspconfig.util")

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
    if ok_cmp then
      capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
    end

    vim.lsp.config("tailwindcss", {
      capabilities = capabilities,
      single_file_support = false,
      filetypes = {
        "html",
        "css",
        "scss",
        "javascriptreact",
        "typescriptreact",
        "svelte",
      },
      root_dir = util.root_pattern(
        "tailwind.config.js",
        "tailwind.config.cjs",
        "tailwind.config.mjs",
        "tailwind.config.ts",
        "postcss.config.js",
        "postcss.config.cjs",
        "postcss.config.mjs",
        "postcss.config.ts"
      ),
    })

    vim.lsp.enable("tailwindcss")
  end,
}
