#!/usr/bin/env bash
set -euo pipefail

INPUT="$1"

# If the argument is a directory, use it directly; otherwise treat it as a branch name
if [ -d "$INPUT" ]; then
  WORKTREE_PATH="$INPUT"
else
  WORKTREE_PATH="$(git worktree list --porcelain | awk -v branch="$INPUT" '
    /^worktree / { wt = substr($0, 10) }
    /^branch refs\/heads\// {
      b = substr($0, 19)
      if (b == branch) { print wt; exit }
    }
  ')"
  if [ -z "$WORKTREE_PATH" ]; then
    echo "Error: no worktree found for branch '$INPUT'"
    exit 1
  fi
fi

WT_NAME="$(basename "$WORKTREE_PATH")"
SESSION="mpos-${WT_NAME}"

# Get current session name (empty if not in tmux)
CURRENT_SESSION=""
if [ -n "${TMUX:-}" ]; then
  CURRENT_SESSION="$(tmux display-message -p '#S')"
fi

# Recursively collect all descendant PIDs of a given PID
get_descendants() {
  local parent="$1"
  local children
  children="$(pgrep -P "$parent" 2>/dev/null)" || true
  for child in $children; do
    echo "$child"
    get_descendants "$child"
  done
}

# Kill the full process tree for every pane in a tmux session's Servers window
kill_servers() {
  local sess="$1"
  local pane_pids
  pane_pids="$(tmux list-panes -t "$sess:Servers" -F '#{pane_pid}' 2>/dev/null)" || return 0

  # Collect all descendant PIDs first (bottom-up order for clean teardown)
  local all_pids=()
  for pid in $pane_pids; do
    while IFS= read -r dpid; do
      all_pids+=("$dpid")
    done <<< "$(get_descendants "$pid")"
    all_pids+=("$pid")
  done

  # SIGTERM everything, then wait, then SIGKILL survivors
  for p in "${all_pids[@]}"; do
    kill -TERM "$p" 2>/dev/null || true
  done
  sleep 1
  for p in "${all_pids[@]}"; do
    kill -KILL "$p" 2>/dev/null || true
  done

  tmux kill-window -t "$sess:Servers" 2>/dev/null || true
}

# Kill all other mpos-* sessions (kill their servers first, then the session)
for s in $(tmux list-sessions -F '#S' 2>/dev/null | grep '^mpos-' || true); do
  if [ "$s" != "$CURRENT_SESSION" ]; then
    kill_servers "$s"
    tmux kill-session -t "$s" 2>/dev/null || true
  fi
done

# Kill Servers window in current session (stop servers before starting new ones)
if [ -n "$CURRENT_SESSION" ] && [[ "$CURRENT_SESSION" == mpos-* ]]; then
  kill_servers "$CURRENT_SESSION"
fi

# Run npm install if node_modules is missing
if [ ! -d "$WORKTREE_PATH/node_modules" ]; then
  echo "node_modules not found — running npm install..."
  (cd "$WORKTREE_PATH" && npm install)
  echo "npm install complete."
fi

# Create new session with lazygit window
tmux new-session -d -s "$SESSION" -c "$WORKTREE_PATH" -n "lazygit"
tmux send-keys -t "$SESSION:lazygit" "lazygit" Enter

# Create Servers window with 6 panes (3x2 grid)
tmux new-window -t "$SESSION" -n "Servers" -c "$WORKTREE_PATH"

COMMANDS=(
  "npm run start:admin-ui"
  "npm run start:admin-api"
  "npm run start:borrower-portal-ui"
  "npm run start:borrower-portal-api"
  "npm run start:api"
  "npm run start:ui"
)

# Pane 0 already exists, send first command
tmux send-keys -t "$SESSION:Servers.0" "${COMMANDS[0]}" Enter

# Create panes 1-5
for i in 1 2 3 4 5; do
  tmux split-window -t "$SESSION:Servers" -c "$WORKTREE_PATH"
  tmux send-keys -t "$SESSION:Servers.$i" "${COMMANDS[$i]}" Enter
  tmux select-layout -t "$SESSION:Servers" tiled
done

# Open Cursor IDE at the worktree
/Applications/Cursor.app/Contents/Resources/app/bin/cursor "$WORKTREE_PATH"

# Select lazygit window
tmux select-window -t "$SESSION:lazygit"

# Switch to the new session, then kill the old one
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$SESSION"
  # Kill the old session now that we've switched away
  if [ -n "$CURRENT_SESSION" ] && [ "$CURRENT_SESSION" != "$SESSION" ] && [[ "$CURRENT_SESSION" == mpos-* ]]; then
    tmux kill-session -t "$CURRENT_SESSION" 2>/dev/null || true
  fi
else
  tmux attach-session -t "$SESSION"
fi
