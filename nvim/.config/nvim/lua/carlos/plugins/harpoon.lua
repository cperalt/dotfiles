return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local harpoon = require("harpoon")

    -- REQUIRED
    harpoon:setup()

    local keymap = vim.keymap

    -- Toggle harpoon quick menu (using Telescope)
    local conf = require("telescope.config").values
    local function toggle_telescope(harpoon_files)
      local entries = {}
      for _, item in ipairs(harpoon_files.items) do
        local row = item.context and item.context.row or 0
        table.insert(entries, {
          value = item.value,
          display = item.value .. ":" .. row,
          ordinal = item.value,
          filename = item.value,
          lnum = row,
        })
      end

      require("telescope.pickers")
        .new({}, {
          prompt_title = "Harpoon",
          finder = require("telescope.finders").new_table({
            results = entries,
            entry_maker = function(entry)
              return {
                value = entry.value,
                display = entry.display,
                ordinal = entry.ordinal,
                filename = entry.value,
                lnum = entry.lnum,
              }
            end,
          }),
          previewer = conf.grep_previewer({}),
          sorter = conf.generic_sorter({}),
        })
        :find()
    end

    keymap.set("n", "<leader>mm", function()
      toggle_telescope(harpoon:list())
    end, { desc = "Harpoon: Open menu (Telescope)" })

    -- Native Harpoon UI (use dd to delete marks, reorder lines, etc.)
    keymap.set("n", "<leader>me", function()
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end, { desc = "Harpoon: Edit marks" })

    -- Add current file to harpoon list
    keymap.set("n", "<leader>ma", function()
      harpoon:list():add()
    end, { desc = "Harpoon: Add file" })

    -- Quick nav to harpooned files by index
    for i = 1, 4 do
      keymap.set("n", "<leader>" .. i, function()
        harpoon:list():select(i)
      end, { desc = "which_key_ignore" })
    end

    -- Cycle through harpoon list
    keymap.set("n", "<leader>mp", function()
      harpoon:list():prev()
    end, { desc = "Harpoon: Previous file" })

    keymap.set("n", "<leader>mn", function()
      harpoon:list():next()
    end, { desc = "Harpoon: Next file" })
  end,
}
