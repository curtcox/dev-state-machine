# Merge State Machine

## Purpose

Governs the process of getting code reviewed and merged via pull requests. This machine's state is entirely derived from GitHub — no repo-resident state file is needed.

## State Storage

- **Derived from GitHub**: PR existence, status, review state, CI check results.
- No repo state file. Query GitHub (via `gh` CLI or API) to determine current state.
- The PR itself is the source of truth.

## States

### `pr-open`

A pull request has been created but has not yet been reviewed.

| | |
|---|---|
| **Entry Criteria** | PR created targeting an environment branch (dev, test, or main). CI checks triggered. |
| **Exit Criteria** | A reviewer begins review, OR CI checks fail requiring code fixes. |
| **Invariants** | PR exists and is open. CI checks are running or pending. |

### `reviewing`

The PR is under active review. Reviewers are examining the code.

| | |
|---|---|
| **Entry Criteria** | A reviewer has started reviewing or left comments. |
| **Exit Criteria** | Reviewer approves, requests changes, or review is abandoned. |
| **Invariants** | PR is open. At least one review is in progress. |

### `changes-requested`

A reviewer has requested changes to the code.

| | |
|---|---|
| **Entry Criteria** | A reviewer explicitly requests changes via GitHub review. |
| **Exit Criteria** | Changes are made and pushed, triggering re-review. Returns to `reviewing` or `approved`. |
| **Side Effects** | May trigger a backward transition to the Code machine if the changes require significant rework (new tests, TDD cycle). |
| **Invariants** | PR is open. At least one review has "changes requested" status. |

### `approved`

All required reviews are approved and CI checks are passing.

| | |
|---|---|
| **Entry Criteria** | All required reviewers have approved. All CI checks pass. No unresolved review comments. |
| **Exit Criteria** | PR is merged. |
| **Invariants** | PR is open. All checks green. All reviews approved. |

### `merged`

The PR has been merged to the target branch. This is the terminal state for this machine instance.

| | |
|---|---|
| **Entry Criteria** | PR merged to target environment branch. |
| **Exit Criteria** | N/A — transitions to the Promote machine. |
| **Side Effects** | Merge triggers CI/CD deployment to the target environment. |

### `blocked`

The PR cannot proceed due to CI failures, merge conflicts, or other impediments.

| | |
|---|---|
| **Entry Criteria** | CI checks fail, merge conflicts detected, or branch protection rules prevent merge. |
| **Exit Criteria** | CI failures fixed (new commits pushed), conflicts resolved, or blocking conditions removed. |
| **Side Effects** | If the fix requires new test code or significant changes, transitions back to the Code machine. |
| **Invariants** | PR is open but not mergeable. |

## Transition Table

| # | From | To | Trigger | Conditions |
|---|---|---|---|---|
| M1 | *(entry from Code or Promote machine)* | `pr-open` | PR created | Developer/agent creates PR. CI checks triggered. First instance enters from Code (feature → dev). Subsequent instances enter from Promote (dev → test, test → main). |
| M2 | `pr-open` | `reviewing` | Review started | Reviewer begins examining code. |
| M3 | `pr-open` | `blocked` | CI checks fail | Automated checks fail. Requires fixes. |
| M4 | `reviewing` | `approved` | Review approved | All required reviewers approve. CI checks pass. |
| M5 | `reviewing` | `changes-requested` | Changes requested | Reviewer requests modifications. |
| M6 | `changes-requested` | `reviewing` | Changes pushed | New commits address review feedback. Re-review triggered. |
| M7 | `changes-requested` | *(Code machine)* | Significant rework needed | Review feedback requires new tests or major changes. Back to TDD cycle. |
| M8 | `approved` | `merged` | PR merged | Merge executed. CI/CD deployment triggered. |
| M9 | `blocked` | `pr-open` | Fix pushed | New commits fix CI failures or resolve conflicts. |
| M10 | `blocked` | *(Code machine)* | Significant fix needed | CI failure requires new tests or major code changes. |
| M11 | `merged` | *(Promote machine)* | Deployment triggered | Transitions to Promote machine. |

## PR Targets and the Promotion Path

The Merge machine runs once for each stage of promotion:

| PR Target | Context | Previous Machine |
|-----------|---------|-----------------|
| `dev` | Feature branch → dev | Code machine |
| `test` | dev → test | Promote machine (after dev deployment verified) |
| `main` | test → main | Promote machine (after test deployment + manual testing verified) |

Each PR-to-merge cycle is an independent instance of the Merge machine.

## GitHub State Derivation

| Machine State | GitHub Indicators |
|---------------|-------------------|
| `pr-open` | PR is open, no reviews submitted, checks running/pending |
| `reviewing` | PR has review comments or in-progress reviews |
| `changes-requested` | PR has at least one "changes requested" review |
| `approved` | All required reviews approved, all checks passing |
| `merged` | PR status is "merged" |
| `blocked` | Checks failing, merge conflicts, or branch protection blocking |

## Concurrency

- The system is single-threaded. Only one plan is actively being worked across all machines at any given time.

## Branch Rules

- Feature branches are created from `dev`.
- TDD happens only on feature branches. `dev`, `test`, and `main` never receive direct commits.
- PRs are the only way to merge to `dev`, `test`, or `main`.
- All CI checks must pass for PR merge.
- PRs include: plan summary, test results, and quality metrics in the description.
