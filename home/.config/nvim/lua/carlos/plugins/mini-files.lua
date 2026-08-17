return {
  "echasnovski/mini.nvim",
  config = function()
    require("mini.files").setup({
      -- Customization of shown content
      content = {
        filter = nil, -- Predicate for which file system entries to show
        prefix = nil, -- What prefix to show to the left of file system entry
        sort = nil, -- In which order to show file system entries
      },

      -- Module mappings created only inside explorer.
      -- Use `''` (empty string) to not create one.
      mappings = {
        close = "q",
        go_in = "l",
        go_in_plus = "L",
        go_out = "h",
        go_out_plus = "H",
        reset = "<BS>",
        reveal_cwd = "@",
        show_help = "g?",
        synchronize = "=",
        trim_left = "<",
        trim_right = ">",
      },

      -- General options
      options = {
        permanent_delete = true, -- Whether to delete permanently or move into module-specific trash
        use_as_default_explorer = true, -- Whether to use for editing directories
      },

      -- Customization of explorer windows
      windows = {
        max_number = math.huge, -- Maximum number of windows to show side by side
        preview = false, -- Whether to show preview of file/directory under cursor
        width_focus = 50, -- Width of focused window
        width_nofocus = 15, -- Width of not focused window
        width_preview = 25, -- Width of preview window
      },
    })

    -- Helper function to copy path to clipboard (yazi-style)
    local copy_path = function(path_type)
      local MiniFiles = require("mini.files")
      local entry = MiniFiles.get_fs_entry()
      if not entry then
        vim.notify("No entry under cursor", vim.log.levels.WARN)
        return
      end

      local path = entry.path
      if path_type == "relative" then
        path = vim.fn.fnamemodify(path, ":.")
      elseif path_type == "dirname" then
        path = vim.fn.fnamemodify(path, ":p")
      elseif path_type == "filename" then
        path = vim.fn.fnamemodify(path, ":t")
      elseif path_type == "name_without_ext" then
        path = vim.fn.fnamemodify(path, ":t:r")
      end

      vim.fn.setreg("+", path)
      vim.notify("Copied: " .. path, vim.log.levels.INFO)
    end

    -- Set up yazi-style keybindings inside mini.files
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesBufferCreate",
      callback = function(args)
        local buf_id = args.data.buf_id

        -- Yazi-style copy keybindings (cc, cd, cf, cn)
        vim.keymap.set("n", "cc", function()
          copy_path("relative")
        end, { buffer = buf_id, desc = "Copy relative path" })

        vim.keymap.set("n", "cd", function()
          copy_path("dirname")
        end, { buffer = buf_id, desc = "Copy absolute path" })

        vim.keymap.set("n", "cf", function()
          copy_path("filename")
        end, { buffer = buf_id, desc = "Copy filename" })

        vim.keymap.set("n", "cn", function()
          copy_path("name_without_ext")
        end, { buffer = buf_id, desc = "Copy filename without extension" })
      end,
    })

    -- Set keymaps
    local keymap = vim.keymap

    keymap.set("n", "<leader>ee", function()
      require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
    end, { desc = "Open mini.files (directory of current file)" })

    keymap.set("n", "<leader>eE", function()
      require("mini.files").open(vim.loop.cwd(), true)
    end, { desc = "Open mini.files (cwd)" })
  end,
}
