return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  dependencies = {
    "windwp/nvim-ts-autotag",
  },
  config = function()
    -- Map filetype "tf" → terraform parser (Neovim detects .tf files as "tf", not "terraform")
    vim.treesitter.language.register("terraform", "tf")
    -- Reuse the bash parser for shell-like config files so Treesitter-based integrations work there.
    vim.treesitter.language.register("bash", "zsh")
    vim.treesitter.language.register("bash", "ghostty")

    require("nvim-treesitter").install({
      "json",
      "javascript",
      "typescript",
      "tsx",
      "yaml",
      "html",
      "css",
      "prisma",
      "markdown",
      "markdown_inline",
      "svelte",
      "graphql",
      "bash",
      "lua",
      "vim",
      "dockerfile",
      "gitignore",
      "query",
      "vimdoc",
      "c",
      "python",
      "terraform",
      "tmux",
      "toml",
    })

    -- Enable treesitter highlighting and indentation via built-in API (Neovim 0.12+)
    vim.api.nvim_create_autocmd("FileType", {
      callback = function()
        if vim.treesitter.get_parser() then
          vim.treesitter.start()
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
