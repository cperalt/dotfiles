return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  config = function()
    require("copilot").setup({
      panel = {
        enabled = true,
        auto_refresh = false,
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<M-CR>",
        },
        layout = {
          position = "bottom", -- | top | left | right
          ratio = 0.4,
        },
      },
      suggestion = {
        enabled = true,
        auto_trigger = true,
        debounce = 75,
        keymap = {
          accept = "<C-c>",
          accept_word = false,
          accept_line = false,
          next = "<C-v>",
          prev = "<C-x>",
          dismiss = "<C-]>",
        },
      },
      filetypes = {
        ["*"] = true,
        ["."] = true,
        yaml = true,
        markdown = true,
        help = false,
        gitcommit = false,
        gitrebase = false,
        hgcommit = false,
        -- svn = false,
        -- cvs = false,
      },
      copilot_node_command = vim.fn.expand("$HOME") .. "/.nvm/versions/node/v22.9.0/bin/node",
      server_opts_overrides = {},
      copilot_model = "gpt-4o-copilot",
    })
    -- require("copilot.suggestion").toggle_auto_trigger()
  end,
}
