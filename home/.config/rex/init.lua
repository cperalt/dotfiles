-- Rex config, migrated from Herdr (~/.config/herdr/config.toml) and tmux (~/.tmux.conf).
-- Prefix is ctrl+a, as in both sources. Everything not listed here uses Rex's defaults.

-- Herdr: split_vertical = "prefix+|", split_horizontal = "prefix+minus"
rex.bind("ctrl+a>shift+\\", "pane.split", { direction = "right" })
rex.bind("ctrl+a>-", "pane.split", { direction = "down" })

-- Herdr: rename_tab = "prefix+comma"; defaults next_tab = "prefix+n", previous_tab = "prefix+p".
-- client.tab.next/previous walk every session's tabs in the sidebar, so these
-- cycle within the current session only (wrapping at the ends).
rex.bind("ctrl+a>,", "client.tab.rename")
-- The Mac app tracks its shown tab separately from the server's active window,
-- so after moving the server side we also tell the client which window to show.
local function cycle_tab(ctx, step)
  local v = rex.session.view{}
  local n = #v.windows
  if n < 2 then return end
  local cur = 1
  for i, w in ipairs(v.windows) do
    if w.window_id == v.active_window_id then cur = i end
  end
  local target = v.windows[((cur - 1 + step) % n) + 1].window_id
  rex.session.focus_window{ window_id = target }
  rex.client.queue("session.select", { session_id = ctx.session_id, window_id = target })
end
rex.action{ name = "tab_next", title = "Next Tab (this session)", category = "Tabs",
  run = function(ctx) cycle_tab(ctx, 1) end }
rex.action{ name = "tab_prev", title = "Previous Tab (this session)", category = "Tabs",
  run = function(ctx) cycle_tab(ctx, -1) end }
rex.bind("ctrl+a>n", "tab_next")
rex.bind("ctrl+a>p", "tab_prev")

-- Herdr default: prefix+b toggles the sidebar. cmd+/ (Rex default) still works too.
rex.bind("ctrl+a>b", "client.sidebar.toggle")
-- Fold every other session in the sidebar; the current one stays open.
rex.bind("ctrl+a>o", "session.collapse_others")

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
