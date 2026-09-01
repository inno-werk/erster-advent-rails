# SPEC workflow

Use this workflow to turn an informal request into implementation-ready requirements. Do **not** implement code or modify application behavior during this phase.

## Inputs and preparation

1. Read `AGENTS.md` and relevant documents linked from it.
2. Read the complete client request and any supplied notes or artifacts.
3. Investigate before asking questions. Inspect relevant routes, controllers, models, services, jobs, mailers, views, tests, database schema, migrations, configuration, existing documentation, and git history where useful.
4. When migration or parity is required and the old/existing system is available, inspect its behavior and evidence. Do not infer parity from screenshots or labels alone.
5. Convert informal notes into observable behavior, constraints, permissions, failure behavior, and verification criteria.

Use existing repository behavior as evidence, not as an automatic requirement. Call out conflicts between the request, existing implementation, and documentation.

## Evidence and uncertainty

Classify material conclusions:

- **CONFIRMED** — explicitly required or supported by authoritative repository/existing-system evidence.
- **INFERRED** — strongly implied by established behavior or patterns.
- **ASSUMED** — selected because evidence is unavailable.

Every important inference or assumption must state its basis and impact. Do not ask questions the repository can answer.

Separate open questions into:

- **BLOCKING** — the answer materially changes security, architecture, data integrity, destructive behavior, money, contracts, legal behavior, important external communication, or core user experience.
- **NON-BLOCKING** — a conservative default permits safe progress. State the proposed default and its rationale.

Avoid turning cosmetic preferences into blockers. If a blocking answer is missing, stop at requirements; do not plan or implement.

## Required specification

Write the specification to `docs/features/<feature-slug>.md` by default. Do not create an empty placeholder.

```markdown
# Feature: <name>

## Goal
The outcome and business/user value.

## Actors
Who initiates, receives, administers, reads, or must be excluded.

## Current behavior
Observed behavior, including evidence and known limitations.

## Desired behavior
The intended end state without prescribing implementation unnecessarily.

## Functional requirements
- REQ-001 — ...
- REQ-002 — ...

## Acceptance criteria
- AC-001 — Given ..., when ..., then ...
- AC-002 — Given ..., when ..., then ...

## Authorization
Roles, ownership boundaries, denied actors, and failure response.

## Data and persistence
Entities, fields, constraints, lifecycle, existing-row implications, and deletion/retention.

## External side effects
Email, payment, file, webhook, job, retry, duplicate-send, and audit behavior.

## Security and privacy
Sensitive data, storage access, signed tokens, IDOR, CSRF, leakage, logging, replay, and abuse concerns.

## UI states
Success, loading, empty, validation, permission-denied, failure, responsive, keyboard, and touch states where relevant.

## Edge cases
Boundary conditions, concurrency, duplicate submission, partial failure, and recovery.

## Compatibility / migration
Existing data, old-system parity, backwards compatibility, rollout, and rollback constraints.

## Out of scope
Explicit exclusions that prevent silent scope expansion.

## Evidence
Repository paths, tests, migrations, git history, existing-system observations, and classification as CONFIRMED/INFERRED/ASSUMED.

## Open questions
### BLOCKING
...

### NON-BLOCKING
... with proposed conservative defaults.

## Requirement-to-verification matrix
| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001 | AC-001 | Automated test or explicit manual flow |

## Final assessment
READY FOR PLANNING
```

Requirements and acceptance criteria must be atomic, testable, and traceable. Use Given/When/Then when it makes preconditions and outcomes clearer. Include negative authorization and failure cases, not only the happy path.

## Final status

The final assessment must be exactly one of:

```text
READY FOR PLANNING
```

or

```text
BLOCKED — REQUIRES ANSWERS
```

Use `READY FOR PLANNING` only when the requirements are sufficiently complete for design. Use the blocked status when unresolved BLOCKING questions remain.
