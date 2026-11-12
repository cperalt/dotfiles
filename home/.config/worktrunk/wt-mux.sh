#!/usr/bin/env bash
# Rex glue for the worktrunk hooks in config.toml. A worktree's "space" is a
# Rex session labelled after it.
#
#   wt-mux.sh ensure LABEL PATH [review]       create the session if missing
#   wt-mux.sh focus  LABEL                     show it on the client
#   wt-mux.sh run    LABEL first|last CMD...   type CMD into its first or last block
#   wt-mux.sh close  LABEL                     kill it
#
# A missing Rex server or session is not an error: hooks skip quietly.
set -euo pipefail

cmd=${1:?usage: wt-mux.sh ensure|focus|run|close LABEL ...}
label=${2:?label required}
shift 2

# Never start a Rex server from a hook; only talk to one that is running.
rex() { command rex --autostart=false "$@"; }

if ! rex ls >/dev/null 2>&1; then
  [ "$cmd" = ensure ] && echo "wt-mux: no Rex server running; skipping session creation" >&2
  exit 0
fi

session_id=$(rex ls --json | jq -r --arg l "$label" '.sessions[] | select(.label==$l) | .session_id' | head -1)

case "$cmd" in
  ensure)
    path=${1:?path required}; review=${2:-}
    [ -n "$session_id" ] && exit 0
    rex session new "$label" -c "$path" >/dev/null
    if [ -n "$review" ]; then
      # 25/75 split plus a small bottom block for deps
      b0=$(rex block ls -s "$label" --json | jq -r '.blocks[0].block_id')
      b1=$(rex split -s "$label" -b "$b0" --split right --ratio 75 -c "$path" --focus=false --json | jq -r '.block_ids[0]')
      rex split -s "$label" -b "$b1" --split below --ratio 20 -c "$path" --focus=false >/dev/null
    fi
    ;;
  focus)
    [ -n "$session_id" ] || exit 0
    rex do session.select session_id="$session_id" >/dev/null
    rex do session.collapse_others session_id="$session_id" >/dev/null
    ;;
  run)
    which=${1:?first|last required}; shift
    [ $# -gt 0 ] || { echo "wt-mux run: command required" >&2; exit 2; }
    [ -n "$session_id" ] || exit 0
    case "$which" in
      first) idx=0 ;;
      last) idx=-1 ;;
      *) echo "wt-mux run: expected first or last, got '$which'" >&2; exit 2 ;;
    esac
    # Blocks list in creation order, so first is the main block and last the
    # newest split (the deps block in the review layout).
    blk=$(rex block ls -s "$label" --json | jq -r --argjson i "$idx" '.blocks[$i].block_id // empty')
    [ -n "$blk" ] || exit 0
    rex send -s "$label" -b "$blk" "$*"
    rex send-key -s "$label" -b "$blk" enter
    ;;
  close)
    # Killing the session tears down its blocks, which SIGHUPs anything still
    # running in them.
    [ -n "$session_id" ] || exit 0
    rex session kill "$session_id" >/dev/null
    ;;
  *)
    echo "wt-mux: unknown command '$cmd'" >&2; exit 2 ;;
esac
