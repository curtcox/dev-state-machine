#!/usr/bin/env bash
# queries.sh — Cross-domain informational function implementations

determine_active_machine() {
    # Priority order per overview.md:
    # 1. Open PR exists → Merge
    # 2. PR merged and deployment in progress → Promote
    # 3. Feature branch exists and has test code → Code
    # 4. Otherwise → Plan

    # Check for deployment failure first — it overrides everything
    if deployment_failure_plan_exists; then
        # Deployment failure plan goes through Plan→Code→Merge→Promote
        # Determine which machine based on the fix plan's state
        :
    fi

    local merge_state
    merge_state=$(get_merge_state)
    if [[ "$merge_state" != "inactive" && "$merge_state" != "merged" ]]; then
        echo "merge"
        return
    fi

    local promote_state
    promote_state=$(get_promote_state)
    if [[ "$promote_state" != "inactive" ]]; then
        echo "promote"
        return
    fi

    local code_state
    code_state=$(get_code_state)
    if [[ "$code_state" != "inactive" ]]; then
        echo "code"
        return
    fi

    echo "plan"
}

has_feature_branch() {
    local plan_id="${1:-$(get_active_plan_id)}"
    [[ -z "$plan_id" ]] && return 1
    git -C "$REPO_ROOT" rev-parse --verify "${FEATURE_BRANCH_PREFIX}${plan_id}" &>/dev/null
}

feature_branch_has_test_code() {
    local plan_id="${1:-$(get_active_plan_id)}"
    [[ -z "$plan_id" ]] && return 1
    local branch="${FEATURE_BRANCH_PREFIX}${plan_id}"
    # Check if branch has any test files
    git -C "$REPO_ROOT" ls-tree -r --name-only "$branch" 2>/dev/null | \
        grep -qE '(_test\.|\.test\.|\.spec\.|test_|/tests/|/__tests__/)' 2>/dev/null
}

are_all_sibling_plans_complete() {
    local plan_id="${1:-$(get_active_plan_id)}"
    local plan_file
    plan_file=$(_find_plan_file "$plan_id")
    [[ -z "$plan_file" ]] && return 1

    # Read parent plan link
    local parent_id
    parent_id=$(grep -oP '(?<=^Parent Plan: )\S+' "$plan_file" 2>/dev/null)
    [[ -z "$parent_id" || "$parent_id" == "none" ]] && return 1

    local parent_file
    parent_file=$(_find_plan_file "$parent_id")
    [[ -z "$parent_file" ]] && return 1

    # Read child plan links from parent
    local all_done=true
    while IFS= read -r child_link; do
        local child_id
        child_id=$(echo "$child_link" | grep -oP '\S+\.md' | sed 's/\.md//')
        [[ -z "$child_id" ]] && continue
        if [[ ! -f "${REPO_ROOT}/${DONE_DIR}/${child_id}.md" ]]; then
            all_done=false
            break
        fi
    done < <(grep -A 50 "^## Child Plans" "$parent_file" | grep "^- " | head -20)

    [[ "$all_done" == "true" ]]
}
