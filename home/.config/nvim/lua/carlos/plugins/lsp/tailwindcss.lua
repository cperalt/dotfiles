return {
  "neovim/nvim-lspconfig",
  config = function()
    -- Narrow the bundled tailwindcss config: fewer filetypes, and only activate
    -- when a Tailwind/PostCSS config exists (the bundled root_dir falls back to
    -- `.git`, which would start the server in every TS repo).
    vim.lsp.config("tailwindcss", {
      filetypes = {
        "html",
        "css",
        "scss",
        "javascriptreact",
        "typescriptreact",
        "svelte",
      },
      root_dir = function(bufnr, on_dir)
        local root = vim.fs.root(bufnr, {
          "tailwind.config.js",
          "tailwind.config.cjs",
          "tailwind.config.mjs",
          "tailwind.config.ts",
          "postcss.config.js",
          "postcss.config.cjs",
          "postcss.config.mjs",
          "postcss.config.ts",
        })
        if root then
          on_dir(root)
        end
      end,
    })
  end,
}
