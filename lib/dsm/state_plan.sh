#!/usr/bin/env bash
# state_plan.sh — Plan machine: read/parse plan-state.md

get_plan_state() {
    local state_file="${REPO_ROOT}/${PLAN_STATE_FILE}"
    if [[ ! -f "$state_file" ]]; then
        # Derive from filesystem
        if has_plans_in_doing; then
            echo "planning"  # Default if state file missing but plan in doing
        elif has_plans_in_todo; then
            echo "idle"
        else
            echo "idle"
        fi
        return
    fi
    _parse_plan_state_field "state"
}

get_plan_detail() {
    local plan_id
    plan_id=$(get_active_plan_id)
    if [[ -n "$plan_id" ]]; then
        echo "plan: ${plan_id}"
    fi
}

get_active_plan_id() {
    local state_file="${REPO_ROOT}/${PLAN_STATE_FILE}"
    if [[ -f "$state_file" ]]; then
        _parse_plan_state_field "plan_id"
        return
    fi
    # Fallback: first file in /doing/
    local doing_dir="${REPO_ROOT}/${DOING_DIR}"
    if [[ -d "$doing_dir" ]]; then
        local first_plan
        first_plan=$(ls -1 "$doing_dir"/*.md 2>/dev/null | head -1)
        if [[ -n "$first_plan" ]]; then
            basename "$first_plan" .md
        fi
    fi
}

has_plans_in_doing() {
    local doing_dir="${REPO_ROOT}/${DOING_DIR}"
    [[ -d "$doing_dir" ]] && ls -1 "$doing_dir"/*.md &>/dev/null
}

has_plans_in_todo() {
    local todo_plan_dir="${REPO_ROOT}/${TODO_DIR}"
    # Only count plan files, not documentation files (which have known names)
    local count=0
    if [[ -d "$todo_plan_dir" ]]; then
        for f in "$todo_plan_dir"/*.md; do
            [[ ! -f "$f" ]] && continue
            local base
            base=$(basename "$f")
            # Skip known documentation files
            case "$base" in
                overview.md|plan.md|code.md|merge.md|promote.md|\
                informational_functions.md|actions.md)
                    continue ;;
            esac
            # Check if it looks like a plan file (has "# Plan:" header)
            if head -1 "$f" 2>/dev/null | grep -q "^# Plan:"; then
                ((count++))
            fi
        done
    fi
    [[ $count -gt 0 ]]
}

all_plans_blocked() {
    local state_file="${REPO_ROOT}/${PLAN_STATE_FILE}"
    if [[ ! -f "$state_file" ]]; then
        return 1  # No state file means nothing is blocked
    fi
    # Check if every plan in the state file has state "blocked"
    local total=0 blocked=0
    while IFS='|' read -r _ _ state _ _; do
        state=$(echo "$state" | xargs)  # trim whitespace
        [[ -z "$state" || "$state" == "State" ]] && continue
        ((total++))
        [[ "$state" == "blocked" ]] && ((blocked++))
    done < <(grep "^|" "$state_file" | tail -n +3)  # skip header rows
    [[ $total -gt 0 && $total -eq $blocked ]]
}

plan_has_acceptance_criteria() {
    local plan_id="${1:-$(get_active_plan_id)}"
    local plan_file
    plan_file=$(_find_plan_file "$plan_id")
    [[ -n "$plan_file" ]] && grep -q "^## Acceptance Criteria" "$plan_file" && \
        grep -A 20 "^## Acceptance Criteria" "$plan_file" | grep -q "^\- \["
}

test_lists_complete_for_all_applicable_types() {
    local plan_id="${1:-$(get_active_plan_id)}"
    local plan_file
    plan_file=$(_find_plan_file "$plan_id")
    [[ -z "$plan_file" ]] && return 1

    # Check that at least one test type has entries
    local has_any=false
    for section in "Unit Tests" "Integration Tests" "Property Tests" \
                   "Acceptance Tests" "End-to-End Tests" "Manual Tests"; do
        if grep -q "^### ${section}" "$plan_file"; then
            # Check if there's at least one list item under this section
            if grep -A 20 "^### ${section}" "$plan_file" | grep -q "^- "; then
                has_any=true
            fi
        fi
    done
    [[ "$has_any" == "true" ]]
}

deployment_failure_plan_exists() {
    # Check for plan files with deployment-failure priority
    for dir in "${REPO_ROOT}/${TODO_DIR}" "${REPO_ROOT}/${DOING_DIR}"; do
        [[ ! -d "$dir" ]] && continue
        for f in "$dir"/*.md; do
            [[ ! -f "$f" ]] && continue
            if grep -q "deployment-failure" "$f" 2>/dev/null; then
                return 0
            fi
        done
    done
    return 1
}

get_highest_priority_non_blocked_plan() {
    local best_id="" best_priority=999
    local todo_dir="${REPO_ROOT}/${TODO_DIR}"
    [[ ! -d "$todo_dir" ]] && return

    for f in "$todo_dir"/*.md; do
        [[ ! -f "$f" ]] && continue
        # Skip documentation files
        local base
        base=$(basename "$f")
        case "$base" in
            overview.md|plan.md|code.md|merge.md|promote.md|\
            informational_functions.md|actions.md)
                continue ;;
        esac
        # Must be a plan file
        head -1 "$f" 2>/dev/null | grep -q "^# Plan:" || continue
        # Extract priority
        local priority
        priority=$(grep -oP '(?<=^Priority: )\d+' "$f" 2>/dev/null || echo "")
        # Also try bracket format
        [[ -z "$priority" ]] && priority=$(grep -oP '(?<=^\[)\d+(?=\])' "$f" 2>/dev/null || echo "")
        [[ -z "$priority" ]] && priority=5  # Default low priority
        if (( priority < best_priority )); then
            best_priority=$priority
            best_id=$(basename "$f" .md)
        fi
    done
    echo "$best_id"
}

# --- Internal helpers ---

_parse_plan_state_field() {
    local field="$1"
    local state_file="${REPO_ROOT}/${PLAN_STATE_FILE}"
    grep -oP "(?<=^${field}: ).*" "$state_file" 2>/dev/null | head -1
}

_find_plan_file() {
    local plan_id="$1"
    [[ -z "$plan_id" ]] && return
    for dir in "${REPO_ROOT}/${DOING_DIR}" "${REPO_ROOT}/${TODO_DIR}" "${REPO_ROOT}/${DONE_DIR}"; do
        local f="${dir}/${plan_id}.md"
        if [[ -f "$f" ]]; then
            echo "$f"
            return
        fi
    done
}
