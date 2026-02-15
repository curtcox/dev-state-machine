#!/usr/bin/env bash
# transitions.sh — Transition table, eligibility, resolution

# Transition metadata stored in associative arrays
declare -gA T_FROM T_TO T_DESC T_ACTIONS T_PRE T_POST T_JUDGMENT T_USER_ACTION T_MACHINE

_init_transitions() {
    # --- Plan Machine ---
    T_MACHINE[P1]="plan";  T_FROM[P1]="idle";          T_TO[P1]="planning"
    T_DESC[P1]="Select plan and begin planning"
    T_ACTIONS[P1]="move_plan_to_doing create_feature_branch update_plan_state commit_with_bundled_state"
    T_PRE[P1]="has_plans_in_todo"
    T_POST[P1]="has_plans_in_doing has_feature_branch"
    T_JUDGMENT[P1]="false"

    T_MACHINE[P2]="plan";  T_FROM[P2]="planning";      T_TO[P2]="decomposing"
    T_DESC[P2]="Plan is too large, begin decomposition"
    T_ACTIONS[P2]="update_plan_state commit_with_bundled_state"
    T_PRE[P2]=""
    T_POST[P2]=""
    T_JUDGMENT[P2]="true"
    T_USER_ACTION[P2]="Determine if this plan is too large to write meaningful acceptance tests"

    T_MACHINE[P3]="plan";  T_FROM[P3]="planning";      T_TO[P3]="test-listing"
    T_DESC[P3]="Plan is specific enough, begin writing test lists"
    T_ACTIONS[P3]="update_plan_state commit_with_bundled_state"
    T_PRE[P3]=""
    T_POST[P3]=""
    T_JUDGMENT[P3]="true"
    T_USER_ACTION[P3]="Confirm this plan is specific and small enough to write test lists"

    T_MACHINE[P4]="plan";  T_FROM[P4]="decomposing";   T_TO[P4]="idle"
    T_DESC[P4]="Decomposition complete, child plans created"
    T_ACTIONS[P4]="decompose_plan_into_children move_plan_to_todo update_plan_state auto_select_next_plan commit_with_bundled_state"
    T_PRE[P4]=""
    T_POST[P4]=""
    T_JUDGMENT[P4]="true"
    T_USER_ACTION[P4]="Create child plan files and update parent with child links"

    T_MACHINE[P5]="plan";  T_FROM[P5]="test-listing";  T_TO[P5]="ready"
    T_DESC[P5]="Test lists complete for all applicable types"
    T_ACTIONS[P5]="update_plan_state commit_with_bundled_state"
    T_PRE[P5]="test_lists_complete_for_all_applicable_types"
    T_POST[P5]="plan_has_acceptance_criteria test_lists_complete_for_all_applicable_types"
    T_JUDGMENT[P5]="false"

    T_MACHINE[P6]="plan";  T_FROM[P6]="ready";         T_TO[P6]="[Code:red]"
    T_DESC[P6]="Write first failing test, exit to Code machine"
    T_ACTIONS[P6]="write_failing_test update_code_state update_plan_state commit_with_bundled_state"
    T_PRE[P6]="plan_has_acceptance_criteria test_lists_complete_for_all_applicable_types"
    T_POST[P6]="does_targeted_test_fail"
    T_JUDGMENT[P6]="true"
    T_USER_ACTION[P6]="Write the first failing test from the test list"

    T_MACHINE[P7]="plan";  T_FROM[P7]="planning";      T_TO[P7]="blocked"
    T_DESC[P7]="Blocker identified during planning"
    T_ACTIONS[P7]="record_blocker update_plan_state auto_select_next_plan commit_with_bundled_state"
    T_PRE[P7]=""
    T_POST[P7]=""
    T_JUDGMENT[P7]="true"
    T_USER_ACTION[P7]="Describe the blocker or unmet dependency"

    T_MACHINE[P8]="plan";  T_FROM[P8]="decomposing";   T_TO[P8]="blocked"
    T_DESC[P8]="Blocker identified during decomposition"
    T_ACTIONS[P8]="record_blocker update_plan_state auto_select_next_plan commit_with_bundled_state"
    T_PRE[P8]=""
    T_POST[P8]=""
    T_JUDGMENT[P8]="true"
    T_USER_ACTION[P8]="Describe the blocker or unmet dependency"

    T_MACHINE[P9]="plan";  T_FROM[P9]="test-listing";  T_TO[P9]="blocked"
    T_DESC[P9]="Blocker identified during test listing"
    T_ACTIONS[P9]="record_blocker update_plan_state auto_select_next_plan commit_with_bundled_state"
    T_PRE[P9]=""
    T_POST[P9]=""
    T_JUDGMENT[P9]="true"
    T_USER_ACTION[P9]="Describe the blocker or unmet dependency"

    T_MACHINE[P10]="plan"; T_FROM[P10]="blocked";      T_TO[P10]="[previous]"
    T_DESC[P10]="Blocker resolved, resume previous state"
    T_ACTIONS[P10]="clear_blocker update_plan_state commit_with_bundled_state"
    T_PRE[P10]=""
    T_POST[P10]=""
    T_JUDGMENT[P10]="true"
    T_USER_ACTION[P10]="Confirm the blocker has been resolved"

    T_MACHINE[P11]="plan"; T_FROM[P11]="[Code]";       T_TO[P11]="planning"
    T_DESC[P11]="Return from Code machine — fundamental plan flaw discovered"
    T_ACTIONS[P11]="record_plan_flaw_on_exit_to_plan annotate_plan_with_revision_needed update_plan_state update_code_state commit_with_bundled_state"
    T_PRE[P11]=""
    T_POST[P11]=""
    T_JUDGMENT[P11]="true"
    T_USER_ACTION[P11]="Describe the fundamental flaw discovered in the plan"

    # --- Code Machine ---
    T_MACHINE[C1]="code";  T_FROM[C1]="[Plan:ready]";  T_TO[C1]="red"
    T_DESC[C1]="Entry from Plan — first failing test written"
    T_ACTIONS[C1]="write_failing_test update_code_state commit_with_bundled_state"
    T_PRE[C1]=""
    T_POST[C1]="does_targeted_test_fail"
    T_JUDGMENT[C1]="true"
    T_USER_ACTION[C1]="Write the first failing test from the test list"

    T_MACHINE[C2]="code";  T_FROM[C2]="red";           T_TO[C2]="green"
    T_DESC[C2]="Make failing test pass with minimal code"
    T_ACTIONS[C2]="write_production_code update_code_state commit_with_bundled_state"
    T_PRE[C2]="does_targeted_test_fail"
    T_POST[C2]="all_tests_pass"
    T_JUDGMENT[C2]="true"
    T_USER_ACTION[C2]="Write minimal production code to make the targeted test pass"

    T_MACHINE[C3]="code";  T_FROM[C3]="green";         T_TO[C3]="red"
    T_DESC[C3]="Write next failing test"
    T_ACTIONS[C3]="write_failing_test update_code_state commit_with_bundled_state"
    T_PRE[C3]="remaining_test_list_items_exist"
    T_POST[C3]="does_targeted_test_fail"
    T_JUDGMENT[C3]="true"
    T_USER_ACTION[C3]="Write the next failing test from the test list"

    T_MACHINE[C4]="code";  T_FROM[C4]="green";         T_TO[C4]="refactor"
    T_DESC[C4]="Refactor — simpler solution identified"
    T_ACTIONS[C4]="refactor_code update_code_state commit_with_bundled_state"
    T_PRE[C4]="all_tests_pass"
    T_POST[C4]="all_tests_pass"
    T_JUDGMENT[C4]="true"
    T_USER_ACTION[C4]="Refactor the code to a simpler or cleaner solution"

    T_MACHINE[C5]="code";  T_FROM[C5]="green";         T_TO[C5]="[Merge:pr-open]"
    T_DESC[C5]="All tests done, quality gates pass — create PR"
    T_ACTIONS[C5]="create_pull_request update_code_state commit_with_bundled_state"
    T_PRE[C5]="all_tests_pass quality_gates_met"
    T_POST[C5]=""
    T_JUDGMENT[C5]="false"

    T_MACHINE[C6]="code";  T_FROM[C6]="refactor";      T_TO[C6]="red"
    T_DESC[C6]="Refactoring complete, write next failing test"
    T_ACTIONS[C6]="write_failing_test update_code_state commit_with_bundled_state"
    T_PRE[C6]="remaining_test_list_items_exist all_tests_pass"
    T_POST[C6]="does_targeted_test_fail"
    T_JUDGMENT[C6]="true"
    T_USER_ACTION[C6]="Write the next failing test from the test list"

    T_MACHINE[C7]="code";  T_FROM[C7]="refactor";      T_TO[C7]="[Merge:pr-open]"
    T_DESC[C7]="Refactoring complete, all tests done — create PR"
    T_ACTIONS[C7]="create_pull_request update_code_state commit_with_bundled_state"
    T_PRE[C7]="all_tests_pass quality_gates_met"
    T_POST[C7]=""
    T_JUDGMENT[C7]="false"

    T_MACHINE[C8]="code";  T_FROM[C8]="refactor";      T_TO[C8]="red"
    T_DESC[C8]="Regression detected during refactoring"
    T_ACTIONS[C8]="update_code_state commit_with_bundled_state"
    T_PRE[C8]="regression_detected"
    T_POST[C8]=""
    T_JUDGMENT[C8]="false"

    T_MACHINE[C9]="code";  T_FROM[C9]="green";         T_TO[C9]="red"
    T_DESC[C9]="Regression detected"
    T_ACTIONS[C9]="update_code_state commit_with_bundled_state"
    T_PRE[C9]="regression_detected"
    T_POST[C9]=""
    T_JUDGMENT[C9]="false"

    T_MACHINE[C10]="code"; T_FROM[C10]="red";          T_TO[C10]="blocked"
    T_DESC[C10]="Blocker identified in red state"
    T_ACTIONS[C10]="record_blocker update_code_state auto_select_next_plan commit_with_bundled_state"
    T_PRE[C10]=""
    T_POST[C10]=""
    T_JUDGMENT[C10]="true"
    T_USER_ACTION[C10]="Describe the blocker or unmet dependency"

    T_MACHINE[C11]="code"; T_FROM[C11]="green";        T_TO[C11]="blocked"
    T_DESC[C11]="Blocker identified in green state"
    T_ACTIONS[C11]="record_blocker update_code_state auto_select_next_plan commit_with_bundled_state"
    T_PRE[C11]=""
    T_POST[C11]=""
    T_JUDGMENT[C11]="true"
    T_USER_ACTION[C11]="Describe the blocker or unmet dependency"

    T_MACHINE[C12]="code"; T_FROM[C12]="refactor";     T_TO[C12]="blocked"
    T_DESC[C12]="Blocker identified in refactor state"
    T_ACTIONS[C12]="record_blocker update_code_state auto_select_next_plan commit_with_bundled_state"
    T_PRE[C12]=""
    T_POST[C12]=""
    T_JUDGMENT[C12]="true"
    T_USER_ACTION[C12]="Describe the blocker or unmet dependency"

    T_MACHINE[C13]="code"; T_FROM[C13]="blocked";      T_TO[C13]="[previous]"
    T_DESC[C13]="Blocker resolved, resume previous TDD state"
    T_ACTIONS[C13]="clear_blocker update_code_state commit_with_bundled_state"
    T_PRE[C13]=""
    T_POST[C13]=""
    T_JUDGMENT[C13]="true"
    T_USER_ACTION[C13]="Confirm the blocker has been resolved"

    T_MACHINE[C14]="code"; T_FROM[C14]="red";          T_TO[C14]="[Plan:planning]"
    T_DESC[C14]="Fundamental plan flaw discovered in red state"
    T_ACTIONS[C14]="record_plan_flaw_on_exit_to_plan annotate_plan_with_revision_needed update_code_state update_plan_state commit_with_bundled_state"
    T_PRE[C14]=""
    T_POST[C14]=""
    T_JUDGMENT[C14]="true"
    T_USER_ACTION[C14]="Describe the fundamental flaw discovered in the plan"

    T_MACHINE[C15]="code"; T_FROM[C15]="green";        T_TO[C15]="[Plan:planning]"
    T_DESC[C15]="Fundamental plan flaw discovered in green state"
    T_ACTIONS[C15]="record_plan_flaw_on_exit_to_plan annotate_plan_with_revision_needed update_code_state update_plan_state commit_with_bundled_state"
    T_PRE[C15]=""
    T_POST[C15]=""
    T_JUDGMENT[C15]="true"
    T_USER_ACTION[C15]="Describe the fundamental flaw discovered in the plan"

    T_MACHINE[C16]="code"; T_FROM[C16]="refactor";     T_TO[C16]="[Plan:planning]"
    T_DESC[C16]="Fundamental plan flaw discovered in refactor state"
    T_ACTIONS[C16]="record_plan_flaw_on_exit_to_plan annotate_plan_with_revision_needed update_code_state update_plan_state commit_with_bundled_state"
    T_PRE[C16]=""
    T_POST[C16]=""
    T_JUDGMENT[C16]="true"
    T_USER_ACTION[C16]="Describe the fundamental flaw discovered in the plan"

    # --- Merge Machine ---
    T_MACHINE[M1]="merge"; T_FROM[M1]="[Code/Promote]"; T_TO[M1]="pr-open"
    T_DESC[M1]="PR created, CI checks triggered"
    T_ACTIONS[M1]="create_pull_request"
    T_PRE[M1]=""
    T_POST[M1]=""
    T_JUDGMENT[M1]="true"
    T_USER_ACTION[M1]="Create the pull request"

    T_MACHINE[M2]="merge"; T_FROM[M2]="pr-open";       T_TO[M2]="reviewing"
    T_DESC[M2]="Review started"
    T_ACTIONS[M2]="submit_review"
    T_PRE[M2]=""
    T_POST[M2]="reviews_submitted"
    T_JUDGMENT[M2]="true"
    T_USER_ACTION[M2]="Request or begin code review"

    T_MACHINE[M3]="merge"; T_FROM[M3]="pr-open";       T_TO[M3]="blocked"
    T_DESC[M3]="CI checks failed"
    T_ACTIONS[M3]=""
    T_PRE[M3]=""
    T_POST[M3]=""
    T_JUDGMENT[M3]="false"

    T_MACHINE[M4]="merge"; T_FROM[M4]="reviewing";     T_TO[M4]="approved"
    T_DESC[M4]="All required reviewers approved, CI passing"
    T_ACTIONS[M4]=""
    T_PRE[M4]="all_required_reviewers_approved"
    T_POST[M4]=""
    T_JUDGMENT[M4]="false"

    T_MACHINE[M5]="merge"; T_FROM[M5]="reviewing";     T_TO[M5]="changes-requested"
    T_DESC[M5]="Reviewer requested changes"
    T_ACTIONS[M5]=""
    T_PRE[M5]="any_reviewer_requested_changes"
    T_POST[M5]=""
    T_JUDGMENT[M5]="false"

    T_MACHINE[M6]="merge"; T_FROM[M6]="changes-requested"; T_TO[M6]="reviewing"
    T_DESC[M6]="Changes addressed, pushed for re-review"
    T_ACTIONS[M6]="address_review_feedback push_pr_fix"
    T_PRE[M6]=""
    T_POST[M6]=""
    T_JUDGMENT[M6]="true"
    T_USER_ACTION[M6]="Address the review feedback, commit, and push"

    T_MACHINE[M7]="merge"; T_FROM[M7]="changes-requested"; T_TO[M7]="[Code]"
    T_DESC[M7]="Significant rework needed — return to Code machine"
    T_ACTIONS[M7]=""
    T_PRE[M7]=""
    T_POST[M7]=""
    T_JUDGMENT[M7]="true"
    T_USER_ACTION[M7]="Determine if changes require new tests or major rework"

    T_MACHINE[M8]="merge"; T_FROM[M8]="approved";      T_TO[M8]="merged"
    T_DESC[M8]="Merge PR to target branch"
    T_ACTIONS[M8]="merge_pull_request"
    T_PRE[M8]="all_required_reviewers_approved"
    T_POST[M8]=""
    T_JUDGMENT[M8]="false"

    T_MACHINE[M9]="merge"; T_FROM[M9]="blocked";       T_TO[M9]="pr-open"
    T_DESC[M9]="Fix pushed, CI re-running"
    T_ACTIONS[M9]="push_pr_fix"
    T_PRE[M9]=""
    T_POST[M9]=""
    T_JUDGMENT[M9]="true"
    T_USER_ACTION[M9]="Fix the CI failure or merge conflict, commit, and push"

    T_MACHINE[M10]="merge"; T_FROM[M10]="blocked";     T_TO[M10]="[Code]"
    T_DESC[M10]="Significant fix needed — return to Code machine"
    T_ACTIONS[M10]=""
    T_PRE[M10]=""
    T_POST[M10]=""
    T_JUDGMENT[M10]="true"
    T_USER_ACTION[M10]="Determine if the fix requires new tests or major rework"

    T_MACHINE[M11]="merge"; T_FROM[M11]="merged";      T_TO[M11]="[Promote:deploying]"
    T_DESC[M11]="PR merged, deployment triggered"
    T_ACTIONS[M11]="trigger_deployment"
    T_PRE[M11]=""
    T_POST[M11]=""
    T_JUDGMENT[M11]="false"

    # --- Promote Machine ---
    T_MACHINE[R1]="promote"; T_FROM[R1]="[Merge:merged]"; T_TO[R1]="deploying"
    T_DESC[R1]="PR merged, deployment pipeline triggered"
    T_ACTIONS[R1]="trigger_deployment"
    T_PRE[R1]=""
    T_POST[R1]=""
    T_JUDGMENT[R1]="false"

    T_MACHINE[R2]="promote"; T_FROM[R2]="deploying";   T_TO[R2]="deployed"
    T_DESC[R2]="Deployment succeeded"
    T_ACTIONS[R2]=""
    T_PRE[R2]="deployment_succeeded"
    T_POST[R2]=""
    T_JUDGMENT[R2]="false"

    T_MACHINE[R3]="promote"; T_FROM[R3]="deploying";   T_TO[R3]="failed"
    T_DESC[R3]="Deployment failed — all work halted"
    T_ACTIONS[R3]="halt_all_work perform_rollback"
    T_PRE[R3]="deployment_failed"
    T_POST[R3]=""
    T_JUDGMENT[R3]="false"

    T_MACHINE[R4]="promote"; T_FROM[R4]="deployed";    T_TO[R4]="validating"
    T_DESC[R4]="Post-deployment checks initiated"
    T_ACTIONS[R4]="run_post_deployment_checks"
    T_PRE[R4]=""
    T_POST[R4]=""
    T_JUDGMENT[R4]="false"

    T_MACHINE[R5]="promote"; T_FROM[R5]="validating";  T_TO[R5]="promoted"
    T_DESC[R5]="Validation passed"
    T_ACTIONS[R5]=""
    T_PRE[R5]="health_checks_passed smoke_tests_passed"
    T_POST[R5]=""
    T_JUDGMENT[R5]="false"

    T_MACHINE[R6]="promote"; T_FROM[R6]="validating";  T_TO[R6]="failed"
    T_DESC[R6]="Validation failed — all work halted"
    T_ACTIONS[R6]="halt_all_work perform_rollback"
    T_PRE[R6]=""
    T_POST[R6]=""
    T_JUDGMENT[R6]="false"

    T_MACHINE[R7]="promote"; T_FROM[R7]="promoted";    T_TO[R7]="[Merge:pr-open]"
    T_DESC[R7]="Create PR for next environment"
    T_ACTIONS[R7]="create_pull_request"
    T_PRE[R7]=""
    T_POST[R7]=""
    T_JUDGMENT[R7]="false"

    T_MACHINE[R8]="promote"; T_FROM[R8]="promoted";    T_TO[R8]="complete"
    T_DESC[R8]="Production deployment validated — plan complete"
    T_ACTIONS[R8]="move_plan_to_done mark_parent_plan_complete"
    T_PRE[R8]="is_production_deployment"
    T_POST[R8]=""
    T_JUDGMENT[R8]="false"

    T_MACHINE[R9]="promote"; T_FROM[R9]="failed";      T_TO[R9]="[Plan:planning]"
    T_DESC[R9]="Create fix plan, enter Plan machine"
    T_ACTIONS[R9]="create_deployment_failure_plan"
    T_PRE[R9]=""
    T_POST[R9]=""
    T_JUDGMENT[R9]="false"
}

get_transition_field() {
    local tid="$1" field="$2"
    case "$field" in
        from)        echo "${T_FROM[$tid]:-}" ;;
        to)          echo "${T_TO[$tid]:-}" ;;
        desc)        echo "${T_DESC[$tid]:-}" ;;
        actions)     echo "${T_ACTIONS[$tid]:-}" ;;
        preconditions) echo "${T_PRE[$tid]:-}" ;;
        postconditions) echo "${T_POST[$tid]:-}" ;;
        judgment)    echo "${T_JUDGMENT[$tid]:-false}" ;;
        user_action) echo "${T_USER_ACTION[$tid]:-}" ;;
        machine)     echo "${T_MACHINE[$tid]:-}" ;;
    esac
}

get_valid_transitions() {
    local machine="$1" state="$2"

    case "${machine}:${state}" in
        plan:idle)              echo "P1" ;;
        plan:planning)          echo "P2 P3 P7" ;;
        plan:decomposing)       echo "P4 P8" ;;
        plan:test-listing)      echo "P5 P9" ;;
        plan:ready)             echo "P6" ;;
        plan:blocked)           echo "P10" ;;
        code:red)               echo "C2 C10 C14" ;;
        code:green)             echo "C3 C4 C5 C9 C11 C15" ;;
        code:refactor)          echo "C6 C7 C8 C12 C16" ;;
        code:blocked)           echo "C13" ;;
        merge:pr-open)          echo "M2 M3" ;;
        merge:reviewing)        echo "M4 M5" ;;
        merge:changes-requested) echo "M6 M7" ;;
        merge:approved)         echo "M8" ;;
        merge:merged)           echo "M11" ;;
        merge:blocked)          echo "M9 M10" ;;
        promote:deploying)      echo "R2 R3" ;;
        promote:deployed)       echo "R4" ;;
        promote:validating)     echo "R5 R6" ;;
        promote:promoted)       echo "R7 R8" ;;
        promote:failed)         echo "R9" ;;
    esac
}

is_transition_eligible() {
    local tid="$1"
    local preconditions="${T_PRE[$tid]}"

    # Transitions with no preconditions are always eligible
    [[ -z "$preconditions" ]] && return 0

    # Check each precondition
    for pre in $preconditions; do
        if ! "$pre" 2>/dev/null; then
            return 1
        fi
    done
    return 0
}

# C5 special: also requires no remaining test items
_check_c5_eligible() {
    all_tests_pass && quality_gates_met && ! remaining_test_list_items_exist
}
