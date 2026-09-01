# IMPLEMENT workflow

Use this workflow only when authorized to change the repository.

## Prepare

1. Read `AGENTS.md`, the approved feature specification, the approved implementation plan, and relevant linked project documentation.
2. Inspect `git status`, the complete current diff, and every relevant file before editing. Existing changes belong to the user unless proven otherwise; preserve them.
3. Confirm the plan is still consistent with the worktree. Stop and report a material specification/plan conflict instead of improvising a different feature.

## Implement incrementally

- Make the smallest coherent change that satisfies the approved requirements.
- Avoid unrelated refactoring, formatting, renaming, dependencies, or infrastructure.
- Preserve Rails namespaces and the established `routes → controllers → models/services/jobs → Active Record and external systems` direction.
- Keep HTTP concerns and strong parameters in controllers, cohesive invariants/transitions in models, multi-record/external workflows in services, and retryable background execution in jobs.
- Validate untrusted input at boundaries and retain important model/database invariants.
- Enforce authentication, roles, and record ownership server-side; UI visibility is only presentation.
- Preserve Active Storage access, email-preview isolation, payment verification, and secret filtering. Never store sensitive values in public files or logs.
- Design uploads, payments, emails, webhooks, and jobs for retry, partial failure, and duplicate execution.
- Add or update tests with each behavior slice. Bug fixes should include regression coverage when reasonably possible.

Run narrow verification after each meaningful step: a focused Rails test, a JavaScript test, a model/service invocation, a targeted request, or a browser flow. Do not defer all feedback until the end.

## Required verification

For non-trivial changes run at minimum:

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Also run relevant JavaScript tests with `node --test test/javascript/*_test.mjs`, relevant system tests with `bin/rails test:system`, and browser verification when available and applicable. For user-facing changes, exercise the primary flow plus relevant validation, ownership/role denial, failure, empty/loading, and responsive states.

Before completion:

1. Re-read every acceptance criterion.
2. Inspect the complete git diff and surrounding code.
3. Check authentication, authorization/ownership, validation, security, data integrity, failure behavior, and side-effect idempotency.
4. Confirm no unrelated behavior changed and no debug or temporary artifacts remain.
5. Record evidence for each criterion. A command succeeding is evidence only for what that command actually checks.

Do not claim `PASS` without concrete evidence. Use `NOT VERIFIED` when evidence is absent or a check could not be run.

## Implementation report

```markdown
# Completed

Concise description of verified behavior.

# Acceptance criteria

- AC-001 — PASS — <test, command, diff location, or browser evidence>
- AC-002 — NOT VERIFIED — <reason>

# Verification

Commands, tests, and browser flows with results.

# Changed areas

Files/domains changed and why.

# Assumptions / deviations

Any approved assumptions, plan deviations, and rationale.

# Not verified

Anything not confidently checked and its impact.
```
