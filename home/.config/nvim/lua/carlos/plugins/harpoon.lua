return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local harpoon = require("harpoon")

    -- ── Line marks: a second harpoon list ("marks") ──────────────────────
    -- Each item encodes "path:row" in `value`, so every mark is unique and
    -- dedup, quick-menu editing and persistence are inherited from harpoon.
    -- An extmark tracks each mark while its buffer is loaded, so positions
    -- follow your edits within a session.

    local marks_ns = vim.api.nvim_create_namespace("carlos_harpoon_marks")

    -- "path:12" -> "path", 12 ; plain "path" -> "path", nil
    local function parse(value)
      local path, row = value:match("^(.+):(%d+)$")
      if path then
        return path, tonumber(row)
      end
      return value, nil
    end

    local function buf_matches(bufname, path)
      return bufname == path or vim.endswith(bufname, "/" .. path)
    end

    -- Current 1-indexed row of the item's extmark, or nil if it is not
    -- alive (unloaded buffer, stale bufnr from a previous session, etc.)
    local function extmark_row(item)
      local ctx = item.context
      if not (ctx and ctx.extmark_id and ctx.bufnr) then
        return nil
      end
      if not vim.api.nvim_buf_is_valid(ctx.bufnr) then
        return nil
      end
      local path = parse(item.value)
      if not buf_matches(vim.api.nvim_buf_get_name(ctx.bufnr), path) then
        return nil -- bufnr recycled for a different file
      end
      local pos = vim.api.nvim_buf_get_extmark_by_id(ctx.bufnr, marks_ns, ctx.extmark_id, {})
      if #pos == 0 then
        return nil
      end
      return pos[1] + 1
    end

    local function plant_extmark(item, buf, row)
      row = math.min(row, vim.api.nvim_buf_line_count(buf))
      item.context = item.context or {}
      item.context.extmark_id = vim.api.nvim_buf_set_extmark(buf, marks_ns, row - 1, 0, {})
      item.context.bufnr = buf
    end

    -- Sync stored "path:row" values with live extmark positions for every
    -- mark in `buf`; plant extmarks for marks that do not have one yet.
    local function refresh_marks(list, buf)
      local bufname = vim.api.nvim_buf_get_name(buf)
      if bufname == "" then
        return
      end

      -- Phase 1: compute proposed values from live extmarks; plant
      -- extmarks for marks in this buffer that do not have one yet.
      local updates = {}
      local proposed = {}
      for i = 1, list._length or 0 do
        local item = list.items[i]
        if item then
          local path, row = parse(item.value)
          if row and buf_matches(bufname, path) then
            local live = extmark_row(item)
            if live then
              local u = { item = item, value = path .. ":" .. live, row = live }
              table.insert(updates, u)
              proposed[item] = u.value
            else
              plant_extmark(item, buf, row)
            end
          end
        end
      end

      -- Phase 2: apply only updates whose final value stays unique across
      -- the whole list (two items must never share a value, harpoon #476).
      local counts = {}
      for i = 1, list._length or 0 do
        local item = list.items[i]
        if item then
          local v = proposed[item] or item.value
          counts[v] = (counts[v] or 0) + 1
        end
      end
      for _, u in ipairs(updates) do
        if counts[u.value] == 1 then
          u.item.value = u.value
          u.item.context.row = u.row
        end
      end
    end

    harpoon:setup({
      marks = {
        create_list_item = function(config, name)
          if name then
            -- re-created from a quick-menu line ("path:row")
            local path, row = parse(name)
            row = row or 1
            return { value = path .. ":" .. row, context = { row = row, col = 0 } }
          end
          local buf = vim.api.nvim_get_current_buf()
          local path = require("plenary.path")
            :new(vim.api.nvim_buf_get_name(buf))
            :make_relative(config.get_root_dir())
          local pos = vim.api.nvim_win_get_cursor(0)
          local item = {
            value = path .. ":" .. pos[1],
            context = { row = pos[1], col = pos[2] },
          }
          plant_extmark(item, buf, pos[1])
          return item
        end,

        select = function(item)
          if not item then
            return
          end
          local path, row = parse(item.value)
          row = extmark_row(item) or row or 1
          local col = item.context and item.context.col or 0

          -- switch to an already-loaded buffer; :edit only for fresh files
          -- (:edit on the current modified buffer would mean reload -> E37)
          local target
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(b)
              and buf_matches(vim.api.nvim_buf_get_name(b), path) then
              target = b
              break
            end
          end
          if target then
            if target ~= vim.api.nvim_get_current_buf() then
              vim.api.nvim_set_current_buf(target)
            end
          else
            vim.cmd.edit(vim.fn.fnameescape(path))
            target = vim.api.nvim_get_current_buf()
          end

          row = math.min(row, vim.api.nvim_buf_line_count(target))
          pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
          if not extmark_row(item) then
            plant_extmark(item, target, row)
          end
        end,

        -- Marks stay pinned: refresh from extmarks instead of harpoon's
        -- default "follow the last cursor position" behavior.
        BufLeave = function(arg, list)
          refresh_marks(list, arg.buf)
        end,

        VimLeavePre = function(_, list)
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) then
              refresh_marks(list, buf)
            end
          end
        end,
      },
    })

    -- Plant extmarks for saved marks when their file is opened.
    vim.api.nvim_create_autocmd("BufReadPost", {
      group = vim.api.nvim_create_augroup("CarlosHarpoonMarks", { clear = true }),
      callback = function(arg)
        local bufname = vim.api.nvim_buf_get_name(arg.buf)
        if bufname == "" then
          return
        end
        local list = harpoon:list("marks")
        for i = 1, list._length or 0 do
          local item = list.items[i]
          if item then
            local path, row = parse(item.value)
            if row and buf_matches(bufname, path) and not extmark_row(item) then
              plant_extmark(item, arg.buf, row)
            end
          end
        end
      end,
    })

    local keymap = vim.keymap

    -- Combined Telescope picker over both harpoon lists.
    -- [F] = file list entry, [M] = line mark; both carry filename+lnum,
    -- so <CR> opens the file at the right line either way.
    local conf = require("telescope.config").values
    local function collect_entries(harpoon_files, tag, entries)
      for i = 1, harpoon_files._length or #harpoon_files.items do
        local item = harpoon_files.items[i]
        if item then
          local path, row = parse(item.value)
          row = extmark_row(item) or row or (item.context and item.context.row) or 1
          table.insert(entries, {
            value = tag .. item.value,
            display = "[" .. tag .. "] " .. path .. ":" .. row,
            ordinal = tag .. " " .. item.value,
            filename = path,
            lnum = row,
          })
        end
      end
      return entries
    end

    local function toggle_telescope()
      local entries = collect_entries(harpoon:list(), "F", {})
      collect_entries(harpoon:list("marks"), "M", entries)

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
                filename = entry.filename,
                lnum = entry.lnum,
              }
            end,
          }),
          previewer = conf.grep_previewer({}),
          sorter = conf.generic_sorter({}),
        })
        :find()
    end

    -- ── Keymaps: one <leader>m group; lowercase = files, capital = line marks
    keymap.set("n", "<leader>mm", toggle_telescope,
      { desc = "Harpoon: Menu — files + line marks (Telescope)" })

    -- Files
    keymap.set("n", "<leader>ma", function()
      harpoon:list():add()
    end, { desc = "Harpoon: Add file" })

    -- Native Harpoon UI (use dd to delete marks, reorder lines, etc.)
    keymap.set("n", "<leader>me", function()
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end, { desc = "Harpoon: Edit files" })

    for i = 1, 4 do
      keymap.set("n", "<leader>" .. i, function()
        harpoon:list():select(i)
      end, { desc = "which_key_ignore" })
    end

    keymap.set("n", "<leader>mp", function()
      harpoon:list():prev()
    end, { desc = "Harpoon: Previous file" })

    keymap.set("n", "<leader>mn", function()
      harpoon:list():next()
    end, { desc = "Harpoon: Next file" })

    -- Line marks
    keymap.set("n", "<leader>ml", function()
      harpoon:list("marks"):add()
    end, { desc = "Harpoon: Add line mark" })

    keymap.set("n", "<leader>mE", function()
      harpoon.ui:toggle_quick_menu(harpoon:list("marks"))
    end, { desc = "Harpoon: Edit line marks" })

    for i = 1, 4 do
      keymap.set("n", "<leader>m" .. i, function()
        harpoon:list("marks"):select(i)
      end, { desc = "which_key_ignore" })
    end

    keymap.set("n", "<leader>mP", function()
      harpoon:list("marks"):prev()
    end, { desc = "Harpoon: Previous line mark" })

    keymap.set("n", "<leader>mN", function()
      harpoon:list("marks"):next()
    end, { desc = "Harpoon: Next line mark" })
  end,
}
