# Informational Functions

## Purpose

This document catalogs all informational functions required to implement the Plan, Code, Merge, and Promote state machines. Each function answers a specific question needed to evaluate transition conditions. Functions are grouped by domain rather than by machine, since many serve multiple machines.

## Conventions

- **Determines**: The specific question the function answers.
- **How it works**: Included only where concreteness adds needed clarity.
- **⚠️ Judgment Call**: Functions that require human or agent reasoning and cannot be fully automated.

---

## 1. Active Machine Resolution

### `determine_active_machine`

**Determines**: Which state machine (Plan, Code, Merge, Promote) is currently active for a given plan.

**How it works**: Evaluates observable state in priority order:

1. Open PR exists for the plan's branch → Merge
2. PR merged and deployment in progress or pending validation → Promote
3. Feature branch exists and contains test code → Code
4. Otherwise → Plan

### `has_feature_branch`

**Determines**: Whether a feature branch exists for the given plan.

### `feature_branch_has_test_code`

**Determines**: Whether the plan's feature branch contains any test code.

**How it works**: Checks for the presence of test files on the feature branch (files matching test naming conventions or residing in test directories).

### `has_open_pr_for_branch`

**Determines**: Whether an open pull request exists for the plan's feature branch.

**How it works**: Queries GitHub PR API for open PRs with the feature branch as the head.

### `is_deployment_in_progress_or_pending`

**Determines**: Whether a deployment or post-deployment validation is underway for the merged code.

**How it works**: Queries GitHub deployment and workflow APIs for active deployment runs associated with the merge commit.

---

## 2. Plan Selection & Priority

### `has_plans_in_doing`

**Determines**: Whether any plan files currently exist in `/doing/`.

### `has_plans_in_todo`

**Determines**: Whether any plan files currently exist in `/todo/`.

### `all_plans_blocked`

**Determines**: Whether every existing plan is in a blocked state.

**How it works**: Reads `plan-state.md` and checks the state of every tracked plan.

### `get_highest_priority_non_blocked_plan`

**Determines**: Which plan should be worked on next.

**How it works**: Reads plan files from `/todo/`, filters out plans marked as blocked in `plan-state.md`, and returns the one with the highest priority value (lowest number).

### `deployment_failure_plan_exists`

**Determines**: Whether a deployment-failure plan exists that blocks all other work.

**How it works**: Checks `/todo/` and `/doing/` for plan files flagged as deployment-failure priority.

### `are_all_sibling_plans_complete`

**Determines**: Whether all child plans of a given parent plan have been completed.

**How it works**: Reads the parent plan's child plan links, then checks whether each child's plan file resides in `/done/`.

---

## 3. Plan Structure

### `get_plan_location`

**Determines**: Which directory (`/todo/`, `/doing/`, or `/done/`) contains a given plan file.

### `read_plan_metadata`

**Determines**: The contents of a plan file — goal, acceptance criteria, test lists, priority, dependencies, parent/child links.

**How it works**: Parses the plan's markdown structure to extract each section.

### `plan_has_acceptance_criteria`

**Determines**: Whether the plan file contains defined acceptance criteria.

### `plan_has_child_plans`

**Determines**: Whether the plan has been decomposed into child plans.

**How it works**: Checks the plan file's "Child Plans" section for linked children.

### `child_plans_exist_in_todo`

**Determines**: Whether all child plans listed in a parent plan actually exist as files in `/todo/`.

### ⚠️ `is_plan_too_large`

**Determines**: Whether the plan is too large to write meaningful acceptance tests at its current granularity.

Judgment call based on whether acceptance criteria can be clearly articulated, whether test descriptions can be concrete and specific, and whether the scope is decomposable into smaller pieces.

### ⚠️ `is_plan_specific_enough`

**Determines**: Whether the plan is specific and small enough to write test lists.

Judgment call based on clarity of acceptance criteria, ability to enumerate concrete test scenarios, and absence of ambiguity in requirements.

---

## 4. Test List Status

### `test_lists_complete_for_all_applicable_types`

**Determines**: Whether test lists have been written for every applicable test type (unit, integration, property, acceptance, end-to-end, manual).

**How it works**: Reads the plan file's "Test Lists" section and checks that each applicable type contains at least one prose test description.

---

## 5. Test Execution

### `does_targeted_test_fail`

**Determines**: Whether the currently targeted test fails when run.

### `all_tests_pass`

**Determines**: Whether the full test suite passes with zero failures.

### `remaining_test_list_items_exist`

**Determines**: Whether there are test list items not yet implemented as executable tests.

**How it works**: Compares the test list in the plan file against progress tracked in `code-state.md`.

### `get_test_list_progress`

**Determines**: How far through the test list the current plan has progressed (e.g., 3 of 7).

**How it works**: Reads `code-state.md` for the current test index and total count.

### `regression_detected`

**Determines**: Whether a previously passing test now fails.

**How it works**: Runs the full test suite and compares current failures against the last known passing set recorded in `code-state.md`.

### ⚠️ `is_simpler_solution_available`

**Determines**: Whether a simpler or cleaner implementation exists for the current code.

Judgment call based on code duplication, overly complex logic, naming and structure opportunities, and adherence to design principles.

### ⚠️ `is_plan_fundamentally_flawed`

**Determines**: Whether a fundamental flaw in the plan has been discovered that requires plan revision — distinct from a blocker, which is an external impediment that will be resolved.

Judgment call based on contradictory or impossible acceptance criteria, incorrect architectural assumptions, technical infeasibility, or ambiguous requirements needing clarification.

---

## 6. Quality Gates

### `quality_gates_met`

**Determines**: Whether all quality metrics meet their configured thresholds.

**How it works**: Runs quality measurement tools, reads thresholds from `.devstate/quality-gates.yml`, and compares actual values against thresholds. Returns true only if all metrics pass.

### `test_coverage_meets_threshold`

**Determines**: Whether line and branch coverage percentages meet configured minimums.

### `complexity_within_limits`

**Determines**: Whether cyclomatic and cognitive complexity are within configured maximums.

### `lint_violations_at_zero`

**Determines**: Whether there are zero lint/style violations.

### `security_findings_at_zero`

**Determines**: Whether there are zero critical or high-severity static analysis / security findings.

---

## 7. Blocker Tracking

### `blocker_exists_for_plan`

**Determines**: Whether the current plan has an unresolved blocker recorded.

**How it works**: Reads `plan-state.md` or `code-state.md` (depending on active machine) and checks for a populated blocker field.

### `blocker_resolved`

**Determines**: Whether a previously recorded blocker has been resolved.

### `get_previous_state_before_block`

**Determines**: What state the plan was in before it became blocked.

**How it works**: Reads the state file's recorded previous-state field for the blocked plan.

---

## 8. GitHub PR State

All functions in this section query the GitHub API. These are the primary inputs for the Merge machine, whose state is entirely GitHub-derived.

### `get_pr_status`

**Determines**: The current status of the PR — open, closed, or merged.

### `ci_checks_status`

**Determines**: The aggregate CI check status — all passing, any failing, or still pending.

**How it works**: Queries the PR's status check rollup from the GitHub API.

### `reviews_submitted`

**Determines**: Whether any reviews have been submitted on the PR.

### `any_reviewer_requested_changes`

**Determines**: Whether any reviewer has explicitly requested changes.

### `all_required_reviewers_approved`

**Determines**: Whether all required reviewers have submitted approving reviews.

### `unresolved_review_comments_exist`

**Determines**: Whether any review comment threads remain unresolved.

### `merge_conflicts_exist`

**Determines**: Whether the PR has merge conflicts with its target branch.

**How it works**: Queries the PR's mergeability status from the GitHub API.

### `branch_protection_satisfied`

**Determines**: Whether all branch protection rules (required checks, required reviews, etc.) are satisfied.

### `is_pr_merged`

**Determines**: Whether the PR has been merged to its target branch.

### ⚠️ `does_fix_require_significant_rework`

**Determines**: Whether addressing CI failures or review feedback requires returning to the Code machine for new tests or major changes, versus minor fixes made in place.

Judgment call based on whether new test cases are needed, whether changes affect core logic requiring a TDD cycle, and whether fixes are minor (typos, formatting) versus substantial (logic errors, missing functionality).

---

## 9. GitHub Deployment State

All functions in this section query GitHub deployment and workflow APIs. These are the primary inputs for the Promote machine, whose state is entirely GitHub-derived.

### `deployment_workflow_status`

**Determines**: The current status of the deployment workflow — running, succeeded, or failed.

**How it works**: Queries GitHub Actions API for the most recent deployment workflow run on the environment branch.

### `deployment_succeeded`

**Determines**: Whether the deployment workflow completed successfully.

### `deployment_failed`

**Determines**: Whether the deployment workflow failed.

### `health_checks_passed`

**Determines**: Whether post-deployment health checks are passing in the target environment.

### `smoke_tests_passed`

**Determines**: Whether post-deployment smoke tests passed.

**How it works**: Queries GitHub Actions for the smoke test workflow result on the environment branch.

### `manual_testing_approved`

**Determines**: Whether a designated reviewer has approved manual testing (applicable only in the test environment).

**How it works**: Checks GitHub environment protection rules for manual approval status.

### `production_monitors_green`

**Determines**: Whether production monitoring shows a healthy state after deployment to main.

**How it works**: Queries production monitoring systems for absence of critical alerts and acceptable levels on key metrics (error rate, latency, availability).

---

## 10. Environment & Promotion Path

### `get_current_environment`

**Determines**: Which environment (dev, test, main) the current deployment targets.

**How it works**: Maps the target branch of the merged PR to its environment — `dev` branch → dev, `test` branch → test, `main` branch → production.

### `is_production_deployment`

**Determines**: Whether this is the final production (main) deployment.

### `get_next_environment`

**Determines**: The next environment in the promotion path.

**How it works**: dev → test, test → main, main → none (terminal).

---

## Judgment Calls Summary

These functions require human or agent reasoning. They cannot be fully automated because they depend on interpretation, domain knowledge, or subjective assessment.

| Function | Determines | Used By |
|----------|-----------|---------|
| **`is_plan_too_large`** | Whether the plan is too large to write meaningful acceptance tests at its current granularity. | Plan (P2) |
| **`is_plan_specific_enough`** | Whether the plan is specific and small enough to write test lists. | Plan (P3) |
| **`is_simpler_solution_available`** | Whether a simpler or cleaner implementation exists for the current code. | Code (C4) |
| **`is_plan_fundamentally_flawed`** | Whether a fundamental flaw in the plan has been discovered that requires plan revision — distinct from a blocker, which is an external impediment. | Code (C14–C16) |
| **`does_fix_require_significant_rework`** | Whether addressing CI failures or review feedback requires returning to the Code machine for new tests or major changes, versus minor fixes made in place. | Merge (M7, M10) |
