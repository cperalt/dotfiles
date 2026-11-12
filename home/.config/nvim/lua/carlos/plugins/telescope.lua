-- Populated by config() so the lazily-registered keys below can reach the
-- test-file toggle state that lives inside config.
local M = {}

return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-tree/nvim-web-devicons",
    "folke/todo-comments.nvim",
  },
  cmd = "Telescope",
  keys = {
    {
      "<leader>ff",
      function()
        require("telescope.builtin").find_files()
      end,
      desc = "Fuzzy find files in cwd",
    },
    {
      "<leader>fr",
      function()
        M.recent_files()
      end,
      desc = "Fuzzy find recent files (project)",
    },
    {
      "<leader>fs",
      function()
        require("telescope.builtin").live_grep()
      end,
      desc = "Find string in cwd",
    },
    {
      "<leader>fc",
      function()
        require("telescope.builtin").grep_string()
      end,
      desc = "Find string under cursor in cwd",
    },
    { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Find todos" },
    {
      "<leader>fT",
      function()
        M.toggle_tests()
      end,
      desc = "Toggle hiding test files",
    },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")

    -- Test-file exclusion toggle (module-level so we can flip at runtime)
    local hide_tests = true

    -- Ripgrep globs (used by find_files via rg --files and live_grep)
    local test_globs = {
      "!**/__tests__/**",
      "!**/__mocks__/**",
      "!**/test/**",
      "!**/tests/**",
      "!**/*.test.*",
      "!**/*.spec.*",
      "!**/*_test.go",
    }

    -- Lua patterns (post-filter fallback, also covers oldfiles)
    local test_lua_patterns = {
      "__tests__/",
      "__mocks__/",
      "%.test%.",
      "%.spec%.",
      "_test%.",
      "/test/",
      "/tests/",
    }

    local function rg_find_command()
      local cmd = { "rg", "--files", "--hidden", "--glob", "!.git/" }
      if hide_tests then
        for _, g in ipairs(test_globs) do
          table.insert(cmd, "--glob")
          table.insert(cmd, g)
        end
      end
      return cmd
    end

    local function rg_grep_args()
      if not hide_tests then
        return {}
      end
      local args = {}
      for _, g in ipairs(test_globs) do
        table.insert(args, "--glob")
        table.insert(args, g)
      end
      return args
    end

    telescope.setup({
      defaults = {
        -- path_display = { "smart" },
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
        },
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-j>"] = actions.move_selection_next,
            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
          },
        },
      },
      pickers = {
        find_files = {
          hidden = true,
          find_command = rg_find_command,
        },
        live_grep = {
          additional_args = rg_grep_args,
        },
        grep_string = {
          additional_args = rg_grep_args,
        },
      },
    })

    telescope.load_extension("fzf")

    M.recent_files = function()
      require("telescope.builtin").oldfiles({
        cwd_only = true,
        file_ignore_patterns = hide_tests and test_lua_patterns or {},
      })
    end

    -- Toggle test-file visibility in Telescope pickers
    M.toggle_tests = function()
      hide_tests = not hide_tests
      vim.notify("Telescope: tests " .. (hide_tests and "hidden" or "shown"), vim.log.levels.INFO)
    end
  end,
}
