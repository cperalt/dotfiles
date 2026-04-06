---
description: Execute an implementation plan task-by-task with subagent reviews
subagent: task-orchestrator
inheritContext: true
---
Execute this implementation plan.

Plan input: $@

Requirements:
- Read the plan first.
- Execute one task at a time using `task-implementer`.
- Require `spec-reviewer` approval before `code-reviewer`.
- Do not move to the next task until the current one is approved.
- Create clean task-scoped commits for implementation changes.
- Do not commit generated docs.
- End with a `final-reviewer` pass.
