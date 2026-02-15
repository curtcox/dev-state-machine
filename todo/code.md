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
- Current test being worked (from test list)
- Test list progress (e.g., 3/7)
- Quality metrics (coverage, complexity, lint, security)
- Blocker details (if blocked)

## States

### `red`

A failing test has been written. The system is in a "red" state.

| | |
|---|---|
| **Entry Criteria** | One of: (a) A new test from the test list has been written and it fails. (b) A regression was detected — a previously passing test now fails. |
| **Exit Criteria** | The failing test passes with minimal code changes. All other tests still pass. |
| **Invariants** | Exactly one test is currently "targeted" — the one being made to pass. The test is executable code. The build may be failing (expected). |

### `green`

All tests are passing. Minimal code has been written to make the latest test pass.

| | |
|---|---|
| **Entry Criteria** | The targeted failing test now passes. All other existing tests still pass. |
| **Exit Criteria** | One of: (a) A simpler solution exists → transition to `refactor`. (b) More tests remain in the test list → transition to `red` (write next failing test). (c) All tests pass and quality gates met → exit to Merge machine (create PR). |
| **Invariants** | All tests pass. No new test code should be written in this state (only enough production code to pass the current test). |

### `refactor`

All tests are passing and the code is being improved without changing behavior.

| | |
|---|---|
| **Entry Criteria** | All tests pass. A simpler or cleaner solution has been identified. |
| **Exit Criteria** | One of: (a) Refactoring complete, all tests still pass → transition to `red` (next test) or exit to Merge. (b) A test fails during refactoring (regression) → forced transition to `red`. |
| **Invariants** | No new functionality is being added. No new tests are being written. All existing tests must continue to pass throughout. |

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
| C1 | *(entry from Plan machine)* | `red` | First test written | First test from the test list implemented as failing executable code. |
| C2 | `red` | `green` | Failing test passes | Minimal code written. All other tests still pass. |
| C3 | `green` | `red` | Write next failing test | More items remain in test lists. Next test written and failing. |
| C4 | `green` | `refactor` | Simpler solution identified | All tests pass. Refactoring opportunity identified. |
| C5 | `green` | *(exits to Merge machine)* | All tests done, quality gates pass | No remaining test list items. All automated tests pass. All quality metrics meet thresholds. PR created. |
| C6 | `refactor` | `red` | Next test to write | Refactoring complete. More test list items remain. Next test written and failing. |
| C7 | `refactor` | *(exits to Merge machine)* | All tests done, quality gates pass | Refactoring complete. No remaining items. Quality gates met. PR created. |
| C8 | `refactor` | `red` | Regression detected | A previously passing test fails during refactoring. |
| C9 | `green` | `red` | Regression detected | A previously passing test fails (flaky test, environmental change). |
| C10 | `red` | `blocked` | Blocker identified | External dependency discovered. Previous state recorded. |
| C11 | `green` | `blocked` | Blocker identified | Same as C10. |
| C12 | `refactor` | `blocked` | Blocker identified | Same as C10. |
| C13 | `blocked` | *(previous state)* | Blocker resolved | Returns to TDD state before blocking. |

## Invalid Transitions

| From | To | Reason |
|---|---|---|
| `red` | `refactor` | Cannot refactor when a test is failing. Must go green first. |
| `red` | *(Merge machine)* | Cannot create PR with a failing test. |
| `refactor` | *(Merge machine)* with failing tests | Regression during refactor must be fixed first. |

## Quality Gates

Quality gates are checked before exiting to the Merge machine (transitions C5, C7):

| Metric | Requirement |
|--------|-------------|
| Test coverage | Line and branch percentages meet thresholds |
| Complexity | Cyclomatic and cognitive complexity within limits |
| Lint/Style | Zero violations |
| Static analysis / Security | Zero critical/high findings |

Thresholds defined in `.devstate/quality-gates.yml`.

## TDD Rules

1. **Only write new code when there is a failing test.** No production code without a red test.
2. **Only refactor when all tests are passing.** Never refactor in a red state.
3. **Refactor when there is a simpler solution.** Simplicity is a goal, not optional.
4. **Any regression immediately forces the state back to `red`.** Regressions are highest priority within the current plan.

## Test Execution Order

Tests should generally be implemented in this order within the TDD cycle:

1. Unit tests (fastest feedback)
2. Integration tests
3. Property tests
4. Acceptance tests
5. End-to-end tests
6. Manual tests (defined during test-listing, executed later during Promote validation)

## Commit Rules

- Code state file changes are bundled in the same commit as the code change.
- Commit messages reference the plan and state transition (e.g., `feat(plan-x): implement login validation [red → green]`).
- Every commit must leave the repo in a valid state configuration.
