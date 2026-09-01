# REVIEW workflow

Review adversarially. Do not assume the implementation or its report is correct. Do **not** modify code unless explicitly requested.

## Review inputs

1. Read `AGENTS.md`, the approved feature specification, implementation plan, and relevant linked project documentation.
2. Inspect the complete git diff, changed files, and surrounding code. Do not review isolated hunks without their call sites and invariants.
3. Inspect verification evidence and run safe, relevant checks when useful. Independently trace acceptance criteria to code and observable behavior.
4. When old-system parity is required, compare the implementation with available old-system evidence.

## Review dimensions

Check:

- requirements and every acceptance criterion;
- missing behavior, negative cases, and scope deviations;
- Devise authentication, role authorization, record ownership, IDOR, and denied paths;
- strong parameters, boundary validation, and model/database invariants;
- sensitive data, Active Storage access, email previews, signed tokens, CSRF, leakage, replay, and logging;
- data integrity, migrations, existing rows, constraints, transactions, locks, concurrency, retention, and deletion;
- webhook authenticity, external side-effect ordering, retries, idempotency, duplicate submissions, and partial failure;
- Rails architecture, namespace/layout boundaries, and separation of HTTP/domain/external concerns;
- unnecessary abstractions, indirection, duplication, and unrelated refactoring;
- model/service/job/controller/system/JavaScript tests, regression coverage, false-positive tests, and missing verification;
- UI/UX states, accessibility, responsive behavior, role-aware presentation, localization, and browser evidence;
- old-system parity and compatibility where applicable.

Use severity carefully:

- **BLOCKER** — unsafe to proceed or impossible to evaluate due to a fundamental issue.
- **HIGH** — likely security, data-loss, contractual, or core-function failure requiring correction.
- **MEDIUM** — meaningful requirement, reliability, architecture, or test defect.
- **LOW** — limited-impact issue worth fixing without blocking most use.
- **NOTE** — observation or optional improvement, not a defect.

Do not inflate severity. Findings must be specific, evidenced, and actionable. If there are no findings, say so plainly.

## Required output

```markdown
# Review verdict

APPROVE
```

Use exactly one verdict:

```text
APPROVE
APPROVE WITH MINOR CHANGES
REQUEST CHANGES
BLOCK
```

Then provide:

```markdown
# Acceptance criteria review

| Criterion | Result | Evidence |
|---|---|---|
| AC-001 | PASS / FAIL / NOT VERIFIED | ... |

# Findings

## [SEVERITY] Short title

Location:
...

Problem:
...

Impact:
...

Recommended fix:
...

# Missing verification

Checks or criteria that remain unproven.

# Complexity review

Whether the solution is the smallest coherent change and follows existing patterns.

# Security conclusion

Explicit conclusion on authentication, authorization/ownership, sensitive data, attack surface, and side-effect safety.

# Final recommendation

What must happen next and whether implementation can proceed or ship.
```

`APPROVE` requires all material criteria to be supported by evidence and no blocking finding. `APPROVE WITH MINOR CHANGES` is for non-material corrections. `REQUEST CHANGES` means implementation defects must be fixed. `BLOCK` is reserved for a fundamental requirements, evidence, or safety problem that prevents a meaningful approval decision.
