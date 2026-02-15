# Plan State Machine

## Purpose

Governs the process of deciding **what** to do, breaking work down into implementable pieces, and writing test lists. This machine operates before any test code is written.

## State Storage

- **File**: `plan-state.md` at the repo root.
- Updated via tooling only (never hand-edited).
- Changes bundled in the same commit as the triggering action.
- Git history is the authoritative transition log.

## States

### `idle`

No plans are active. The developer/agent has no planning work to do.

| | |
|---|---|
| **Entry Criteria** | No plans in `/doing/` and no plans in `/todo/`, OR all plans are blocked and `/todo/` is empty. |
| **Exit Criteria** | A new plan is created or a blocker is resolved. |
| **Invariants** | Plan state file shows no active plans. |

### `planning`

A plan is being written or refined.

| | |
|---|---|
| **Entry Criteria** | A plan has been selected for work. Plan file exists in `/doing/`. Feature branch created. |
| **Exit Criteria** | Plan is detailed enough to write test lists, OR plan is identified as too large and must be decomposed. |
| **Invariants** | Plan file is in `/doing/`. State file reflects this plan as active. No test code has been written for this plan, unless re-entering via P11 (from Code machine), in which case existing test code is preserved on the feature branch pending revision. |

### `decomposing`

A plan has been identified as too large. It is being broken into child plans.

| | |
|---|---|
| **Entry Criteria** | Plan was in `planning` and determined to be too large to write acceptance tests for. |
| **Exit Criteria** | All child plans created in `/todo/`. Parent plan updated with child links and moved to `/todo/`. |
| **Invariants** | Parent plan is still in `/doing/` until decomposition is complete. |

### `test-listing`

Writing test lists (prose descriptions) for all test types before writing any test code.

| | |
|---|---|
| **Entry Criteria** | Plan is specific and small enough to write tests for. All test types have been considered. |
| **Exit Criteria** | Test lists are complete for all applicable test types: unit, integration, property, acceptance, end-to-end, and manual. Each item is a single-sentence prose description. |
| **Invariants** | No test code has been written yet. Plan file in `/doing/` contains the test lists. |

### `ready`

Plan is fully specified with test lists and ready to hand off to the Code machine.

| | |
|---|---|
| **Entry Criteria** | Test lists are complete for all applicable test types. Acceptance criteria are defined. |
| **Exit Criteria** | Work begins in the Code machine (first failing test written). |
| **Invariants** | Plan file in `/doing/` has complete test lists. No test code exists yet. |

### `blocked`

A plan has an unresolved blocker or unmet dependency preventing planning progress.

| | |
|---|---|
| **Entry Criteria** | A blocker or unmet dependency is identified during `planning`, `decomposing`, or `test-listing`. |
| **Exit Criteria** | The blocker is resolved or the dependency is met. |
| **On Entry** | The plan's previous state is recorded. The system auto-selects the highest-priority non-blocked plan. |
| **On Exit** | The plan returns to its previous state before blocking. It re-enters the priority queue if another plan is currently active. |
| **Invariants** | Plan file remains in `/doing/`. The blocker is documented in the state file and plan file. |

## Transition Table

| # | From | To | Trigger | Conditions |
|---|---|---|---|---|
| P1 | `idle` | `planning` | New plan selected from `/todo/` or new plan created | Plan file moved to `/doing/`. Feature branch created. |
| P2 | `planning` | `decomposing` | Plan identified as too large | Cannot write meaningful acceptance tests at current granularity. |
| P3 | `planning` | `test-listing` | Plan is ready for test design | Plan is specific and small enough to write test lists. |
| P4 | `decomposing` | `idle` | Decomposition complete | Child plans created in `/todo/`. Parent moved to `/todo/` with child links. System selects next plan. |
| P5 | `test-listing` | `ready` | Test lists complete | All applicable test types have prose test descriptions. |
| P6 | `ready` | *(exits to Code machine)* | First test written | Transition out of Plan machine into Code machine. |
| P7 | `planning` | `blocked` | Blocker identified | External dependency or impediment discovered. Previous state recorded. |
| P8 | `decomposing` | `blocked` | Blocker identified | Same as P7. |
| P9 | `test-listing` | `blocked` | Blocker identified | Same as P7. |
| P10 | `blocked` | *(previous state)* | Blocker resolved | Plan returns to state before blocking. |
| P11 | *(entry from Code machine)* | `planning` | Plan revision needed | Fundamental flaw discovered during coding. Plan file remains in `/doing/`. Existing test code preserved on feature branch. Previous test lists retained for reference during revision. |

## Invalid Transitions

| From | To | Reason |
|---|---|---|
| `planning` | `ready` | Must write test lists first. Cannot skip `test-listing`. |
| `test-listing` | `planning` | Internal transition not allowed. If the plan needs revision while still in the Plan machine, it should go through `blocked` or be decomposed. Cross-machine re-entry from Code uses P11. |
| `idle` | `test-listing` | Must go through `planning` first to ensure plan quality. |

## Plan File Format

Plans are markdown files with this structure:

```markdown
# Plan: [Title]

## Goal
[One-sentence description of what this plan achieves]

## Parent Plan
[Link to parent plan if this is a child, or "none"]

## Child Plans
[Links to child plans if decomposed, or "none"]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Test Lists

### Unit Tests
- Description of unit test 1

### Integration Tests
- Description of integration test 1

### Property Tests
- Description of property test 1

### Acceptance Tests
- Description of acceptance test 1

### End-to-End Tests
- Description of e2e test 1

### Manual Tests
- Description of manual test 1

## Priority
[1-5, where 1 is highest]

## Dependencies
- [List of other plans or external dependencies]

## Notes
[Any additional context]
```

## Plan Lifecycle (Within This Machine)

1. **Creation**: New plan file created in `/todo/`.
2. **Activation**: Plan file moved from `/todo/` to `/doing/` when work begins (P1).
3. **Decomposition**: If too large, broken into child plans. Parent returns to `/todo/` (P2 → P4).
4. **Test Listing**: Test lists written for all applicable types (P3 → P5).
5. **Ready**: Handed off to Code machine (P6).

## Rules

1. Write a test list before writing any test code.
2. Extract a sub-plan if the current plan is too big to write acceptance tests for.
3. A parent plan cannot complete until all child plans are complete.
4. The state machine operates on leaf plans only (no TDD on plans with children).
5. Plans are actual markdown files that move between `/todo/`, `/doing/`, and `/done/`.

## Concurrency

- The system is single-threaded. Only one plan is actively being worked across all machines at any given time.

## Directory Structure

```
/
├── plan-state.md         # Plan machine state
├── doing/                # Plans actively being worked
├── todo/                 # Plans queued for future work (priority ordered)
└── done/                 # Completed plans (archived)
```
