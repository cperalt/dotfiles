#!/usr/bin/env bash
# Outputs a numbered pill per pane, styled like catppuccin window tabs.
# Usage: tmux-pane-status.sh <window_id>

WINDOW_ID="$1"

tmux list-panes -t "$WINDOW_ID" -F '#{pane_active}' 2>/dev/null | while read -r active; do
    if [ "$active" = "1" ]; then
        printf '#[fg=#cba6f7]⬤  '
    else
        printf '#[fg=#6c7086]⬤  '
    fi
done
