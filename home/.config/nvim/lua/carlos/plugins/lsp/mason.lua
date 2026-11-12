return {
  "williamboman/mason-lspconfig.nvim",
  opts = {
    -- Every server here is auto-enabled. tailwindcss is narrowed in
    -- lsp/tailwindcss.lua so it only starts where a Tailwind config exists.
    automatic_enable = true,
    --     -- list of servers for mason to install
    ensure_installed = {
      "ts_ls",
      "html",
      "cssls",
      "tailwindcss",
      "svelte",
      "lua_ls",
      "graphql",
      "emmet_ls",
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
