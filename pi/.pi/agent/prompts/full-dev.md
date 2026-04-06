---
description: Run the full feature workflow from brainstorming through implementation
---
Start the full feature workflow in the current session.

User request: $@

Workflow requirements:
- Phase 1: brainstorm interactively, produce an approved written spec, and do not implement yet.
- Phase 2: once the written spec is approved, create an implementation plan in the current session.
- Phase 3: once the plan is ready and the user approves continuing, invoke the `task-orchestrator` subagent to execute the implementation plan task-by-task.
- During implementation, require `spec-reviewer` approval before `code-reviewer`, and finish with `final-reviewer`.
- Do not commit generated docs.
- Do create clean task-scoped commits for implementation changes.
- Stop and ask for approval at the design and written-spec stages, and before moving from planning into implementation.
