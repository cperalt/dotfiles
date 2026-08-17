return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  dependencies = {
    "catppuccin/nvim",
  },
  config = function()
    local function getLen(str, start_pos)
      local byte = string.byte(str, start_pos)
      if not byte then
        return nil
      end

      return (byte < 0x80 and 1) or (byte < 0xE0 and 2) or (byte < 0xF0 and 3) or (byte < 0xF8 and 4) or 1
    end

    local function colorize(header, header_color_map, colors)
      for letter, color in pairs(colors) do
        local color_name = "AlphaHeaderColor" .. letter
        vim.api.nvim_set_hl(0, color_name, color)
        colors[letter] = color_name
      end

      local colorized = {}

      for i, line in ipairs(header_color_map) do
        local colorized_line = {}
        local pos = 0

        for j = 1, #line do
          local start = pos
          pos = pos + getLen(header[i], start + 1)

          local color_name = colors[line:sub(j, j)]
          if color_name then
            table.insert(colorized_line, { color_name, start, pos })
          end
        end

        table.insert(colorized, colorized_line)
      end

      return colorized
    end

    local alpha = require("alpha")
    local mocha = require("catppuccin.palettes").get_palette("mocha")
    local dashboard = require("alpha.themes.dashboard")

    local header = {
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ███████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ███████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
      [[ ██████████████████████████████████████████████████████████████████████████████████████████████████████ ]],
    }

    local color_map = {
      [[ WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWW ]],
      [[ RRRRWWWWWWWWWWWWWWWWRRRRRRRRRRRRRRRRWWWWWWWWWWWWWWWWBBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPBBWWWWWWWWWWWW ]],
      [[ RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRBBPPPPPPHHHHHHHHHHHHHHHHHHHHHHHHHHPPPPPPBBWWWWWWWWWW ]],
      [[ RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRBBPPPPHHHHHHHHHHHHFFHHHHFFHHHHHHHHHHPPPPBBWWWWWWWWWW ]],
      [[ OOOORRRRRRRRRRRRRRRROOOOOOOOOOOOOOOORRRRRRRRRRRRRRBBPPHHHHFFHHHHHHHHHHHHHHHHHHHHHHHHHHHHPPBBWWWWWWWWWW ]],
      [[ OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOBBPPHHHHHHHHHHHHHHHHHHHHBBBBHHHHFFHHHHPPBBWWBBBBWWWW ]],
      [[ OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOBBPPHHHHHHHHHHHHHHHHHHBBMMMMBBHHHHHHHHPPBBBBMMMMBBWW ]],
      [[ YYYYOOOOOOOOOOOOOOOOYYYYYYYYYYYYYYYYOOBBBBBBBBOOOOBBPPHHHHHHHHHHHHFFHHHHBBMMMMMMBBHHHHHHPPBBMMMMMMBBWW ]],
      [[ YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYBBMMMMBBBBOOBBPPHHHHHHHHHHHHHHHHHHBBMMMMMMMMBBBBBBBBMMMMMMMMBBWW ]],
      [[ YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYBBBBMMMMBBBBBBPPHHHHHHFFHHHHHHHHHHBBMMMMMMMMMMMMMMMMMMMMMMMMBBWW ]],
      [[ GGGGYYYYYYYYYYYYYYYYGGGGGGGGGGGGGGGGYYYYBBBBMMMMBBBBPPHHHHHHHHHHHHHHFFBBMMMMMMMMMMMMMMMMMMMMMMMMMMMMBB ]],
      [[ GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGBBBBMMMMBBPPHHFFHHHHHHHHHHHHBBMMMMMMCCBBMMMMMMMMMMCCBBMMMMBB ]],
      [[ GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGBBBBBBBBPPHHHHHHHHHHHHHHHHBBMMMMMMBBBBMMMMMMBBMMBBBBMMMMBB ]],
      [[ UUUUGGGGGGGGGGGGGGGGUUUUUUUUUUUUUUUUGGGGGGGGGGGGBBBBPPHHHHHHHHHHFFHHHHBBMMrrrrMMMMMMMMMMMMMMMMrrrrBB ]],
      [[ UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUBBPPPPHHFFHHHHHHHHHHBBMMrrrrMMBBMMMMBBMMMMBBMMrrrrBB ]],
      [[ UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUBBPPPPPPHHHHHHHHHHHHHHBBMMMMMMBBBBBBBBBBBBBBMMMMBBWW ]],
      [[ VVVVUUUUUUUUUUUUUUUUVVVVVVVVVVVVVVVVUUUUUUUUUUUUBBBBBBPPPPPPPPPPPPPPPPPPPPBBMMMMMMMMMMMMMMMMMMMMBBWWWW ]],
      [[ VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVBBMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBWWWWWW ]],
      [[ VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVBBMMMMBBBBWWBBMMMMBBWWWWWWWWWWBBMMMMBBWWBBMMMMBBWWWWWWWW ]],
      [[ WWWWVVVVVVVVVVVVVVVVWWWWWWWWWWWWWWWWVVVVVVVVVVBBBBBBBBWWWWBBBBBBWWWWWWWWWWWWWWBBBBBBWWWWBBBBWWWWWWWWWW ]],
    }

    local function alpha_colors()
      return {
        ["W"] = { fg = mocha.base },
        ["C"] = { fg = mocha.text },
        ["B"] = { fg = mocha.crust },
        ["R"] = { fg = mocha.red },
        ["O"] = { fg = mocha.peach },
        ["Y"] = { fg = mocha.yellow },
        ["G"] = { fg = mocha.green },
        ["U"] = { fg = mocha.blue },
        ["P"] = { fg = mocha.yellow },
        ["H"] = { fg = mocha.pink },
        ["F"] = { fg = mocha.red },
        ["M"] = { fg = mocha.overlay0 },
        ["V"] = { fg = mocha.lavender },
        ["r"] = { fg = mocha.red },
        ["c"] = { fg = mocha.text },
      }
    end

    local function sample_line(line, step)
      local out = {}
      local chars = vim.fn.strchars(line)

      for i = 0, chars - 1, step do
        out[#out + 1] = vim.fn.strcharpart(line, i, 1)
      end

      return table.concat(out)
    end

    local function compact_lines(lines, step, keep_every)
      local out = {}
      for i, line in ipairs(lines) do
        if (i - 1) % keep_every == 0 then
          out[#out + 1] = sample_line(line, step)
        end
      end
      return out
    end

    local function apply_responsive_header()
      local width = vim.o.columns
      local active_header = header
      local active_color_map = color_map

      if width < 100 then
        active_header = compact_lines(header, 2, 2)
        active_color_map = compact_lines(color_map, 2, 2)
      end

      dashboard.section.header.val = active_header
      dashboard.section.header.opts = {
        hl = colorize(active_header, active_color_map, alpha_colors()),
        position = "center",
      }
    end

    apply_responsive_header()

    -- stylua: ignore
    dashboard.section.buttons.val = {
      dashboard.button("e", "📄 > New File", "<cmd>ene<CR>"),
      dashboard.button("SPC ee", "📁 > Toggle file explorer", "<cmd>lua require('mini.files').open(vim.fn.getcwd(), true)<CR>"),
      dashboard.button("SPC ff", "󰱼 > Find File", "<cmd>Telescope find_files<CR>"),
      dashboard.button("SPC fs", "🔍 > Find Word", "<cmd>Telescope live_grep<CR>"),
      dashboard.button("SPC wr", "󰁯  > Restore Session For Current Directory", "<cmd>SessionRestore<CR>"),
      dashboard.button("q", "🚪 > Quit NVIM", "<cmd>qa<CR>"),
    }

    for _, button in ipairs(dashboard.section.buttons.val) do
      button.opts.hl = "AlphaButtons"
      button.opts.hl_shortcut = "AlphaShortcut"
    end
    dashboard.section.buttons.opts.hl = "AlphaButtons"
    dashboard.section.footer.opts.hl = "AlphaFooter"

    -- close Lazy and re-open when the dashboard is ready
    if vim.o.filetype == "lazy" then
      vim.cmd.close()
      vim.api.nvim_create_autocmd("User", {
        once = true,
        pattern = "AlphaReady",
        callback = function()
          require("lazy").show()
        end,
      })
    end

    alpha.setup(dashboard.opts)

    vim.api.nvim_create_autocmd("VimResized", {
      callback = function()
        apply_responsive_header()
        if vim.bo.filetype == "alpha" then
          pcall(vim.cmd.AlphaRedraw)
        end
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      once = true,
      pattern = "AlphaReady",
      callback = function()
        apply_responsive_header()
        pcall(vim.cmd.AlphaRedraw)
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      once = true,
      pattern = "LazyVimStarted",
      callback = function()
        local stats = require("lazy").stats()
        local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)

        dashboard.section.footer.val = "⚡ Neovim loaded "
          .. stats.loaded
          .. "/"
          .. stats.count
          .. " plugins in "
          .. ms
          .. "ms"
        pcall(vim.cmd.AlphaRedraw)
      end,
    })

    -- Disable folding on alpha buffer
    vim.cmd([[autocmd FileType alpha setlocal nofoldenable]])
  end,
}
