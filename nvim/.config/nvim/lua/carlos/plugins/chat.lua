return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    dependencies = {
      { "zbirenbaum/copilot.lua" }, -- or github/copilot.vim
      { "nvim-lua/plenary.nvim" }, -- for curl, log wrapper
    },
    -- build = "make tiktoken", -- Only on MacOS or Linux
    opts = {
      model = "claude-3.5-sonnet",
      -- window = {
      --   layout = "float",
      -- },
      show_help = true,
      debug = true, -- Enable debugging
      question_header = "## THE USER",
      answer_header = "## THE CATILA",
      -- See Configuration section for rest
      mappings = {
        complete = {
          detail = "Use @<Tab> or /<Tab> for options.",
          insert = "<Tab>",
        },
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        reset = {
          normal = "<C-r>",
          insert = "<C-r>",
        },
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-m>",
        },
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
        yank_diff = {
          normal = "gy",
        },
        show_diff = {
          normal = "gd",
        },
        -- show_system_prompt = {
        --   normal = "gp",
        -- },
        -- show_user_selection = {
        --   normal = "gs",
        -- },
      },
    },
    -- See Commands section for default commands if you want to lazy load on them
  },
}
