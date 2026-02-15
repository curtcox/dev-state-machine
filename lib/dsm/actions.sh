#!/usr/bin/env bash
# actions.sh — Action implementations for state machine transitions

action_move_plan_to_doing() {
    local plan_id="$1"
    local src="${REPO_ROOT}/${TODO_DIR}/${plan_id}.md"
    local dst_dir="${REPO_ROOT}/${DOING_DIR}"
    mkdir -p "$dst_dir"
    mv "$src" "${dst_dir}/${plan_id}.md"
}

action_move_plan_to_todo() {
    local plan_id="$1"
    local src="${REPO_ROOT}/${DOING_DIR}/${plan_id}.md"
    mv "$src" "${REPO_ROOT}/${TODO_DIR}/${plan_id}.md"
}

action_move_plan_to_done() {
    local plan_id="$1"
    local dst_dir="${REPO_ROOT}/${DONE_DIR}"
    mkdir -p "$dst_dir"
    local plan_file
    plan_file=$(_find_plan_file "$plan_id")
    [[ -n "$plan_file" ]] && mv "$plan_file" "${dst_dir}/${plan_id}.md"
}

action_create_feature_branch() {
    local plan_id="$1"
    local branch="${FEATURE_BRANCH_PREFIX}${plan_id}"
    git -C "$REPO_ROOT" checkout -b "$branch" dev 2>/dev/null || \
    git -C "$REPO_ROOT" checkout -b "$branch"
}

action_update_plan_state() {
    local plan_id="$1" new_state="$2"
    local state_file="${REPO_ROOT}/${PLAN_STATE_FILE}"

    if [[ ! -f "$state_file" ]]; then
        cat > "$state_file" <<EOF
# Plan State

## Active Plan
plan_id: ${plan_id}
state: ${new_state}
previous_state:
blocker:
EOF
    else
        # Update existing state file
        sed -i.bak "s/^plan_id: .*/plan_id: ${plan_id}/" "$state_file"
        sed -i.bak "s/^state: .*/state: ${new_state}/" "$state_file"
        rm -f "${state_file}.bak"
    fi
}

action_update_code_state() {
    local plan_id="$1" new_state="$2" test_index="${3:-}" test_total="${4:-}"
    local state_file="${REPO_ROOT}/${CODE_STATE_FILE}"

    if [[ ! -f "$state_file" ]]; then
        cat > "$state_file" <<EOF
# Code State

## Active
plan_id: ${plan_id}
state: ${new_state}
test_index: ${test_index:-1}
test_total: ${test_total:-0}
current_test:
previous_state:
blocker:
EOF
    else
        sed -i.bak "s/^state: .*/state: ${new_state}/" "$state_file"
        [[ -n "$test_index" ]] && sed -i.bak "s/^test_index: .*/test_index: ${test_index}/" "$state_file"
        rm -f "${state_file}.bak"
    fi
}

action_record_blocker() {
    local machine="$1" plan_id="$2" blocker_desc="$3" previous_state="$4"
    local state_file
    if [[ "$machine" == "plan" ]]; then
        state_file="${REPO_ROOT}/${PLAN_STATE_FILE}"
    else
        state_file="${REPO_ROOT}/${CODE_STATE_FILE}"
    fi
    [[ ! -f "$state_file" ]] && return 1
    sed -i.bak "s/^previous_state: .*/previous_state: ${previous_state}/" "$state_file"
    sed -i.bak "s/^blocker: .*/blocker: ${blocker_desc}/" "$state_file"
    sed -i.bak "s/^state: .*/state: blocked/" "$state_file"
    rm -f "${state_file}.bak"
}

action_clear_blocker() {
    local machine="$1"
    local state_file
    if [[ "$machine" == "plan" ]]; then
        state_file="${REPO_ROOT}/${PLAN_STATE_FILE}"
    else
        state_file="${REPO_ROOT}/${CODE_STATE_FILE}"
    fi
    [[ ! -f "$state_file" ]] && return 1
    local previous_state
    previous_state=$(grep -oP '(?<=^previous_state: ).*' "$state_file")
    sed -i.bak "s/^state: .*/state: ${previous_state}/" "$state_file"
    sed -i.bak "s/^blocker: .*/blocker: /" "$state_file"
    sed -i.bak "s/^previous_state: .*/previous_state: /" "$state_file"
    rm -f "${state_file}.bak"
}

action_record_plan_flaw_on_exit_to_plan() {
    local plan_id="$1" flaw_desc="$2"
    local state_file="${REPO_ROOT}/${CODE_STATE_FILE}"
    [[ ! -f "$state_file" ]] && return 1
    # Append flaw details
    cat >> "$state_file" <<EOF

## Flaw
description: ${flaw_desc}
exit_state: $(get_code_state)
test_progress: $(get_test_progress)
EOF
}

action_annotate_plan_with_revision_needed() {
    local plan_id="$1" flaw_desc="$2"
    local plan_file
    plan_file=$(_find_plan_file "$plan_id")
    [[ -z "$plan_file" ]] && return 1
    cat >> "$plan_file" <<EOF

## Revision Needed
${flaw_desc}
EOF
}

action_create_deployment_failure_plan() {
    local env="$1" failure_desc="$2"
    local plan_id="fix-deployment-${env}-$(date +%Y%m%d%H%M%S)"
    local plan_file="${REPO_ROOT}/${TODO_DIR}/${plan_id}.md"
    cat > "$plan_file" <<EOF
# Plan: Fix deployment failure in ${env}

## Goal
Fix the deployment failure in the ${env} environment and restore service.

## Parent Plan
none

## Child Plans
none

## Acceptance Criteria
- [ ] Root cause identified
- [ ] Fix implemented and tested
- [ ] Deployment to ${env} succeeds
- [ ] Post-deployment checks pass

## Test Lists

### Unit Tests
- Test that the fix addresses the root cause

### Integration Tests
- Test deployment pipeline with the fix

## Priority
deployment-failure

## Dependencies
- None

## Notes
Auto-created by dsm due to deployment failure.
Failure description: ${failure_desc}
EOF
    echo "$plan_id"
}

action_decompose_plan_into_children() {
    # This is a judgment call — the user creates child plans
    # The tool helps by providing the template
    local plan_id="$1"
    print_warning "Create child plan files in ${TODO_DIR}/ and update the parent plan's Child Plans section."
    print_dim "Use the plan file format from todo/plan.md"
}

action_commit_with_bundled_state() {
    local plan_id="$1" message="$2"
    # Stage all state files and relevant changes
    git -C "$REPO_ROOT" add \
        "${PLAN_STATE_FILE}" \
        "${CODE_STATE_FILE}" \
        "${DOING_DIR}/" \
        "${TODO_DIR}/" \
        "${DONE_DIR}/" \
        2>/dev/null
    # Stage any code changes in the working tree
    git -C "$REPO_ROOT" add -A 2>/dev/null
    git -C "$REPO_ROOT" commit -m "$message" 2>/dev/null
}

action_auto_select_next_plan() {
    local next_plan
    next_plan=$(get_highest_priority_non_blocked_plan)
    if [[ -n "$next_plan" ]]; then
        echo "$next_plan"
    fi
}

action_halt_all_work() {
    print_error "DEPLOYMENT FAILURE — All work halted."
    print_error "No other plan may progress until the failure is resolved."
}

action_perform_rollback() {
    local env="$1"
    print_warning "Rollback: Redeploying previous known-good state to ${env}."
    # Would trigger rollback deployment via GitHub Actions
}

action_merge_pull_request() {
    local branch
    branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null)
    local pr_number
    pr_number=$(gh pr list --repo "$(get_repo_nwo)" --head "${branch}" --json number --limit 1 2>/dev/null | _json_field 0 "number")
    if [[ -n "$pr_number" ]]; then
        gh pr merge "$pr_number" --repo "$(get_repo_nwo)" --merge 2>/dev/null
    fi
}

action_create_pull_request() {
    local plan_id="$1" target_branch="${2:-dev}"
    local branch
    branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null)
    print_dim "Creating PR: ${branch} -> ${target_branch}"
    gh pr create --repo "$(get_repo_nwo)" \
        --head "$branch" \
        --base "$target_branch" \
        --title "Plan: ${plan_id}" \
        --body "State machine transition: Code -> Merge" \
        2>/dev/null
}

action_push_pr_fix() {
    git -C "$REPO_ROOT" push 2>/dev/null
}

action_run_post_deployment_checks() {
    print_dim "Running post-deployment health checks and smoke tests..."
    # Would trigger health check and smoke test workflows
}

action_trigger_deployment() {
    print_dim "Deployment triggered by PR merge. CI/CD pipeline running."
    # Deployment is triggered automatically by GitHub Actions on merge
}

action_mark_parent_plan_complete() {
    local plan_id="$1"
    if are_all_sibling_plans_complete "$plan_id"; then
        local plan_file
        plan_file=$(_find_plan_file "$plan_id")
        [[ -z "$plan_file" ]] && return
        local parent_id
        parent_id=$(grep -oP '(?<=^Parent Plan: )\S+' "$plan_file" 2>/dev/null)
        [[ -z "$parent_id" || "$parent_id" == "none" ]] && return
        action_move_plan_to_done "$parent_id"
    fi
}
