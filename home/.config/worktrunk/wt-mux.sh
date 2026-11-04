#!/usr/bin/env bash
# Multiplexer glue for the worktrunk hooks in config.toml.
#
#   wt-mux.sh ensure LABEL PATH [review]   create the space for a worktree if missing
#   wt-mux.sh focus  LABEL                 switch to it
#   wt-mux.sh run    LABEL COMMAND...      run COMMAND in its last pane
#   wt-mux.sh close  LABEL                 close it everywhere it exists
#
# A "space" is a Rex session or a Herdr workspace. `ensure`, `focus` and `run`
# act on the multiplexer the hook runs inside (Rex sets REX_SESSION, Herdr sets
# HERDR_ENV); outside both, on whichever server answers, Rex first. `close`
# always tries both so cleanup works no matter where it runs from.
set -euo pipefail

cmd=${1:?usage: wt-mux.sh ensure|focus|run|close LABEL ...}
label=${2:?label required}
shift 2

# Never start a Rex server from a hook; only talk to one that is running.
rex() { command rex --autostart=false "$@"; }

rex_up() { rex ls >/dev/null 2>&1; }
herdr_up() { herdr workspace list >/dev/null 2>&1; }

detect() {
  if [ -n "${REX_SESSION:-}" ]; then echo rex
  elif [ -n "${HERDR_ENV:-}" ]; then echo herdr
  elif rex_up; then echo rex
  elif herdr_up; then echo herdr
  else echo none
  fi
}

rex_session_id() {
  rex ls --json | jq -r --arg l "$label" '.sessions[] | select(.label==$l) | .session_id' | head -1
}

herdr_workspace_id() {
  herdr workspace list | jq -r --arg l "$label" '.result.workspaces[] | select(.label==$l) | .workspace_id' | head -1
}

ensure_rex() {
  local path=$1 review=${2:-}
  [ -n "$(rex_session_id)" ] && return 0
  rex session new "$label" -c "$path" >/dev/null
  if [ -n "$review" ]; then
    # 25/75 split plus a small bottom pane for deps (the old tmux review layout)
    local p0 p1
    p0=$(rex block ls -s "$label" --json | jq -r '.blocks[0].block_id')
    p1=$(rex split -s "$label" -b "$p0" --split right --ratio 75 -c "$path" --focus=false --json | jq -r '.block_ids[0]')
    rex split -s "$label" -b "$p1" --split below --ratio 20 -c "$path" --focus=false >/dev/null
  fi
}

ensure_herdr() {
  local path=$1 review=${2:-}
  [ -n "$(herdr_workspace_id)" ] && return 0
  local ws p0 p1
  ws=$(herdr workspace create --cwd "$path" --label "$label" --no-focus | jq -r '.result.workspace.workspace_id')
  if [ -n "$review" ]; then
    p0=$(herdr pane list --workspace "$ws" | jq -r '.result.panes[0].pane_id')
    p1=$(herdr pane split --pane "$p0" --direction right --ratio 0.75 --cwd "$path" --no-focus | jq -r '.result.pane.pane_id')
    herdr pane split --pane "$p1" --direction down --ratio 0.2 --cwd "$path" --no-focus >/dev/null
  fi
}

case "$cmd" in
  ensure)
    path=${1:?path required}; review=${2:-}
    case "$(detect)" in
      rex) ensure_rex "$path" "$review" ;;
      herdr) ensure_herdr "$path" "$review" ;;
      none) echo "wt-mux: no Rex or Herdr server running; skipping space creation" >&2 ;;
    esac
    ;;
  focus)
    case "$(detect)" in
      rex)
        id=$(rex_session_id)
        [ -n "$id" ] || exit 0
        rex do session.select session_id="$id" >/dev/null
        rex do session.collapse_others session_id="$id" >/dev/null
        ;;
      herdr) ws=$(herdr_workspace_id); [ -n "$ws" ] && herdr workspace focus "$ws" >/dev/null ;;
    esac
    ;;
  run)
    [ $# -gt 0 ] || { echo "wt-mux run: command required" >&2; exit 2; }
    case "$(detect)" in
      rex)
        blk=$(rex block ls -s "$label" --json | jq -r '.blocks[-1].block_id')
        [ -n "$blk" ] && rex send -s "$label" -b "$blk" "$*" && rex send-key -s "$label" -b "$blk" enter
        ;;
      herdr)
        ws=$(herdr_workspace_id)
        pane=$(herdr pane list --workspace "$ws" | jq -r '.result.panes[-1].pane_id')
        [ -n "$pane" ] && herdr pane run "$pane" "$@"
        ;;
    esac
    ;;
  close)
    # Closing tears down the panes, which SIGHUPs anything still running in them.
    if rex_up; then
      id=$(rex_session_id); [ -n "$id" ] && rex session kill "$id" >/dev/null || true
    fi
    if herdr_up; then
      ws=$(herdr_workspace_id); [ -n "$ws" ] && herdr workspace close "$ws" >/dev/null || true
    fi
    ;;
  *)
    echo "wt-mux: unknown command '$cmd'" >&2; exit 2 ;;
esac
