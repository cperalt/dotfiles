---
description: Run the full continuous dev workflow from brainstorming through implementation
---
Run the full development workflow as one continuous flow in the current session.

User request: $@

This command is the canonical workflow. Do not treat brainstorming, planning, plan review, and implementation as separate optional flows. Drive the whole process from start to finish unless the user explicitly stops or changes direction.

## Required workflow

### Phase 1 — Brainstorm in-session
You must:
- inspect repository context first
- for broad repository discovery, use `semantic_search` before guessing keywords or file paths, then verify important details with targeted reads
- ask clarifying questions one at a time
- identify constraints and success criteria
- propose 2-3 approaches with trade-offs and a recommendation
- present the design clearly in sections
- get explicit design approval before proceeding
- do not implement code during this phase

### Phase 2 — Write and approve the spec
After the design is approved, you must:
- write the spec to `.pi/specs/YYYY-MM-DD-<topic>.md`
- review the written spec for ambiguity, contradictions, placeholders, and overscope
- ask the user to approve the written spec
- revise the spec if needed until approved
- do not commit generated docs

### Phase 3 — Plan in-session
After the written spec is approved, you must:
- use `semantic_search` for broad architecture or dependency discovery when planning touches unclear areas, then verify concrete details with file reads
- create an implementation plan in the current session
- write it to `.pi/plans/YYYY-MM-DD-<topic>.md`
- break work into small, reviewable, commit-sized tasks
- include verification expectations and commit intent per task
- do not implement code during this phase
- do not commit generated docs

### Phase 4 — Mandatory plan review
After writing the plan, you must invoke the `plan-reviewer` subagent.

The `plan-reviewer` must review the plan for:
- missing spec coverage
- tasks that are too large
- vague or non-actionable tasks
- poor ordering or missing dependencies
- missing verification expectations
- weak or unclear commit boundaries

If `plan-reviewer` finds issues:
- revise the plan in the current session
- re-run `plan-reviewer`
- repeat until the plan is approved

### Phase 5 — Approval before coding
Once the plan is approved, you must:
- show the approved plan path
- summarize the task structure briefly
- ask the user whether to proceed into implementation
- only continue after explicit approval

### Phase 6 — Implementation via subagents
After implementation approval, you must invoke the `task-orchestrator` subagent.

The implementation flow must be:
- `task-orchestrator` executes one task at a time
- `task-implementer` implements the current task
- `spec-reviewer` must approve before `code-reviewer` runs
- if either reviewer finds issues, the task goes back for fixes
- do not move to the next task until the current task is approved
- create clean task-scoped commits for implementation changes
- do not commit generated docs

### Phase 7 — Final review
After all tasks are complete, you must ensure a final holistic review is performed using `final-reviewer`.

## Non-negotiable rules
- This is one continuous workflow.
- Do not skip the plan-review stage.
- Do not skip approval gates.
- Do not start implementation before spec approval, plan review approval, and user approval to proceed.
- Do not commit workflow artifacts such as specs or plans.
- Do commit implementation changes in clean task-scoped commits.

Keep the user informed of the current phase and next gate as you move through the workflow.
