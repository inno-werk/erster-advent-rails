# Shared agent workflows

These workflows are canonical for every coding agent used in this repository. `AGENTS.md` decides which phases are proportionate to a task; trivial work may skip phases.

```text
SPEC → PLAN → IMPLEMENT → REVIEW
```

## SPEC

SPEC defines **WHAT** should happen. It consumes an informal request plus repository evidence and produces an implementation-ready feature specification in `docs/features/<feature-slug>.md`. It resolves discoverable uncertainty, records assumptions, and stops for genuinely blocking product decisions.

Use [`spec.md`](spec.md) when requirements are incomplete, behavior spans several areas, parity or migration matters, or risk warrants explicit acceptance criteria.

## PLAN

PLAN defines **HOW** the approved behavior should be implemented. It consumes an approved specification and repository evidence, validates the specification against reality, and produces an implementation plan with concrete files, steps, risks, and verification.

Use [`plan.md`](plan.md) for standard and high-risk implementation work. Planning must not change production code.

## IMPLEMENT

IMPLEMENT executes the approved plan. It consumes the approved specification and plan, produces the smallest coherent code/documentation change, and reports acceptance-criterion evidence and verification results.

Use [`implement.md`](implement.md) when authorized to make changes. Verification is continuous, not deferred until the end.

## REVIEW

REVIEW independently checks the implementation against requirements. It consumes the approved specification, plan, complete diff, surrounding code, and verification evidence. It produces an adversarial verdict and severity-ranked findings. It does not modify code unless explicitly requested.

Use [`review.md`](review.md) after standard work and require an independent reviewer for high-risk work.

## Artifact flow

| Phase | Consumes | Produces |
|---|---|---|
| SPEC | Request, repository evidence, existing-system evidence | Approved feature specification |
| PLAN | Approved specification, repository evidence | Approved implementation plan |
| IMPLEMENT | Approved specification and plan | Verified change and implementation report |
| REVIEW | Specification, plan, diff, code, verification | Verdict and findings |

Do not duplicate these workflows in vendor-specific configuration. Claude Code and Codex should both read `AGENTS.md` and the corresponding file here.
