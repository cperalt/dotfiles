# tmux copy-mode crash — context & fix

**Status: FIXED (2026-07-26), then REVERTED to brew (2026-08-17)** — see update at bottom.
Feed this file to any AI agent session working on the tmux crash.

## Symptom
tmux server aborts with `SIGABRT` / `pointer being freed was not allocated` in
`grid_free_line`, when **entering copy-mode** in a long-running session (hours→days).
Backtrace: `cmd_copy_mode_exec → window_pane_set_mode → window_copy_init →
window_copy_clone_screen → screen_reinit → grid_clear_lines → grid_free_line`.
Crash reports land in `~/Library/Logs/DiagnosticReports/tmux-*.ips`. It's **tmux**, not
Ghostty (Ghostty only shows up as the host/`responsibleProc`).

## Root cause
macOS libmalloc bug on **Apple Silicon / macOS 26 (Tahoe)**: large `calloc` allocations
come back **not zeroed** (hold freed memory). tmux's `grid_create` trusts `xcalloc`
zeroing; copy-mode clones the screen, hits garbage line pointers, and `free()`s them →
double-free. Only macOS 26/arm64; macOS 15 never reproduces. Not a tmux logic bug.
Upstream issues: #4777, #5267, #5385 (open, may be filed with Apple).

## The fix (what actually works)
Build tmux **linked against jemalloc** (sidesteps the broken system allocator).
Confirmed by upstream A/B test: stock malloc crashed 6×, jemalloc 0×.
- The `memset` patch (`grid_trim_history`, commit `035a2f35`) is only PARTIAL — still crashes. Don't rely on it.
- No Homebrew path works: `brew install tmux` (stable 3.7b) and `brew install --HEAD tmux`
  (master) both build **without jemalloc** (formula has no jemalloc dep). Both still crash.
- `--HEAD` == master; switching "HEAD vs master" changes nothing.

## Current install (this machine) — superseded 2026-08-17, see update below
- Binary: `~/.local/bin/tmux` = `tmux 3.7c`, jemalloc-linked. Wins in PATH over `/opt/homebrew/bin` (#6 vs #24).
- Source: `~/src/tmux-3.7c`, git branch `release_3.7c` (= stable 3.7b + jemalloc).
- jemalloc from Homebrew (`brew install jemalloc`, 5.3.0).
- Old brew kegs (`3.6b`, `HEAD-…`) left in place, shadowed, as fallback.

## Verify
```sh
tmux display -p '#{version}'                    # -> 3.7c
otool -L "$(command -v tmux)" | grep jemalloc   # -> libjemalloc.2.dylib
find ~/Library/Logs/DiagnosticReports -name 'tmux-*.ips' -newermt 'YYYY-MM-DD'  # new crashes?
```
After changing the binary you MUST restart the server for it to take effect
(tmux is client/server): save state `C-a C-s`, `tmux kill-server`, then `tmux`
(continuum `@continuum-restore on` auto-restores sessions).

## Update / revert
- Update:  `cd ~/src/tmux-3.7c && git pull && make && make install`, then restart server.
- Revert:  `rm ~/.local/bin/tmux` (brew binary takes over again).
- Rebuild from scratch: need `brew install jemalloc autoconf automake libtool pkgconf`, then
  in the source dir: `sh autogen.sh && ./configure --prefix="$HOME/.local" --enable-utf8proc && make && make install`
  (configure must print `jemalloc: <version>`, not `off`).

## Open items / future
- Watch for a real Homebrew tmux that links jemalloc (a tagged `3.7c` release, or the
  formula gaining a jemalloc dep). When that lands: `rm ~/.local/bin/tmux` + `brew install tmux`.
- Aggravating factor in this setup: `@resurrect-capture-pane-contents on` + large
  `history-limit` (restore-heavy workload feeds the trigger). jemalloc fixes it regardless.

## Update 2026-08-17 — reverted to brew-managed tmux
- Moved daily driving to **herdr**; tmux no longer in active use, so crash exposure is moot.
- `brew upgrade` of the old `--HEAD` keg started **failing at configure**: tmux master now
  *requires* an explicit `--enable-jemalloc`/`--disable-jemalloc` on macOS (upstream added a
  mandatory check for this very calloc bug), and the Homebrew formula passes neither.
  Every HEAD rebuild fails until the formula catches up.
- Reverted per the plan above: `rm ~/.local/bin/tmux`, `brew uninstall tmux` (HEAD keg),
  `brew install tmux` → bottled **3.7b**, old 3.6b keg cleaned up.
- Now: `command -v tmux` → `/opt/homebrew/bin/tmux`, `tmux -V` → 3.7b, **no jemalloc** —
  i.e. the copy-mode crash is NOT fixed in this install. If tmux becomes a daily driver
  again on macOS 26/arm64, rebuild the jemalloc binary (source still at `~/src/tmux-3.7c`,
  instructions in "Update / revert" above) or wait for a jemalloc-linked brew formula.
