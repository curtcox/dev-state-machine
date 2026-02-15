# Actions

## Purpose

This document catalogs all actions (mutations, side effects, state changes) required to implement the Plan, Code, Merge, and Promote state machines. Each action changes the state of the system. Actions are grouped by domain rather than by machine, since many are shared across machines.

This is the companion to [Informational Functions](informational_functions.md), which catalogs read-only queries. Together they form the complete operational interface.

## Conventions

- **What it does**: Brief description of the mutation.
- **How it works**: Included only where concreteness adds needed clarity.
- **⚠️ Human/Agent Action**: Actions that require human or agent judgment and cannot be fully automated.

---

## 1. Plan File Management

### ⚠️ `create_plan_file`

**What it does**: Creates a new plan file in `/todo/` with the standard markdown structure.

**How it works**: Generates a markdown file with sections for Goal, Parent Plan, Child Plans, Acceptance Criteria, Test Lists (by type), Priority, Dependencies, and Notes.

### `move_plan_to_doing`

**What it does**: Moves a plan file from `/todo/` to `/doing/` when work begins on it.

### `move_plan_to_todo`

**What it does**: Moves a plan file from `/doing/` back to `/todo/`.

**How it works**: Used when decomposition completes (parent returns to `/todo/` with child links) or when the system switches to a different plan.

### `move_plan_to_done`

**What it does**: Archives a completed plan by moving it from `/doing/` to `/done/`.

### ⚠️ `write_acceptance_criteria`

**What it does**: Writes or updates the Acceptance Criteria section of a plan file.

### ⚠️ `write_test_lists`

**What it does**: Populates the Test Lists section of a plan file with prose descriptions for all applicable test types.

**How it works**: Each test list item is a single-sentence prose description. Applicable types are: unit, integration, property, acceptance, end-to-end, and manual.

### ⚠️ `decompose_plan_into_children`

**What it does**: Breaks a too-large plan into smaller child plans.

**How it works**: Creates new plan files in `/todo/` for each child. Updates the parent plan's Child Plans section with links to the children. Moves the parent back to `/todo/`.

### `annotate_plan_with_revision_needed`

**What it does**: Adds a "Revision Needed" section to a plan file describing a discovered flaw.

**How it works**: Appends a section to the plan markdown recording why the plan needs revision. Triggered when the Code machine discovers a fundamental plan flaw (C14–C16).

### `create_deployment_failure_plan`

**What it does**: Auto-creates a highest-priority plan to fix a deployment failure.

**How it works**: Creates a new plan file in `/todo/` flagged with deployment-failure priority. Describes the failure symptoms and the affected environment. All other work is blocked until this plan completes.

### `mark_parent_plan_complete`

**What it does**: Moves a parent plan to `/done/` when all its child plans are complete.

**How it works**: Checks if all child plans are in `/done/`. If so, moves the parent plan file to `/done/`. Triggered as a side effect when any child plan completes (Promote R8).

---

## 2. State File Management

### `update_plan_state`

**What it does**: Updates `plan-state.md` to reflect the current state of one or more plans.

**How it works**: Records which plans exist, their current state (idle, planning, decomposing, test-listing, ready, blocked), priority, and blockers. Bundled in the same commit as the triggering change.

### `update_code_state`

**What it does**: Updates `code-state.md` to reflect the current TDD state.

**How it works**: Records current state (red, green, refactor), the test being worked, test list progress (e.g., 3/7), quality metrics, and blocker details. Bundled in the same commit as the triggering code change.

### `record_blocker`

**What it does**: Writes blocker details into the appropriate state file and plan file.

**How it works**: Records the blocker description, the plan's previous state before blocking, and the plan ID. Used by both Plan (P7–P9) and Code (C10–C12) machines.

### `clear_blocker`

**What it does**: Removes blocker information from the state file when the blocker is resolved.

**How it works**: Clears blocker fields and restores the plan's previous state. Triggered by Plan P10 and Code C13.

### `record_plan_flaw_on_exit_to_plan`

**What it does**: Records discovered plan flaw details in `code-state.md` when exiting the Code machine.

**How it works**: Records the flaw description, the TDD state at time of exit, and test list progress (e.g., "3/7 tests implemented"). Triggered by Code C14–C16.

---

## 3. Git Operations

### `create_feature_branch`

**What it does**: Creates a new feature branch from `dev` for a plan.

**How it works**: Branches from `dev` with naming convention `feature/plan-<id>`. Triggered when a plan enters the planning state (P1).

### `commit_with_bundled_state`

**What it does**: Creates a git commit that bundles state file changes with the triggering change.

**How it works**: Stages the triggering change (code, plan file, test file) together with the state file change (`plan-state.md` or `code-state.md`), then commits. Commit message references the plan and state transition (e.g., `feat(plan-x): implement login validation [red → green]`). Every commit must leave the repo in a valid state configuration.

### `push_to_remote`

**What it does**: Pushes committed changes from the local branch to the remote repository.

---

## 4. Test & Code Authoring

### ⚠️ `write_failing_test`

**What it does**: Implements the next test from the test list as executable code that fails.

**How it works**: Translates a prose test description from the plan's test list into executable test code. The test must fail when run. Triggered at Plan→Code entry (C1) and during the TDD cycle (C3, C6).

### ⚠️ `write_production_code`

**What it does**: Writes minimal production code to make the currently failing test pass.

**How it works**: Implements only enough logic to satisfy the targeted test. No functionality beyond what the test requires. Triggered by Code C2 (red → green).

### ⚠️ `refactor_code`

**What it does**: Improves code structure, readability, or design without changing behavior.

**How it works**: Modifies production or test code while all tests continue to pass. No new functionality added. No new tests written. Triggered by Code C4 (green → refactor).

---

## 5. Pull Request Operations

### ⚠️ `create_pull_request`

**What it does**: Creates a GitHub pull request targeting an environment branch.

**How it works**: PR description includes plan summary, test results, and quality metrics. Target branch depends on context: feature→dev (from Code machine, C5/C7), dev→test or test→main (from Promote machine, R7).

### ⚠️ `push_pr_fix`

**What it does**: Pushes new commits to an open PR to address review feedback or fix CI failures.

**How it works**: Commits changes and pushes to the feature branch. The PR updates automatically. Triggered by Merge M6 (addressing review feedback) and M9 (fixing CI failures).

### `merge_pull_request`

**What it does**: Merges an approved PR into its target environment branch.

**How it works**: Executed when all required reviews are approved, all CI checks pass, and branch protection rules are satisfied. Triggers CI/CD deployment to the target environment (Merge M8).

### ⚠️ `submit_review`

**What it does**: A reviewer examines the PR code and submits a review — approve, request changes, or comment.

### ⚠️ `address_review_feedback`

**What it does**: Modifies code in response to reviewer comments or change requests.

**How it works**: Makes changes, commits, and pushes. If the feedback requires significant rework (new tests, major logic changes), transitions back to the Code machine instead (M7).

---

## 6. Deployment & Validation

### `trigger_deployment`

**What it does**: Initiates CI/CD deployment to the target environment.

**How it works**: Automatically triggered when a PR is merged to an environment branch. The CI/CD pipeline begins the deployment workflow (Merge M11 → Promote R1).

### `run_post_deployment_checks`

**What it does**: Executes automated health checks and smoke tests against the deployed environment.

**How it works**: Runs after successful deployment. Includes health endpoint checks and a smoke test suite. Applies to all environments (dev, test, main). Triggered during Promote validation (R4).

### ⚠️ `execute_manual_testing`

**What it does**: A designated reviewer performs manual testing from the plan's manual test checklist.

**How it works**: Required only in the test environment. The reviewer executes each manual test item and records results. Blocks promotion until explicitly approved (Promote R5).

### ⚠️ `approve_manual_testing`

**What it does**: A designated reviewer explicitly approves that manual testing passed.

**How it works**: Approval recorded via GitHub environment protection rules. Required for promotion from test to main.

### `perform_rollback`

**What it does**: Reverts the environment to its previous known-good state after a deployment failure.

**How it works**: Redeploys from the branch contents prior to the failed merge. Triggered immediately when deployment or validation fails (Promote R9, before creating the fix plan).

### `run_ci_checks`

**What it does**: Executes all CI checks (tests, quality gates, security scans) on a PR.

**How it works**: Triggered automatically by PR creation or update. Runs the full check suite. Results determine Merge state transitions (M3, M4, M9).

---

## 7. Orchestration

### `auto_select_next_plan`

**What it does**: Selects the highest-priority non-blocked plan to work on.

**How it works**: If a deployment-failure plan exists, selects that. Otherwise reads plans from `/todo/`, filters out blocked plans, and selects highest priority (lowest number). If all plans are blocked and `/todo/` is empty, enters idle. Triggered when a plan is blocked (P7–P9), decomposition completes (P4), or a plan finishes.

### `halt_all_work`

**What it does**: Blocks all plan progress except the deployment-failure fix plan.

**How it works**: No plan may advance through any state machine until the deployment failure is resolved. Triggered when Promote enters failed state (R3, R6).

### `resume_normal_work`

**What it does**: Clears the deployment-failure halt and allows normal priority-based plan selection.

**How it works**: Triggered when the deployment-failure plan completes its full cycle through all four machines.

---

## Human/Agent Actions Summary

These actions require human or agent judgment and explicit invocation. They are marked with ⚠️ in the sections above.

| Action | What it does | Used By |
|--------|-------------|---------|
| **`create_plan_file`** | Creates a new plan file with standard structure. | Plan (P1) |
| **`write_acceptance_criteria`** | Writes acceptance criteria for a plan. | Plan (planning state) |
| **`write_test_lists`** | Writes prose test descriptions for all applicable types. | Plan (P5) |
| **`decompose_plan_into_children`** | Breaks a large plan into smaller child plans. | Plan (P2→P4) |
| **`write_failing_test`** | Implements a test from the test list as failing code. | Code (C1, C3, C6) |
| **`write_production_code`** | Writes minimal code to make the failing test pass. | Code (C2) |
| **`refactor_code`** | Improves code without changing behavior. | Code (C4) |
| **`create_pull_request`** | Creates a PR targeting an environment branch. | Code→Merge (C5, C7), Promote→Merge (R7) |
| **`push_pr_fix`** | Pushes commits to address review feedback or CI failures. | Merge (M6, M9) |
| **`submit_review`** | Reviews PR code and submits verdict. | Merge (M2, M4, M5) |
| **`address_review_feedback`** | Modifies code in response to review comments. | Merge (M6) |
| **`execute_manual_testing`** | Performs manual tests in the test environment. | Promote (R5, test env only) |
| **`approve_manual_testing`** | Approves that manual testing passed. | Promote (R5, test env only) |
| **`identify_blocker`** | Recognizes an external impediment to progress. | Plan (P7–P9), Code (C10–C12) |
| **`resolve_blocker`** | Clears a blocker when the impediment is removed. | Plan (P10), Code (C13) |

## Automated Side Effects Summary

These actions happen automatically as part of state transitions or system events:

| Action | Triggered By |
|--------|-------------|
| **`update_plan_state`** | Every Plan machine transition (bundled in commit) |
| **`update_code_state`** | Every Code machine transition (bundled in commit) |
| **`record_blocker`** | Entry to blocked state (P7–P9, C10–C12) |
| **`clear_blocker`** | Blocker resolution (P10, C13) |
| **`record_plan_flaw_on_exit_to_plan`** | Code→Plan backward transition (C14–C16) |
| **`annotate_plan_with_revision_needed`** | Code→Plan backward transition (C14–C16) |
| **`create_deployment_failure_plan`** | Deployment or validation failure (R3, R6→R9) |
| **`move_plan_to_doing`** | Plan selected for work (P1) |
| **`move_plan_to_todo`** | Decomposition complete (P4) |
| **`move_plan_to_done`** | Production deployment validated (R8) |
| **`mark_parent_plan_complete`** | Child plan completion when all siblings done (R8) |
| **`create_feature_branch`** | Plan enters planning state (P1) |
| **`trigger_deployment`** | PR merged to environment branch (M8→R1) |
| **`run_post_deployment_checks`** | Deployment succeeds (R2→R4) |
| **`run_ci_checks`** | PR created or updated (M1, M6, M9) |
| **`perform_rollback`** | Deployment or validation failure (R9) |
| **`halt_all_work`** | Promote enters failed state (R3, R6) |
| **`resume_normal_work`** | Deployment-failure plan completes |
| **`auto_select_next_plan`** | Plan blocked (P7–P9), decomposition done (P4), plan completes |
