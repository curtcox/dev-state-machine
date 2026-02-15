#!/usr/bin/env bash
# state_promote.sh — Promote machine: derive state from GitHub via gh CLI

get_promote_state() {
    if ! _gh_available; then
        echo "inactive"
        return
    fi

    local branch
    branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null)
    [[ -z "$branch" ]] && { echo "inactive"; return; }

    # Only relevant on environment branches (dev, test, main) or when checking deployment
    local env
    env=$(_branch_to_environment "$branch")

    # Check for deployment workflows
    local repo_nwo
    repo_nwo=$(get_repo_nwo)
    [[ -z "$repo_nwo" ]] && { echo "inactive"; return; }

    # Query recent deployment status
    local deploy_json
    deploy_json=$(gh api "repos/${repo_nwo}/deployments?environment=${env}&per_page=1" 2>/dev/null)

    if [[ -z "$deploy_json" || "$(echo "$deploy_json" | _json_length)" -eq 0 ]]; then
        echo "inactive"
        return
    fi

    # Get latest deployment status
    local deploy_id
    deploy_id=$(echo "$deploy_json" | _json_field 0 "id")
    [[ -z "$deploy_id" ]] && { echo "inactive"; return; }

    local status_json
    status_json=$(gh api "repos/${repo_nwo}/deployments/${deploy_id}/statuses?per_page=1" 2>/dev/null)

    if [[ -z "$status_json" || "$(echo "$status_json" | _json_length)" -eq 0 ]]; then
        echo "deploying"
        return
    fi

    local status_state
    status_state=$(echo "$status_json" | _json_field 0 "state")

    case "$status_state" in
        in_progress|queued|pending) echo "deploying" ;;
        success) echo "deployed" ;;  # Could be validating/promoted depending on checks
        failure|error) echo "failed" ;;
        inactive) echo "complete" ;;
        *) echo "inactive" ;;
    esac
}

get_promote_detail() {
    local state
    state=$(get_promote_state)
    case "$state" in
        inactive) ;;
        deploying) echo "deployment in progress" ;;
        deployed) echo "deployed, awaiting validation" ;;
        validating) echo "validation in progress" ;;
        promoted) echo "validated, ready for next environment" ;;
        failed) echo "deployment or validation failed" ;;
        complete) echo "production deployment verified" ;;
    esac
}

get_current_environment() {
    local branch
    branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null)
    _branch_to_environment "$branch"
}

is_production_deployment() {
    local env
    env=$(get_current_environment)
    [[ "$env" == "main" || "$env" == "production" ]]
}

get_next_environment() {
    local env
    env=$(get_current_environment)
    case "$env" in
        dev)  echo "test" ;;
        test) echo "main" ;;
        main) echo "" ;;  # Terminal
        *)    echo "" ;;
    esac
}

deployment_succeeded() {
    local state
    state=$(get_promote_state)
    [[ "$state" == "deployed" || "$state" == "validating" || "$state" == "promoted" || "$state" == "complete" ]]
}

deployment_failed() {
    local state
    state=$(get_promote_state)
    [[ "$state" == "failed" ]]
}

# --- Internal helpers ---

_branch_to_environment() {
    local branch="$1"
    case "$branch" in
        main|master) echo "main" ;;
        test|staging) echo "test" ;;
        dev|develop) echo "dev" ;;
        *) echo "dev" ;;  # Feature branches deploy to dev
    esac
}
