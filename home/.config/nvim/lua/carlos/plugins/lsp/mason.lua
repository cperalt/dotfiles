return {
  "williamboman/mason-lspconfig.nvim",
  opts = {
    -- Every installed server is auto-enabled except those excluded here.
    -- tailwindcss is narrowed in lsp/tailwindcss.lua so it only starts where a
    -- Tailwind config exists. graphql needs a .graphqlrc to do anything (none in
    -- our repos) and emmet abbreviations go unused, yet both started on every
    -- .tsx buffer.
    automatic_enable = { exclude = { "graphql", "emmet_ls" } },
    ensure_installed = {
      "ts_ls",
      "html",
      "cssls",
      "tailwindcss",
      "svelte",
      "lua_ls",
      "prismals",
      "pyright",
      "terraformls",
    },
  },
  dependencies = {
    {
      "williamboman/mason.nvim",
      opts = {
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      },
    },
    "neovim/nvim-lspconfig",
  },
}
