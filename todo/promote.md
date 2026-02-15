# Promote State Machine

## Purpose

Governs the deployment of code through environments (dev → test → main/production) and validation at each stage. This machine's state is entirely derived from GitHub — no repo-resident state file is needed.

## State Storage

- **Derived from GitHub**: Deployment status, CI/CD pipeline results, environment health checks.
- No repo state file. Query GitHub (via `gh` CLI or API) to determine current state.
- GitHub deployments and Actions workflow runs are the source of truth.

## States

### `deploying`

CI/CD is deploying code to the target environment.

| | |
|---|---|
| **Entry Criteria** | PR merged to an environment branch. CI/CD deployment pipeline triggered. |
| **Exit Criteria** | Deployment succeeds or fails. |
| **Invariants** | CI/CD pipeline is running. The target branch contains the merged code. |

### `deployed`

Code has been successfully deployed to the target environment.

| | |
|---|---|
| **Entry Criteria** | CI/CD deployment completed successfully. |
| **Exit Criteria** | Post-deployment validation begins. |
| **Invariants** | The environment is running the new code. |

### `validating`

Post-deployment checks are running. For the test environment, this includes manual testing.

| | |
|---|---|
| **Entry Criteria** | Code deployed successfully. Post-deployment checks initiated. |
| **Exit Criteria** | All validation passes (automated checks + manual testing if applicable), OR validation fails. |
| **Invariants** | Environment is running and accessible. |

#### Validation by Environment

| Environment | Automated Checks | Manual Testing |
|-------------|-----------------|----------------|
| dev | Post-deployment health checks, smoke tests | Not required |
| test | Post-deployment health checks, smoke tests | Required. Designated reviewer executes manual test checklist and explicitly approves. |
| main | Post-deployment health checks, smoke tests, production monitors | Not required (manual testing done in test) |

### `failed`

Deployment or validation has failed.

| | |
|---|---|
| **Entry Criteria** | Deployment pipeline fails, OR post-deployment checks fail, OR manual testing reveals issues. |
| **Exit Criteria** | Failure is diagnosed and a fix plan is created. |
| **Side Effects** | **All other work is halted.** This is the highest priority. Rollback deployed from branch contents prior to the failed merge. A new highest-priority plan is auto-created for the fix, entering the Plan machine. |
| **Invariants** | The environment is rolled back to its previous known-good state. No other plan may progress until the failure is resolved. |

### `promoted`

Validation passed. Code is ready to advance to the next environment.

| | |
|---|---|
| **Entry Criteria** | All validation checks pass for the current environment. |
| **Exit Criteria** | PR created for next environment (transitions to Merge machine), OR this was production and the plan is complete. |
| **Invariants** | Current environment is healthy and running validated code. |

### `complete`

Code has been deployed and validated in production. Terminal state for the plan.

| | |
|---|---|
| **Entry Criteria** | Code deployed to production (main). All post-deployment checks pass. |
| **Exit Criteria** | N/A — terminal state. |
| **Side Effects** | Plan file moved from `/doing/` to `/done/`. If this plan has a parent, check if all siblings are complete; if so, mark parent as complete. |

## Transition Table

| # | From | To | Trigger | Conditions |
|---|---|---|---|---|
| R1 | *(entry from Merge machine)* | `deploying` | PR merged | CI/CD deployment pipeline triggered for target environment. |
| R2 | `deploying` | `deployed` | Deployment succeeds | CI/CD pipeline completes successfully. |
| R3 | `deploying` | `failed` | Deployment fails | CI/CD pipeline fails. All work halted. |
| R4 | `deployed` | `validating` | Checks initiated | Post-deployment health checks and/or manual testing begins. |
| R5 | `validating` | `promoted` | Validation passes | All automated checks pass. Manual testing approved (if applicable). |
| R6 | `validating` | `failed` | Validation fails | Health checks fail or manual testing reveals issues. |
| R7 | `promoted` | *(Merge machine)* | PR for next environment | If not yet in production: PR auto-created for next environment branch. |
| R8 | `promoted` | `complete` | Production validated | This was the main/production deployment. Plan is done. |
| R9 | `failed` | *(Plan machine)* | Fix plan created | Rollback deployed. High-priority fix plan enters the Plan machine. |

## Promotion Path

The Promote machine runs once for each environment in the pipeline:

```
Merge (→dev) → Promote (dev) → Merge (→test) → Promote (test) → Merge (→main) → Promote (main) → complete
```

Each environment pass is an independent instance:

| Instance | Target Environment | Manual Testing? | Next Step |
|----------|-------------------|-----------------|-----------|
| 1st | dev | No | Create PR to test (→ Merge machine) |
| 2nd | test | Yes | Create PR to main (→ Merge machine) |
| 3rd | main (production) | No | `complete` |

## GitHub State Derivation

| Machine State | GitHub Indicators |
|---------------|-------------------|
| `deploying` | Deployment workflow running, status "in_progress" |
| `deployed` | Deployment workflow completed successfully |
| `validating` | Post-deploy check workflows running, or awaiting manual approval |
| `failed` | Deployment workflow failed, or post-deploy checks failed |
| `promoted` | All checks passed, environment healthy |
| `complete` | Production deployment verified, all monitors green |

## Concurrency

- The system is single-threaded. Only one plan is actively being worked across all machines at any given time.

## Deployment Failure Rules

1. **Deployment failures block all work.** This is the highest priority — everything stops.
2. **Rollback first.** Redeploy from the branch contents prior to the failed merge.
3. **Then fix through normal process.** A new plan is auto-created with highest priority and flows through Plan → Code → Merge → Promote like any other work.
4. **No shortcuts.** The fix goes through the full TDD cycle. No direct pushes, no skipping environments.

## Environment Branch Structure

```
main                    ← production deployments
  └── test              ← test environment deployments
       └── dev          ← dev environment deployments
            ├── feature/plan-a   ← TDD work for plan A
            └── feature/plan-b   ← TDD work for plan B
```
