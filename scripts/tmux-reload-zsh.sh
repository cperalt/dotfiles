#!/bin/bash
for pane in $(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}'); do
  tmux send-keys -t "$pane" 'source ~/.zshrc' Enter
done
