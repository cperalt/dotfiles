-- <C-h/j/k/l> crosses Neovim splits and the surrounding multiplexer as one app.
-- Inside herdr, hand off to `herdr pane focus` (vim-herdr-navigation, the herdr
-- port of vim-tmux-navigator); otherwise fall back to nvim-tmux-navigation.
-- The herdr keybinds live in herdr/.config/herdr/config.toml.
return {
  "alexghergh/nvim-tmux-navigation",
  config = function()
    local nav = require("nvim-tmux-navigation")
    nav.setup({ disable_when_zoomed = true })

    local function in_herdr()
      return vim.env.HERDR_PANE_ID ~= nil and vim.env.HERDR_PANE_ID ~= ""
    end

    -- Move within Neovim first; only cross into a herdr pane at a split edge.
    local function herdr_nav(wincmd, direction)
      local from = vim.api.nvim_get_current_win()
      vim.cmd("wincmd " .. wincmd)
      if vim.api.nvim_get_current_win() ~= from then
        return
      end
      local herdr = vim.env.HERDR_BIN_PATH
      if herdr == nil or herdr == "" then
        herdr = "herdr"
      end
      -- Use `--current` (server-side focused pane), NOT `--pane $HERDR_PANE_ID`:
      -- the env var is a launch-time snapshot and herdr reassigns pane ids when
      -- a pane is moved between tabs/workspaces, so it rots under long-lived
      -- nvim instances. `--current` is always right here — these chords only
      -- reach nvim because its pane is the focused one (vim-herdr-navigation
      -- forwards to the focused pane).
      vim.fn.system({ herdr, "pane", "focus", "--direction", direction, "--current" })
    end

    local directions = {
      { key = "<C-h>", wincmd = "h", direction = "left", tmux = nav.NvimTmuxNavigateLeft },
      { key = "<C-j>", wincmd = "j", direction = "down", tmux = nav.NvimTmuxNavigateDown },
      { key = "<C-k>", wincmd = "k", direction = "up", tmux = nav.NvimTmuxNavigateUp },
      { key = "<C-l>", wincmd = "l", direction = "right", tmux = nav.NvimTmuxNavigateRight },
    }

    for _, d in ipairs(directions) do
      vim.keymap.set({ "n", "v", "x" }, d.key, function()
        if in_herdr() then
          herdr_nav(d.wincmd, d.direction)
        else
          d.tmux()
        end
      end, { silent = true, desc = "Navigate " .. d.direction .. " (vim/herdr/tmux)" })
    end
  end,
}
