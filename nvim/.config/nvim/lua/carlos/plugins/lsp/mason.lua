return {
  "williamboman/mason-lspconfig.nvim",
  opts = {
    -- Auto-enabling every matching server in large monorepos can noticeably delay
    -- the first render for TS files. Keep ts_ls enabled, but skip the heaviest
    -- extra servers for now while debugging startup lag.
    automatic_enable = {
      exclude = {
        "tailwindcss",
      },
    },

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
