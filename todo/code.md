# Code State Machine

## Purpose

Governs the TDD inner loop: writing failing tests, making them pass, and refactoring. This machine operates on a feature branch after a plan is ready with complete test lists.

## State Storage

- **File**: `code-state.md` at the repo root.
- Updated via tooling only (never hand-edited).
- Changes bundled in the same commit as the triggering code change.
- Git history is the authoritative transition log.

### State File Tracks

- Current TDD state (red, green, refactor)
- Current targeted test (the unit test actively being made to pass)
- Driving tests in effect (higher-level tests currently failing intentionally)
- Test list progress (e.g., 3/7 unit tests complete)
- Quality metrics (coverage, complexity, lint, security)
- Blocker details (if blocked)

## States

### `red`

A failing unit test has been written and is actively being made to pass. Higher-level driving tests (acceptance, E2E, integration) may also be failing — this is expected and does not block progress.

| | |
|---|---|
| **Entry Criteria** | One of: (a) A new unit test from the test list has been written and it fails. (b) A regression was detected — a previously passing unit test now fails. (c) Entry from Plan machine: the first driving test(s) have been written and the first unit test has been written to begin satisfying them. |
| **Exit Criteria** | The targeted failing unit test passes with minimal code changes. All other previously-passing tests still pass. Intentionally failing driving tests remain failing (expected). |
| **Invariants** | Exactly one unit test is currently "targeted" — the one being made to pass. The test is executable code. The build may be failing (expected). Higher-level driving tests may remain failing without blocking exit. |

### `green`

All previously-passing tests pass. The targeted unit test now passes. Driving tests may still be failing.

| | |
|---|---|
| **Entry Criteria** | The targeted failing unit test now passes. All other previously-passing tests still pass. |
| **Exit Criteria** | One of: (a) A simpler solution exists → transition to `refactor`. (b) More unit tests remain → transition to `red` (write next failing unit test). (c) A useful missing property test is noticed → transition to `red` (write property test). (d) All unit tests pass, all driving tests now pass, and quality gates met → exit to Merge machine. |
| **Invariants** | All previously-passing tests pass. No new test code should be written in this state (only enough production code to pass the current targeted test). Driving tests failing is acceptable here. |

### `refactor`

All previously-passing tests pass and the code is being improved without changing behavior.

| | |
|---|---|
| **Entry Criteria** | All previously-passing tests pass. A simpler or cleaner solution has been identified. |
| **Exit Criteria** | One of: (a) Refactoring complete, all tests still pass → transition to `red` (next test) or exit to Merge. (b) A test fails during refactoring (regression) → forced transition to `red`. |
| **Invariants** | No new functionality is being added. No new tests are being written. All previously-passing tests must continue to pass throughout. |

### `blocked`

An external dependency or impediment prevents coding progress.

| | |
|---|---|
| **Entry Criteria** | A blocker or unmet dependency is identified during `red`, `green`, or `refactor`. |
| **Exit Criteria** | The blocker is resolved or the dependency is met. |
| **On Entry** | The plan's previous TDD state is recorded. The system auto-selects the highest-priority non-blocked plan. |
| **On Exit** | The plan returns to its TDD state before blocking. |
| **Invariants** | Plan file remains in `/doing/`. The blocker is documented in the code state file and plan file. |

## Transition Table

| # | From | To | Trigger | Conditions |
|---|---|---|---|---|
| C1 | *(entry from Plan machine)* | `red` | First driving tests written, then first unit test written | Acceptance, E2E, and/or integration tests from the test list written as failing. Then the first unit test written and failing to begin satisfying them. |
| C2 | `red` | `green` | Targeted unit test passes | Minimal code written. All other previously-passing tests still pass. Driving tests may remain failing. |
| C3 | `green` | `red` | Write next failing unit test | More unit test items remain in test list. Next unit test written and failing. |
| C4 | `green` | `red` | Write property test | A useful missing property test is noticed at any point. Property test written and failing. |
| C5 | `green` | `refactor` | Simpler solution identified | All previously-passing tests pass. Refactoring opportunity identified. |
| C6 | `green` | *(exits to Merge machine)* | All tests done, quality gates pass | All unit tests pass. All driving tests now pass. No remaining test list items. All automated tests pass. All quality metrics meet thresholds. PR created. |
| C7 | `refactor` | `red` | Next test to write | Refactoring complete. More test list items remain. Next unit or property test written and failing. |
| C8 | `refactor` | *(exits to Merge machine)* | All tests done, quality gates pass | Refactoring complete. No remaining items. All driving tests pass. Quality gates met. PR created. |
| C9 | `refactor` | `red` | Regression detected | A previously passing test fails during refactoring. |
| C10 | `green` | `red` | Regression detected | A previously passing test fails (flaky test, environmental change). |
| C11 | `red` | `blocked` | Blocker identified | External dependency discovered. Previous state recorded. |
| C12 | `green` | `blocked` | Blocker identified | Same as C11. |
| C13 | `refactor` | `blocked` | Blocker identified | Same as C11. |
| C14 | `blocked` | *(previous state)* | Blocker resolved | Returns to TDD state before blocking. |
| C15 | `red` | *(exits to Plan machine)* | Fundamental plan flaw discovered | Developer/agent determines the plan is flawed and cannot be fixed by code changes alone. Flaw details and progress recorded in `code-state.md`. |
| C16 | `green` | *(exits to Plan machine)* | Fundamental plan flaw discovered | Same as C15. |
| C17 | `refactor` | *(exits to Plan machine)* | Fundamental plan flaw discovered | Same as C15. |

## Invalid Transitions

| From | To | Reason |
|---|---|---|
| `red` | `refactor` | Cannot refactor when a unit test is failing. Must go green first. |
| `red` | *(Merge machine)* | Cannot create PR with a failing targeted unit test. |
| `green` | *(Merge machine)* | Cannot exit while any driving test (acceptance, E2E, integration) is still failing. |
| `refactor` | *(Merge machine)* with failing tests | Regression during refactor must be fixed first. |
| `blocked` | *(Plan machine)* | Cannot discover a plan flaw while suspended. Unblock first (C14), then assess in an active TDD state. |

## Backward Transition to Plan Machine

When a fundamental plan flaw is discovered during coding (C15, C16, C17):

1. `code-state.md` is updated to record: the flaw description, the TDD state at time of exit, and the test list progress (e.g., "3/7 unit tests implemented").
2. The plan file in `/doing/` is annotated with a "Revision Needed" section describing the discovered flaw.
3. Test code already written is preserved on the feature branch. It is not deleted.
4. The commit recording this transition bundles the state file change per standard commit rules. Message format: `fix(plan-x): return to planning — fundamental flaw [state → Plan]`.

This transition is a **judgment call** by the developer or agent. No automated check can determine that a plan is fundamentally flawed. Examples of fundamental flaws:

- Acceptance criteria are contradictory or impossible to satisfy.
- The plan assumes system architecture that turns out to be wrong.
- The approach is technically infeasible as discovered during implementation.
- Requirements are ambiguous and need clarification before coding can proceed.

This is distinct from a **blocker** (C11–C13). A blocker is an external impediment that will be resolved; a fundamental plan flaw means the plan itself must change.

## Quality Gates

Quality gates are checked before exiting to the Merge machine (transitions C6, C8):

| Metric | Requirement |
|--------|-------------|
| Test coverage | Line and branch percentages meet thresholds |
| Complexity | Cyclomatic and cognitive complexity within limits |
| Lint/Style | Zero violations |
| Static analysis / Security | Zero critical/high findings |

Thresholds defined in `.devstate/quality-gates.yml`.

## Test Type Roles

Each test type has a distinct role in the TDD cycle:

### Driving Tests (written first, may stay failing across many unit test cycles)

| Type | Role |
|------|------|
| **Acceptance tests** | Written first to define what "done" means from a user/stakeholder perspective. Stay failing until all supporting unit tests are complete and integrated. |
| **End-to-end tests** | Written first or early to verify full system behavior. Stay failing until the feature is fully implemented. |
| **Integration tests** | Written after acceptance/E2E tests to specify how components interact. Stay failing until the relevant unit tests and wiring are complete. |

Driving tests are **intentionally left failing** across multiple red/green/refactor cycles. Their failure does not block the `red → green` transition for the targeted unit test. They do block exit to the Merge machine.

### Targeted Tests (written one at a time, must be made green before writing the next)

| Type | Role |
|------|------|
| **Unit tests** | Written one at a time to drive production code. The state machine cycles red/green/refactor around each unit test until all are green and all driving tests pass. |

### Opportunistic Tests (written whenever noticed, treated as targeted tests)

| Type | Role |
|------|------|
| **Property tests** | Written whenever a useful missing property is noticed, regardless of current position in the test list. Treated as a targeted test: must be made green before writing the next test. |

## TDD Rules

1. **Write acceptance, E2E, and integration tests first.** These driving tests define the target. They will stay failing until enough unit tests are implemented to satisfy them.
2. **Only write production code when there is a failing unit test.** No production code without a targeted red unit test.
3. **Failing driving tests do not block the unit test red/green cycle.** Only the targeted unit test governs the red/green state.
4. **All driving tests must pass before exiting to the Merge machine.** A feature is not done until all higher-level tests pass.
5. **Only refactor when all previously-passing tests are passing.** Never refactor in a red state.
6. **Refactor when there is a simpler solution.** Simplicity is a goal, not optional.
7. **Any regression in a previously-passing test immediately forces the state back to `red`.** Regressions are highest priority within the current plan.
8. **Write property tests whenever a useful missing property is noticed.** Property tests are not confined to a fixed position in the test list.

## Test Writing Order

Tests are written in this order, but driving tests may remain failing across many unit test cycles:

1. **Acceptance tests** — written first; stay failing until feature complete
2. **End-to-end tests** — written early; stay failing until feature complete
3. **Integration tests** — written to specify component interactions; stay failing until unit tests and wiring are done
4. **Unit tests** — written one at a time, each driven to green before the next is written
5. **Property tests** — written opportunistically whenever a useful missing property is noticed; each must be made green before continuing
6. **Manual tests** — defined during test-listing (in Plan machine), executed later during Promote validation

## Concurrency

- The system is single-threaded. Only one plan is actively being worked across all machines at any given time.

## Commit Rules

- Code state file changes are bundled in the same commit as the code change.
- Commit messages reference the plan and state transition (e.g., `feat(plan-x): implement login validation [red → green]`).
- Every commit must leave the repo in a valid state configuration.
