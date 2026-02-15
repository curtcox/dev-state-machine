# Software Development State Machine — Requirements

## 1. Overview

This document specifies a **software development process state machine** that governs the lifecycle of plans (features, tasks, bug fixes) from inception through production deployment. The state machine is:

- **Actor-agnostic**: Works identically whether the actor is a human developer or an AI agent.
- **Abstract**: Not tied to any specific software project — it defines the *process*, not the *product*.
- **Repository-resident**: All state is stored in the git repository. Git history is the authoritative record of all state transitions.
- **Enforceable**: Transitions are validated by tooling. Invalid transitions are rejected.

The state machine has two layers:

1. **Inner loop (TDD cycle)**: Red → Green → Refactor, executed on feature branches.
2. **Outer loop (promotion pipeline)**: Feature branch → dev → test → main, each with CI/CD deployment.

---

## 2. Core Concepts

| Concept | Definition |
|---|---|
| **Plan** | A markdown document describing work to be done. Plans are hierarchical — a plan too large for direct acceptance testing is decomposed into child plans. |
| **Test List** | A markdown list where each item is a single-sentence prose description of what should be tested. Written before any test code. Required for all test types. |
| **State File** | `state.md` at the repo root. Tracks all active, blocked, and paused plans and their current states. |
| **Feature Branch** | Where TDD happens. One branch per active plan. |
| **Promotion** | Moving code from one environment branch to the next (dev → test → main). |
| **Blocker** | An external dependency or impediment preventing progress on a plan. Forces context switch. |
| **Quality Gate** | Code quality metrics that must meet defined thresholds to permit state transitions. |

---

## 3. Directory Structure

```
/
├── state.md              # Current state of all plans (single source of truth)
├── doing/                # Plan files actively being worked
│   ├── feature-x.md
│   └── bugfix-y.md
├── todo/                 # Plan files queued for future work (priority ordered)
│   ├── feature-z.md
│   └── improvement-w.md
├── done/                 # Completed plan files (archived)
│   └── feature-a.md
└── plans/                # (not used — plans live directly in doing/todo/done)
```

- **`/doing/`** — Contains plan files for all plans currently in progress (active or blocked).
- **`/todo/`** — Contains plan files for future work. Files are priority-ordered (naming convention or frontmatter).
- **`/done/`** — Contains completed plan files. Moved here when a plan reaches `complete` state.
- Plans are **actual markdown files** that move between directories as their status changes.

---

## 4. State File Format (`state.md`)

The state file has a standard defined format. It can be read directly as markdown and queried programmatically via tooling. It must only be updated via the state update tool.

```markdown
# Development State

## Active Plans

### [plan-name]
- **State**: red
- **Branch**: feature/plan-name
- **Plan File**: doing/plan-name.md
- **Current Test**: unit test — user can log in with valid credentials
- **Test List Progress**: 3/7
- **Blockers**: none
- **Dependencies**: none
- **Quality Metrics**: coverage 87%, complexity A, lint pass, security pass

### [another-plan]
- **State**: blocked
- **Branch**: feature/another-plan
- **Plan File**: doing/another-plan.md
- **Current Test**: n/a
- **Test List Progress**: 1/4
- **Blockers**: waiting on API v2 from upstream team
- **Dependencies**: plan-name (must complete first)
- **Quality Metrics**: n/a

## Global Status

- **Deployment Failure**: none
- **Environment Health**: dev ✓ | test ✓ | main ✓
```

### State File Rules

1. The state file **must always reflect the actual current state** of development.
2. The state file **must only be modified via the state update tool** — never edited by hand.
3. The state file change is **bundled in the same commit** as the code change that triggered the transition.
4. **Git history of `state.md`** is the authoritative transition log. No separate log file is maintained.
5. Tools are available for programmatically querying the state file (current state, plan details, blockers, etc.).

---

## 5. Plans

### Plan Format

Plans are written in markdown with the following structure:

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
- Description of unit test 2

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

### Plan Lifecycle

1. **Creation**: New plan file created in `/todo/`.
2. **Activation**: Plan file moved from `/todo/` to `/doing/` when work begins.
3. **Decomposition**: If a plan is too large to write acceptance tests for, it is decomposed into child plans. The parent plan moves back to `/todo/` with links to children. Children are created in `/todo/`. The parent completes automatically when all children complete.
4. **Blocking**: Plan remains in `/doing/` but state is set to `blocked`. When a blocker forces context switch, the state machine auto-selects the highest-priority non-blocked plan from `/todo/`.
5. **Completion**: Plan file moved from `/doing/` to `/done/` when the plan reaches `complete` state.

### Plan Hierarchy

- Plans can nest to arbitrary depth.
- A parent plan cannot be completed until all child plans are complete.
- A parent plan in `/todo/` tracks its children via links in its "Child Plans" section.
- The state machine always operates on **leaf plans** (plans with no children).

---

## 6. States

### 6.1 Feature Branch States (Inner TDD Loop)

#### `planning`

The plan is being written or refined.

| | |
|---|---|
| **Entry Criteria** | A plan has been selected for work. Plan file exists in `/doing/`. Branch created. |
| **Exit Criteria** | Plan is detailed enough to write test lists for all required test types, OR plan is identified as too large and must be decomposed. |
| **Invariants** | Plan file is in `/doing/`. State file reflects this plan as active. No test code has been written for this plan yet. |

#### `decomposing`

A plan has been identified as too large. It is being broken into child plans.

| | |
|---|---|
| **Entry Criteria** | Plan was in `planning` and determined to be too large to write acceptance tests for. |
| **Exit Criteria** | All child plans created in `/todo/`. Parent plan updated with child links and moved to `/todo/`. |
| **Invariants** | Parent plan is still in `/doing/` until decomposition is complete. |

#### `test-listing`

Writing test lists (prose descriptions) for all test types before writing any test code.

| | |
|---|---|
| **Entry Criteria** | Plan is detailed and small enough to write tests for. All test types have been considered. |
| **Exit Criteria** | Test lists are complete for all applicable test types: unit, integration, property, acceptance, end-to-end, and manual. Each item is a single-sentence prose description. |
| **Invariants** | No test code has been written yet. Plan file in `/doing/` contains the test lists. |

#### `red`

A failing test has been written. The system is in a "red" state.

| | |
|---|---|
| **Entry Criteria** | One of: (a) A new test from the test list has been written and it fails. (b) A regression was detected — a previously passing test now fails. |
| **Exit Criteria** | The failing test passes with minimal code changes. All other tests still pass. |
| **Invariants** | Exactly one test is currently "targeted" — the one being made to pass. The test is executable code, not prose. The build may be failing (expected — there's a known red test). |

#### `green`

All tests are passing. Minimal code has been written to make the latest test pass.

| | |
|---|---|
| **Entry Criteria** | The targeted failing test now passes. All other existing tests still pass. |
| **Exit Criteria** | One of: (a) A simpler solution exists → transition to `refactor`. (b) More tests remain in the test list → transition to `red` (write next failing test). (c) All tests in all test lists pass and quality gates met → transition to `pr-dev`. |
| **Invariants** | All tests pass. No new test code should be written in this state (only enough production code to pass the current test). |

#### `refactor`

All tests are passing and the code is being improved without changing behavior.

| | |
|---|---|
| **Entry Criteria** | All tests pass. A simpler or cleaner solution has been identified. |
| **Exit Criteria** | One of: (a) Refactoring complete, all tests still pass → transition to next test (`red`) or `pr-dev`. (b) A test fails during refactoring (regression) → forced transition to `red`. |
| **Invariants** | No new functionality is being added. No new tests are being written. All existing tests must continue to pass throughout. |

---

### 6.2 Promotion Pipeline States (Outer Loop)

#### `pr-dev`

A pull request has been auto-created to merge the feature branch into `dev`.

| | |
|---|---|
| **Entry Criteria** | All test lists fully implemented. All automated tests pass (unit, integration, property, acceptance, end-to-end). All quality gates pass (coverage, complexity, lint, static analysis/security). |
| **Exit Criteria** | PR passes all CI checks and is merged to `dev`. |
| **Invariants** | PR exists and is open. CI checks are running or have passed. No new commits should be pushed to the feature branch unless CI fails (fix and re-push). |

#### `on-dev`

Code has been merged to `dev` and CI is deploying to the dev environment.

| | |
|---|---|
| **Entry Criteria** | PR to `dev` has been merged. CI deployment triggered. |
| **Exit Criteria** | Deployment to dev environment succeeds. All post-deployment checks pass. |
| **Invariants** | The dev branch contains this plan's code. CI/CD pipeline is running or complete. |

#### `pr-test`

A pull request has been auto-created to merge `dev` into `test`.

| | |
|---|---|
| **Entry Criteria** | Code is successfully deployed and verified on dev. All automated tests pass in the dev environment. Quality gates met. |
| **Exit Criteria** | PR passes all CI checks and is merged to `test`. |
| **Invariants** | PR exists and is open. |

#### `on-test`

Code has been merged to `test` and CI is deploying to the test environment.

| | |
|---|---|
| **Entry Criteria** | PR to `test` has been merged. CI deployment triggered. |
| **Exit Criteria** | Deployment to test environment succeeds. All post-deployment checks pass. |
| **Invariants** | The test branch contains this plan's code. |

#### `manual-testing`

Awaiting manual test approval. This is a separate approval gate with a designated reviewer.

| | |
|---|---|
| **Entry Criteria** | Code is deployed and running in the test environment. Manual test checklist is available in the plan. |
| **Exit Criteria** | A designated reviewer has executed all manual tests and explicitly approved. All manual tests pass. |
| **Invariants** | No automated state transitions occur. A human must sign off. The manual test results are recorded in the plan file. |

#### `pr-main`

A pull request has been auto-created to merge `test` into `main`.

| | |
|---|---|
| **Entry Criteria** | Manual testing approved. All automated tests pass in the test environment. All quality gates pass. |
| **Exit Criteria** | PR passes all CI checks and is merged to `main`. |
| **Invariants** | PR exists and is open. Manual test approval is linked/referenced in the PR. |

#### `complete`

Code has been merged to `main` and deployed to production.

| | |
|---|---|
| **Entry Criteria** | PR to `main` has been merged. CI deployment to production succeeds. |
| **Exit Criteria** | N/A — this is a terminal state for the plan. |
| **Side Effects** | Plan file moved from `/doing/` to `/done/`. Plan removed from `state.md` active list. If this plan has a parent, check if all siblings are complete; if so, mark parent as complete. |

---

### 6.3 Special States

#### `blocked`

A plan has an unresolved blocker or unmet dependency.

| | |
|---|---|
| **Entry Criteria** | A blocker or unmet dependency is identified during any feature-branch state (`planning`, `test-listing`, `red`, `green`, `refactor`). |
| **Exit Criteria** | The blocker is resolved or the dependency is met. |
| **On Entry** | The plan's previous state is recorded. The state machine auto-selects the highest-priority non-blocked plan from `/todo/` and activates it. |
| **On Exit** | The plan returns to its previous state before blocking. It re-enters the priority queue if another plan is currently active. |
| **Invariants** | Plan file remains in `/doing/`. The blocker is documented in the state file and plan file. |

#### `deployment-failure`

A CI/CD deployment to any environment (dev, test, or main) has failed.

| | |
|---|---|
| **Entry Criteria** | A deployment triggered by a merge to `dev`, `test`, or `main` fails. |
| **Exit Criteria** | The deployment failure is diagnosed, fixed, and the deployment succeeds. |
| **Invariants** | **All other work is halted.** This is the highest priority. No other plan may make progress until the deployment failure is resolved. The failed deployment is treated as a bug to fix. Recovery is by redeploying from the branch contents prior to the failed merge, then fixing the bug through the normal TDD cycle. |
| **Side Effects** | All active plans are paused. A new plan is auto-created for the deployment fix with highest priority. |

#### `idle`

No plans are active. The developer/agent has no work to do.

| | |
|---|---|
| **Entry Criteria** | No plans in `/doing/` and no plans in `/todo/`, OR all plans in `/doing/` are blocked and `/todo/` is empty. |
| **Exit Criteria** | A new plan is created or a blocker is resolved. |
| **Invariants** | State file shows no active (non-blocked) plans. |

---

## 7. Complete Transition Table

### 7.1 Normal Flow Transitions

| # | From | To | Trigger | Conditions |
|---|---|---|---|---|
| T1 | `idle` | `planning` | New plan selected from `/todo/` or new plan created | Plan file moved to `/doing/`. Feature branch created. |
| T2 | `planning` | `decomposing` | Plan identified as too large | Cannot write meaningful acceptance tests at current granularity. |
| T3 | `planning` | `test-listing` | Plan is ready for test design | Plan is specific and small enough to write test lists for. |
| T4 | `decomposing` | `idle` | Decomposition complete | Child plans created in `/todo/`. Parent moved to `/todo/` with child links. Current plan's branch may be deleted. State machine selects next plan. |
| T5 | `test-listing` | `red` | Test list complete, first test written | At least one test list has items. First test implemented as failing executable code. |
| T6 | `red` | `green` | Failing test now passes | Minimal code written. All other tests still pass. |
| T7 | `green` | `red` | Write next failing test | More items remain in test lists. Next test written and failing. |
| T8 | `green` | `refactor` | Simpler solution identified | All tests pass. Refactoring opportunity identified. |
| T9 | `green` | `pr-dev` | All test lists complete, quality gates pass | No remaining test list items. All automated tests pass. All quality metrics meet thresholds. PR auto-created. |
| T10 | `refactor` | `red` | Next test to write | Refactoring complete. More test list items remain. Next test written and failing. |
| T11 | `refactor` | `pr-dev` | All test lists complete, quality gates pass | Refactoring complete. No remaining test list items. All automated tests pass. Quality gates met. PR auto-created. |
| T12 | `pr-dev` | `on-dev` | PR merged | All CI checks passed. PR merged to `dev`. |
| T13 | `on-dev` | `pr-test` | Deployment verified | Dev deployment succeeded. Post-deployment checks pass. PR auto-created to `test`. |
| T14 | `pr-test` | `on-test` | PR merged | All CI checks passed. PR merged to `test`. |
| T15 | `on-test` | `manual-testing` | Deployment verified | Test deployment succeeded. Manual test checklist available. |
| T16 | `manual-testing` | `pr-main` | Manual tests approved | Reviewer approved all manual tests. PR auto-created to `main`. |
| T17 | `pr-main` | `complete` | PR merged and deployed | All CI checks passed. PR merged to `main`. Production deployment succeeded. |

### 7.2 Regression Transitions

| # | From | To | Trigger | Conditions |
|---|---|---|---|---|
| T18 | `refactor` | `red` | Regression detected | A previously passing test now fails during refactoring. |
| T19 | `green` | `red` | Regression detected | A previously passing test fails (e.g., flaky test manifests, environmental change). |

### 7.3 Blocker Transitions

| # | From | To | Trigger | Conditions |
|---|---|---|---|---|
| T20 | `planning` | `blocked` | Blocker identified | External dependency or impediment discovered. Previous state (`planning`) recorded. |
| T21 | `test-listing` | `blocked` | Blocker identified | Same as T20, previous state (`test-listing`) recorded. |
| T22 | `red` | `blocked` | Blocker identified | Same as T20, previous state (`red`) recorded. |
| T23 | `green` | `blocked` | Blocker identified | Same as T20, previous state (`green`) recorded. |
| T24 | `refactor` | `blocked` | Blocker identified | Same as T20, previous state (`refactor`) recorded. |
| T25 | `blocked` | (previous state) | Blocker resolved | Plan returns to its state before blocking. Re-enters priority queue. |

### 7.4 Deployment Failure Transitions

| # | From | To | Trigger | Conditions |
|---|---|---|---|---|
| T26 | `on-dev` | `deployment-failure` | Dev deployment fails | CI/CD deployment to dev environment fails. All work halted. |
| T27 | `on-test` | `deployment-failure` | Test deployment fails | CI/CD deployment to test environment fails. All work halted. |
| T28 | `pr-main` → `complete` | `deployment-failure` | Main deployment fails | CI/CD deployment to production fails. All work halted. |
| T29 | `deployment-failure` | `planning` | Fix plan created | Rollback deployed. Bug fix plan created with highest priority. Normal TDD cycle begins for the fix. |

### 7.5 Context Switch Transitions

| # | From | To | Trigger | Conditions |
|---|---|---|---|---|
| T30 | (any blocked plan) | `idle` or `planning` | Auto-select triggered | When a plan becomes blocked, state machine auto-selects highest-priority non-blocked plan from `/todo/`. If none available, transitions to `idle`. |

### 7.6 Invalid Transitions (Explicitly Prohibited)

| From | To | Reason |
|---|---|---|
| `red` | `refactor` | Cannot refactor when a test is failing. Must go green first. |
| `red` | `pr-dev` | Cannot promote code with a failing test. |
| `refactor` | `pr-dev` (with failing tests) | Regression during refactor must be fixed first. |
| `planning` | `red` | Must write test lists before writing tests. |
| `test-listing` | `green` | Cannot be green without having written and passed a test from the list. |
| `pr-dev` | `pr-test` | Must go through `on-dev` (deployment verification) first. |
| `on-test` | `pr-main` | Must go through `manual-testing` approval first. |
| Any state | Any state | While `deployment-failure` is active, no other transitions are permitted. |

---

## 8. Quality Gates

Quality gates are **hard gates** — transitions are blocked until all metrics meet their thresholds.

### 8.1 Tracked Metrics

| Metric | Description | Applies To |
|---|---|---|
| **Test Coverage** | Percentage of code covered by tests (line and branch). | All promotion transitions (T9, T11, T12–T17). |
| **Complexity** | Cyclomatic and/or cognitive complexity per function/module. | All promotion transitions. |
| **Lint/Style** | Linting rules, formatting, naming conventions. Must pass with zero violations. | All promotion transitions and refactor exit. |
| **Static Analysis / Security** | Static analysis findings, known vulnerabilities, dependency audit. Zero critical/high findings. | All promotion transitions. |

### 8.2 Metric Thresholds

Thresholds are defined per-repository in a configuration file (e.g., `.devstate/quality-gates.yml`). Example:

```yaml
quality_gates:
  coverage:
    line: 80
    branch: 75
  complexity:
    max_cyclomatic: 10
    max_cognitive: 15
  lint:
    zero_violations: true
  security:
    max_critical: 0
    max_high: 0
```

### 8.3 When Gates Are Checked

- **Before `pr-dev`** (T9, T11): All metrics must meet thresholds.
- **At every PR CI check** (T12, T14, T16, T17): CI re-validates all metrics.
- **During `refactor`**: Lint must pass. Other metrics checked at exit.

---

## 9. Branching and PR Model

### 9.1 Branch Structure

```
main                    ← production deployments
  └── test              ← test environment deployments
       └── dev          ← dev environment deployments
            ├── feature/plan-a   ← TDD work for plan A
            ├── feature/plan-b   ← TDD work for plan B
            └── fix/deploy-bug   ← deployment failure fix
```

### 9.2 Branch Rules

| Rule | Description |
|---|---|
| Feature branches are created from `dev` | All new work branches off `dev`. |
| TDD happens only on feature branches | `dev`, `test`, and `main` never receive direct commits. |
| PRs are the only way to merge | No direct pushes to `dev`, `test`, or `main`. |
| All CI checks must pass for PR merge | Automated tests, quality gates, and build must all pass. |
| PRs are auto-created | When exit criteria for the current stage are met, the state machine creates the PR. |

### 9.3 PR Lifecycle

1. **Auto-creation**: State machine creates PR with description including plan summary, test results, and quality metrics.
2. **CI validation**: All automated checks run. If any fail, the PR is not mergeable.
3. **Merge**: Upon passing checks (and manual approval for `test` → `main`), PR is merged.
4. **Deployment**: Merge triggers CI/CD deployment to the target environment.

### 9.4 Commit Rules

- State file changes are **bundled in the same commit** as the code change that triggered the transition.
- Commit messages should reference the plan and the state transition (e.g., `feat(plan-x): implement login validation [red → green]`).
- Every commit must leave the repo in a valid state file configuration.

---

## 10. Test Types and Requirements

### 10.1 Test Type Definitions

| Test Type | Scope | Execution | Required Before |
|---|---|---|---|
| **Unit Tests** | Single function/module in isolation | Automated, fast | `pr-dev` |
| **Integration Tests** | Multiple modules/services working together | Automated | `pr-dev` |
| **Property Tests** | Invariants that hold across random inputs | Automated | `pr-dev` |
| **Acceptance Tests** | User-facing behavior matches plan criteria | Automated | `pr-dev` |
| **End-to-End Tests** | Full system workflow through all layers | Automated | `pr-dev` |
| **Manual Tests** | Scenarios requiring human judgment or complex setup | Human-executed | `pr-main` (after `on-test`) |

### 10.2 Test List Requirements

- A **test list** must be written for **every test type** before any test code is written.
- Each test list item is a **single-sentence prose description** of what should be tested.
- Test lists are stored in the plan file under the appropriate heading.
- Tests are implemented one at a time from the test list, following the red → green → refactor cycle.
- The test list may be amended during development if new test cases are discovered.

### 10.3 Test Execution Order

Tests should generally be implemented in this order (within the TDD cycle):

1. Unit tests (fastest feedback)
2. Integration tests
3. Property tests
4. Acceptance tests
5. End-to-end tests
6. Manual tests (defined during test-listing, executed during `manual-testing` state)

---

## 11. Rules and Invariants

### 11.1 Core TDD Rules

1. **Only write new code when there is a failing test.** (No production code without a red test.)
2. **Only refactor when all tests are passing.** (Never refactor in a red state.)
3. **Refactor when there is a simpler solution.** (Simplicity is a goal, not optional.)
4. **Any regression immediately forces the state back to `red`.** (Regressions are highest priority within the current plan.)

### 11.2 Promotion Rules

5. **The build must be passing to merge to `dev`.** (All automated tests + quality gates.)
6. **Merging to `dev` deploys to the dev environment via CI.**
7. **Merging to `test` deploys to the test environment via CI.**
8. **Merging to `main` deploys to the production environment via CI.**
9. **PRs are only accepted into `dev`, `test`, and `main` if all build checks pass.**

### 11.3 Plan Rules

10. **Extract a sub-plan if the current plan is too big to write acceptance tests for.**
11. **Write a test list before writing any test code.** (Applies to all test types.)
12. **A parent plan cannot complete until all child plans are complete.**
13. **The state machine operates on leaf plans only.** (No TDD on plans with children.)

### 11.4 State File Rules

14. **`state.md` must always match the current state.** (Updated on every state transition.)
15. **`state.md` must only be updated via the state update tool.** (Never hand-edited.)
16. **State transitions are committed with the triggering code change.** (Bundled commits.)
17. **Git history of `state.md` is the authoritative transition log.**

### 11.5 Deployment Failure Rules

18. **Deployment failures block all work.** (Highest priority — everything stops.)
19. **Fix all bugs before working any new features.** (Deployment fix goes through normal TDD.)
20. **Rollback by redeploying from the branch contents prior to the failed merge.** (Then fix the root cause.)

### 11.6 Blocker Rules

21. **Blockers force a context switch.** (Blocked plan stays in `/doing/` with `blocked` state.)
22. **Auto-select the highest-priority non-blocked plan from `/todo/`.** (No manual selection needed.)
23. **When a blocker is resolved, the plan returns to its previous state.**

### 11.7 Work-in-Progress Rules

24. **Keep in-progress details needed between commits in `/doing/`.** (Plan files, notes, scratch work.)
25. **Keep future work details in `/todo/`.** (Queued plans, ideas, backlog.)
26. **Keep completed work details in `/done/`.** (Archived plans for reference.)

---

## 12. Concurrency Model

The state file tracks **multiple concurrent plans**, each with their own state:

- **At most one plan is actively being worked** (in a TDD state: `planning`, `test-listing`, `red`, `green`, `refactor`).
- **Multiple plans may be in promotion states** (`pr-dev`, `on-dev`, `pr-test`, `on-test`, `manual-testing`, `pr-main`) simultaneously, since these are waiting on CI/reviewers.
- **Multiple plans may be blocked** simultaneously.
- **Deployment failure overrides everything** — when active, no plan may progress.

### Priority Resolution

When the state machine needs to select the next plan:

1. If `deployment-failure` is active → work on the deployment fix plan.
2. Otherwise, select the highest-priority non-blocked plan from `/todo/`.
3. If `/todo/` is empty and all `/doing/` plans are blocked or in promotion → `idle`.

---

## 13. Tools Required

### 13.1 State Update Tool

- **Purpose**: The only authorized way to modify `state.md`.
- **Operations**: Transition state, add/remove plan, update metrics, record blocker, resolve blocker.
- **Validation**: Rejects invalid transitions (see §7.6). Validates entry criteria before allowing transition.
- **Side Effects**: Moves plan files between `/doing/`, `/todo/`, `/done/` as needed. Auto-creates PRs when promotion criteria are met.

### 13.2 State Query Tool

- **Purpose**: Programmatically query `state.md`.
- **Queries**: Current state of a plan, all active plans, all blockers, quality metrics, test list progress, global status.

### 13.3 Plan Management Tool

- **Purpose**: Create, decompose, and manage plan files.
- **Operations**: Create plan, decompose plan into children, set priority, link dependencies.

### 13.4 Quality Gate Checker

- **Purpose**: Run all quality metric checks and report pass/fail against thresholds.
- **Integration**: Called by the state update tool before promotion transitions.

### 13.5 PR Automation

- **Purpose**: Auto-create PRs with standardized descriptions when promotion criteria are met.
- **Integration**: Triggered by transitions T9, T11, T13, T16.

---

## 14. CI/CD Integration

### 14.1 GitHub Actions Required

| Workflow | Trigger | Purpose |
|---|---|---|
| **PR Checks** | PR opened/updated to `dev`, `test`, `main` | Run all automated tests, quality gates, build validation. |
| **Deploy to Dev** | Merge to `dev` | Deploy to dev environment. Report success/failure. |
| **Deploy to Test** | Merge to `test` | Deploy to test environment. Report success/failure. |
| **Deploy to Production** | Merge to `main` | Deploy to production. Report success/failure. |
| **State Validation** | Any push | Validate `state.md` format and consistency. |

### 14.2 AGENTS.md

An `AGENTS.md` file should be maintained at the repo root with instructions for AI agents, including:

- The state machine rules (reference to this document or a summary).
- How to use the state update tool.
- How to read and interpret `state.md`.
- The TDD cycle expectations.
- Quality gate thresholds.

---

## 15. State Diagram (ASCII)

```
                         ┌──────────────────────┐
                         │        idle           │
                         └──────────┬───────────┘
                                    │ T1: select/create plan
                                    ▼
                         ┌──────────────────────┐
               ┌────────►│      planning         │◄──────────────┐
               │         └──────┬───────┬───────┘               │
               │                │       │                        │
               │         T3: ready    T2: too big               │
               │                │       │                        │
               │                ▼       ▼                        │
               │    ┌───────────┐  ┌──────────────┐             │
               │    │test-listing│  │ decomposing  │             │
               │    └─────┬─────┘  └──────┬───────┘             │
               │          │               │ T4: children created │
               │   T5: first test         └──► idle              │
               │          │                                      │
               │          ▼                                      │
               │    ┌───────────┐    T18/T19: regression         │
               │    │           │◄──────────────────┐            │
               │    │    red    │                    │            │
               │    │           │──────────┐        │            │
               │    └───────────┘          │        │            │
               │          │          T6: test passes│            │
               │          │                │        │            │
               │          ▼                ▼        │            │
               │    ┌───────────┐    ┌───────────┐  │            │
               │    │  blocked  │    │   green   │  │            │
               │    └───────────┘    └──┬──┬──┬──┘  │            │
               │     T25: resolved      │  │  │     │            │
               │     ───► previous      │  │  │     │            │
               │                        │  │  │     │            │
               │           T7: next test│  │  │T8: simplify     │
               │       ┌────────────────┘  │  └──┐  │            │
               │       │    T9/T11: done   │     │  │            │
               │       │         │         │     ▼  │            │
               │       │         │         │  ┌──────────┐       │
               │       ▼         │         │  │ refactor │───────┘
               │     (red)       │         │  └──┬───┬───┘  T10: next test
               │                 │         │     │   │
               │                 ▼         │     │   │
               │         ┌──────────────┐  │     │   │
               │         │   pr-dev     │◄─┼─────┘   │
               │         └──────┬───────┘  │         │
               │                │ T12      │         │
               │                ▼          │         │
               │         ┌──────────────┐  │         │
               │         │   on-dev     │──┼── T26 ──┼──► deployment-failure
               │         └──────┬───────┘  │         │
               │                │ T13      │         │
               │                ▼          │         │
               │         ┌──────────────┐  │         │
               │         │   pr-test    │  │         │
               │         └──────┬───────┘  │         │
               │                │ T14      │         │
               │                ▼          │         │
               │         ┌──────────────┐  │         │
               │         │   on-test    │──┼── T27 ──┼──► deployment-failure
               │         └──────┬───────┘  │         │
               │                │ T15      │         │
               │                ▼          │         │
               │       ┌────────────────┐  │         │
               │       │manual-testing  │  │         │
               │       └───────┬────────┘  │         │
               │               │ T16       │         │
               │               ▼           │         │
               │         ┌──────────────┐  │         │
               │         │   pr-main    │  │         │
               │         └──────┬───────┘  │         │
               │                │ T17      │         │
               │                ▼          │         │
               │         ┌──────────────┐  │         │
    T29:       │         │   complete   │──┼── T28 ──┼──► deployment-failure
    fix plan ──┘         └──────────────┘  │         │
                                           │         │
                                           │         │
                  deployment-failure ──────┼── T29 ──┘
                  (blocks all work)        │
                                           │
```

---

## 16. Open Questions

*None at this time. All design decisions have been resolved through the requirements gathering process.*

---

## 17. Iteration Notes

This document represents the initial specification. Per the development process:

> We will iterate on the plan until there are no open questions and all of the edge cases are defined.

Future iterations may refine:

- Exact state file YAML/markdown schema
- Quality gate configuration file format
- Tool CLI interface design
- GitHub Actions workflow specifics
- AGENTS.md content
- Edge cases discovered during implementation
