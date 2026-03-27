#!/bin/bash
# Receives tmux copy-mode selection via stdin, writes to a temp file,
# then sends :ClaudeCodeAdd to the neovim pane in the current window.

cat > /tmp/tmux-claude-context.txt

NVIM_PANE=$(tmux list-panes -F '#{pane_index}:#{pane_current_command}' | grep -i nvim | cut -d: -f1 | head -1)

if [ -n "$NVIM_PANE" ]; then
  tmux send-keys -t "$NVIM_PANE" ":ClaudeCodeAdd /tmp/tmux-claude-context.txt" Enter
fi
