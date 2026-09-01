# PLAN workflow

Use this workflow to define **HOW** an approved specification will be implemented. Do **not** implement code or modify application behavior during this phase.

## Inputs and investigation

1. Read `AGENTS.md`, the approved feature specification, and relevant linked project documentation.
2. Deeply inspect the relevant routes, controllers, models, services, jobs, mailers, views, tests, database schema, migrations, configuration, and git history.
3. Validate every material specification statement against repository reality. Record conflicts rather than planning around them silently.
4. Search for existing patterns and reuse them when adequate. Do not introduce a new abstraction without a concrete architectural reason.
5. Preserve Rails namespace/layout boundaries, server-side role and ownership checks, model/database invariants, and payment/file/email safety rules.

## Pre-coding design and security review

Before finalizing the plan, explicitly consider:

- Devise authentication, server-side role authorization, and record ownership/IDOR;
- signed-token purpose, scope, expiry, enumeration, and replay where applicable;
- sensitive data minimization, Active Storage access, email-preview isolation, and safe logging;
- information leakage through responses, errors, views, logs, exports, emails, and URLs;
- CSRF, strong parameters, duplicate submissions, concurrent writes, race conditions, transactions, locks, and database constraints;
- external side-effect ordering, webhook authenticity, retries, idempotency, and partial failure;
- backwards compatibility, existing rows, migrations, deletion, retention, rollout, and rollback;
- whether the design introduces unnecessary complexity or bypasses an established Rails seam.

A high-risk plan requires independent review before implementation according to `AGENTS.md`.

## Required plan

```markdown
# Implementation Plan: <feature>

## Summary
The intended implementation shape and scope.

## Existing system findings
Relevant paths, patterns, constraints, and specification conflicts.

## Proposed design
Responsibilities, control/data flow, reuse of existing patterns, and failure handling.

## Data changes
Schema, migrations, existing rows, constraints, indexes, concurrency, retention, and rollback. Say “None” when applicable.

## Authorization
Authentication, roles, controller guards, ownership checks, view behavior, and denial paths.

## Implementation steps

### Step 1 — <name>

Files likely affected:
- ...

Changes:
- ...

Why:
- ...

Verification:
- ...

Dependencies:
- ...

## Test plan
Model, service, job, controller/integration, system, JavaScript, regression, failure, security, and concurrency coverage mapped to acceptance criteria.

## Browser verification
Flows, role/ownership variants, failure states, and relevant desktop/tablet/mobile viewports. Say why it is not applicable when omitted.

## Risks
Risk, likelihood/impact, mitigation, and remaining exposure.

## Assumptions
CONFIRMED, INFERRED, and ASSUMED decisions with their basis.

## Expected changed files
A bounded file list with purpose; identify uncertain additions.

## Definition of done
Acceptance criteria, required commands, tests, browser flows, diff review, documentation, and operational checks.

## Final assessment
READY FOR IMPLEMENTATION
```

Each step must be independently understandable and verifiable. Order steps by dependency and keep them small enough to validate incrementally. The expected-file list is a scope forecast, not permission to modify unrelated files.

## Final status

The final assessment must be exactly one of:

```text
READY FOR IMPLEMENTATION
```

or

```text
BLOCKED — SPECIFICATION CONFLICT
```

Use the blocked status when the approved specification conflicts materially with repository reality or cannot be implemented safely without changing requirements.
