# Custom extensions archived before the upstream reset

These files are preserved for selectively restoring custom behavior later. This
archive is outside `extensions/` and is not configured as a package or extension
path, so Pi does not load it.

- `modal-editor.ts` + `vim/`: expanded Vim motions, operators, counts, clipboard.
- `built-in-tool-renderer.ts` + `tool-display-vendored/`: compact headers and custom diffs.
- `status-line.ts`: custom footer replacement.
- `questionnaire.ts`: Vim navigation and customized rendering.

The active files with these names were replaced with unmodified upstream examples.
Do not load archived and active versions simultaneously. Archived imports/APIs may
need migration before reuse.
