# Upstream Pi examples

The following files are unmodified copies from:
https://github.com/earendil-works/pi/tree/085c84e98e7f4c950f2be606466fff4f75d8fe7c/packages/coding-agent/examples/extensions

- built-in-tool-renderer.ts
- modal-editor.ts
- permission-gate.ts
- protected-paths.ts
- questionnaire.ts
- status-line.ts

They also match the examples bundled with the installed Pi 1.5.0 release.
These are vendored snapshots, not automatically updated packages. When refreshing,
compare against examples bundled with the installed Pi release first; copy the
selected files unchanged and update this reference. Avoid mixing latest-main APIs
with an older installed Pi release.

Personalized predecessors and helper modules are preserved under
`../archive/pre-upstream-reset/`, outside extension auto-discovery.
`session-name.ts` was removed in favor of Pi's built-in `/name` command.

Other extensions in this directory remain locally maintained and were not changed
by this reset.
