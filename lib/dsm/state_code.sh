#!/usr/bin/env bash
# state_code.sh — Code machine: read/parse code-state.md

get_code_state() {
    local state_file="${REPO_ROOT}/${CODE_STATE_FILE}"
    if [[ ! -f "$state_file" ]]; then
        echo "inactive"
        return
    fi
    _parse_code_state_field "state"
}

get_code_detail() {
    local state_file="${REPO_ROOT}/${CODE_STATE_FILE}"
    [[ ! -f "$state_file" ]] && return

    local plan_id test_index test_total
    plan_id=$(_parse_code_state_field "plan_id")
    test_index=$(_parse_code_state_field "test_index")
    test_total=$(_parse_code_state_field "test_total")

    local detail=""
    if [[ -n "$test_index" && -n "$test_total" ]]; then
        detail="test ${test_index}/${test_total}"
    fi
    if [[ -n "$plan_id" ]]; then
        if [[ -n "$detail" ]]; then
            detail="${detail}, plan: ${plan_id}"
        else
            detail="plan: ${plan_id}"
        fi
    fi
    echo "$detail"
}

get_test_progress() {
    local test_index test_total
    test_index=$(_parse_code_state_field "test_index")
    test_total=$(_parse_code_state_field "test_total")
    if [[ -n "$test_index" && -n "$test_total" ]]; then
        echo "${test_index}/${test_total}"
    else
        echo "0/0"
    fi
}

does_targeted_test_fail() {
    # This would run the targeted test and check for failure
    # For now, check if code-state indicates red state
    local state
    state=$(get_code_state)
    [[ "$state" == "red" ]]
}

all_tests_pass() {
    # This would run the full test suite
    # For now, check if code-state indicates green or refactor state
    local state
    state=$(get_code_state)
    [[ "$state" == "green" || "$state" == "refactor" ]]
}

remaining_test_list_items_exist() {
    local test_index test_total
    test_index=$(_parse_code_state_field "test_index")
    test_total=$(_parse_code_state_field "test_total")
    [[ -n "$test_index" && -n "$test_total" ]] && (( test_index < test_total ))
}

regression_detected() {
    # Would compare current test results against last known passing set
    # For now, returns false (no regression detected)
    return 1
}

quality_gates_met() {
    local gates_file="${REPO_ROOT}/${QUALITY_GATES_FILE}"
    if [[ ! -f "$gates_file" ]]; then
        # No quality gates configured — pass by default
        return 0
    fi
    # Would run quality tools and compare against thresholds
    # Stub: check if code-state records passing quality
    local state_file="${REPO_ROOT}/${CODE_STATE_FILE}"
    if [[ -f "$state_file" ]]; then
        # Check for any recorded quality failures
        if grep -q "quality: fail" "$state_file" 2>/dev/null; then
            return 1
        fi
    fi
    return 0
}

# --- Internal helpers ---

_parse_code_state_field() {
    local field="$1"
    local state_file="${REPO_ROOT}/${CODE_STATE_FILE}"
    grep -oP "(?<=^${field}: ).*" "$state_file" 2>/dev/null | head -1
}
