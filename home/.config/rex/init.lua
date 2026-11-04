-- Rex config, migrated from Herdr (~/.config/herdr/config.toml) and tmux (~/.tmux.conf).
-- Prefix is ctrl+a, as in both sources. Everything not listed here uses Rex's defaults.

-- Herdr: split_vertical = "prefix+|", split_horizontal = "prefix+minus"
rex.bind("ctrl+a>shift+\\", "pane.split", { direction = "right" })
rex.bind("ctrl+a>-", "pane.split", { direction = "down" })

-- Herdr: rename_tab = "prefix+comma"; defaults next_tab = "prefix+n", previous_tab = "prefix+p"
rex.bind("ctrl+a>,", "client.tab.rename")
rex.bind("ctrl+a>n", "client.tab.next")
rex.bind("ctrl+a>p", "client.tab.previous")

-- Herdr default: prefix+b toggles the sidebar. cmd+/ (Rex default) still works too.
rex.bind("ctrl+a>b", "client.sidebar.toggle")

-- Herdr: zoom = "prefix+m" (maximize / restore the focused pane)
rex.bind("ctrl+a>m", "pane.zoom")

-- Herdr: vim-herdr-navigation on ctrl+h/j/k/l.
-- ctrl+h/j/k/l focus the neighbouring pane, unless the focused terminal is running
-- one of the programs below, which then receives the key itself (nvim moves between
-- its own splits; fzf uses ctrl+j/k to move the cursor).
local passthrough = { nvim = true, vim = true, vi = true, fzf = true }
local vim_key = { left = "ctrl+h", down = "ctrl+j", up = "ctrl+k", right = "ctrl+l" }

rex.action{
  name = "vim_focus",
  title = "Focus Pane (vim-aware)",
  category = "Panes",
  args = { direction = "string" },
  run = function(ctx, args)
    local p = rex.block.call("com.superlogical.terminal", "process", {})
    local fg = p and p.foreground
    if fg and passthrough[fg.name] then
      rex.client.queue("pane.send_key", { key = vim_key[args.direction] })
    else
      rex.client.queue("pane.focus", { direction = args.direction })
    end
  end,
}

rex.bind("ctrl+h", "vim_focus", { direction = "left" })
rex.bind("ctrl+j", "vim_focus", { direction = "down" })
rex.bind("ctrl+k", "vim_focus", { direction = "up" })
rex.bind("ctrl+l", "vim_focus", { direction = "right" })
