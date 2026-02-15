# Development Process — Multi-Machine Overview

## Purpose

This document describes how four independent state machines compose to govern the software development lifecycle. Each machine is small, focused, and owns a clear scope. Together they cover the full path from "idea" to "deployed in production."

## The Four State Machines

| Machine | Scope | State Storage | Active When |
|---------|-------|---------------|-------------|
| **Plan** | Deciding what to do, breaking work down, writing test lists | `plan-state.md` in repo | Feature branch, no test code yet |
| **Code** | TDD inner loop: red, green, refactor | `code-state.md` in repo | Feature branch, test code being written |
| **Merge** | Getting code reviewed and merged via PRs | Derived from GitHub | Open PR exists |
| **Promote** | Deploying through environments, validating | Derived from GitHub | Code merged to environment branch |

## Determining the Active Machine

The active machine for a given plan is determined by observable state:

1. **No feature branch yet, or branch has no test code** → Plan
2. **Feature branch has test code, no open PR** → Code
3. **Open PR exists for this branch** → Merge
4. **PR merged, deployment in progress or complete** → Promote

In practice, the current git branch plus GitHub PR/deployment status tells you exactly where you are.

## Inter-Machine Transitions

```
  Plan ──────► Code ──────► Merge ──────► Promote
   │            │             │              │
   │ ready      │ PR created  │ PR merged    │ deployed &
   │ (test      │             │              │ validated
   │  lists     │             │              │
   │  done)     │             │              │
   │            │             │              │
   └──── ◄─────┴──── ◄──────┴──── ◄────────┘
         (failures roll back to earlier machines)
```

### Forward Transitions

| From | To | Trigger |
|------|----|---------|
| Plan | Code | Plan has acceptance criteria and complete test lists for all applicable test types. First failing test written. |
| Code | Merge | All tests passing, quality gates met. Developer/agent creates PR. |
| Merge | Promote | PR merged to target environment branch. CI/CD deployment triggered. |
| Promote | Merge | Validated in non-production environment. PR auto-created for next environment. |
| Promote | (done) | Deployed and validated in production. Plan moved to `/done/`. |

### Backward Transitions (Failures)

| From | To | Trigger |
|------|----|---------|
| Code | Plan | Fundamental flaw in plan discovered during coding. Plan needs revision. |
| Merge | Code | CI checks fail, review requests changes that require code rework. |
| Promote | Plan | Deployment failure. Highest-priority fix plan auto-created, enters Plan machine, flows through normal Plan → Code → Merge → Promote. |

## Bug and Hotfix Handling

A bug is just a plan with a different origin. There are no special bug states.

| Scenario | Entry Point | Flow |
|----------|-------------|------|
| Feature request | Plan (from backlog) | Plan → Code → Merge → Promote |
| Bug report | Plan (new plan created) | Plan → Code → Merge → Promote |
| Production incident | Plan (high-priority plan auto-created) | Plan → Code → Merge → Promote |
| Deployment failure | Plan (highest-priority plan auto-created, blocks all other work) | Plan → Code → Merge → Promote |

Priority and urgency are metadata on the plan, not structural elements of any state machine.

## Concurrency Model

- **One plan at a time.** The system is single-threaded. Only one plan is actively being worked across all four machines at any given time.
- **Deployment failure overrides everything**: when Promote enters `failed`, a new highest-priority plan is auto-created, and no other plan may progress until it is resolved.

### Priority Resolution

When the system needs to select the next plan for active work:

1. If a deployment-failure plan exists → work on that (highest priority).
2. Otherwise, select the highest-priority non-blocked plan.
3. If all plans are blocked → idle.

## State Storage

### Repo-Resident State (Plan and Code)

- `plan-state.md` — Tracks plan status: which plans exist, their priority, whether they're in planning/decomposing/test-listing, blockers.
- `code-state.md` — Tracks TDD state: current test, red/green/refactor, test list progress, quality metrics.
- Both files live at the repo root.
- Both files are updated via tooling, not hand-edited.
- Changes to state files are bundled in the same commit as the triggering change.
- Git history of these files is the authoritative transition log.

### GitHub-Derived State (Merge and Promote)

- Merge state is derived from: PR existence, PR status (open/closed/merged), review status, CI check results.
- Promote state is derived from: deployment status, environment health checks, CI/CD pipeline results.
- No repo files needed — query GitHub directly.

## Quality Gates

Quality gates are checked at machine boundaries:

- **Code → Merge**: All automated tests pass. Coverage, complexity, lint, and security metrics meet thresholds defined in `.devstate/quality-gates.yml`.
- **Merge (CI checks)**: Re-validated by CI on every PR update.
- **Promote (deployment checks)**: Post-deployment health checks must pass.

## Directory Structure

```
/
├── plan-state.md         # Plan machine state
├── code-state.md         # Code machine state
├── doing/                # Plan files actively being worked
├── todo/                 # Plan files queued for future work
├── done/                 # Completed plan files
└── .devstate/
    └── quality-gates.yml # Quality gate thresholds
```

## Related Documents

- [Plan State Machine](plan.md)
- [Code State Machine](code.md)
- [Merge State Machine](merge.md)
- [Promote State Machine](promote.md)
