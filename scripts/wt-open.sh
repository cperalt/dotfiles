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

# These are specific to my workflow, change prefix as desired
WT_NAME="$(basename "$WORKTREE_PATH")"
SESSION="mpos-${WT_NAME}"

# Get current session name (empty if not in tmux)
CURRENT_SESSION=""
if [ -n "${TMUX:-}" ]; then
  CURRENT_SESSION="$(tmux display-message -p '#S')"
fi

# Commands below are to make sure process are terminated before switching to new
# session, was running into high cpu load consumption by servers running in
# previos tmxu tree session, would not terminate,

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

# Stop Docker containers for a given worktree path
stop_docker() {
  local wt_path="$1"
  if [ -n "$wt_path" ] && [ -f "$wt_path/docker-compose.yml" ]; then
    echo "Stopping Docker containers from $wt_path..."
    (cd "$wt_path" && docker-compose down --rmi all --volumes 2>/dev/null) || true
  fi
}

# Create Servers window with 6 panes (3x2 grid) in the given session
start_servers() {
  local sess="$1"
  local wt="$2"

  tmux new-window -t "$sess" -n "Servers" -c "$wt"

  local commands=(
    "npm run start:admin-ui"
    "npm run start:admin-api"
  )

  # Pane 0 already exists, send first command
  tmux send-keys -t "$sess:Servers.0" "${commands[0]}" Enter

  # Create panes 1-5
  for i in 1 2 3 4 5; do
    tmux split-window -t "$sess:Servers" -c "$wt"
    tmux send-keys -t "$sess:Servers.$i" "${commands[$i]}" Enter
    tmux select-layout -t "$sess:Servers" tiled
  done
}

# --- Teardown current session's servers and docker (free ports/CPU) ---
if [ -n "$CURRENT_SESSION" ] && [[ "$CURRENT_SESSION" == mpos-* ]]; then
  kill_servers "$CURRENT_SESSION"
  CURRENT_WT="$(tmux display-message -t "$CURRENT_SESSION" -p '#{pane_current_path}' 2>/dev/null)" || true
  stop_docker "$CURRENT_WT"
fi

# --- First time setup for a new worktree ---

# Resolve the main worktree path (first listed worktree)
MAIN_WT="$(git worktree list --porcelain | awk '/^worktree / { print substr($0, 10); exit }')"

# Copy migrations-index from main so esbuild can resolve the import in dev mode
if [ -f "$MAIN_WT/db/migrations-index.ts" ] && [ ! -f "$WORKTREE_PATH/db/migrations-index.ts" ]; then
  echo "Copying db/migrations-index.ts from main worktree..."
  cp "$MAIN_WT/db/migrations-index.ts" "$WORKTREE_PATH/db/migrations-index.ts"
fi

# Symlink .claude dir to main worktree so settings/skills stay in sync
if [ -d "$MAIN_WT/.claude" ] && [ ! -e "$WORKTREE_PATH/.claude" ]; then
  echo "Symlinking .claude/ to main worktree..."
  ln -s "$MAIN_WT/.claude" "$WORKTREE_PATH/.claude"
fi

# Run npm install if node_modules is missing
if [ ! -d "$WORKTREE_PATH/node_modules" ]; then
  echo "node_modules not found — running npm install..."
  (cd "$WORKTREE_PATH" && npm install)
  echo "npm install complete."
  echo "Warming up Nx Daemon (building project graph)..."
  (cd "$WORKTREE_PATH" && npx nx reset 2>/dev/null; npx nx show projects > /dev/null 2>&1)
  echo "Nx Daemon ready."
fi

# Create new session with lazygit window
tmux new-session -d -s "$SESSION" -c "$WORKTREE_PATH" -n "lazygit"
tmux send-keys -t "$SESSION:lazygit" "lazygit" Enter

# Create Servers window and start all dev servers
start_servers "$SESSION" "$WORKTREE_PATH"

# Select lazygit window
tmux select-window -t "$SESSION:lazygit"

# Switch to the new session (keep the old session alive)
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach-session -t "$SESSION"
fi
