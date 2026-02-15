#!/usr/bin/env bash
# catalogs.sh — Function and action catalog display for 'dsm list'

_print_functions_catalog() {
    local filter_machine="$1"

    _print_catalog_section "Active Machine Resolution" "$filter_machine" "" \
        "determine_active_machine:Which machine is currently active:all" \
        "has_feature_branch:Whether a feature branch exists for the plan:plan,code" \
        "feature_branch_has_test_code:Whether the feature branch contains test code:plan,code" \
        "has_open_pr_for_branch:Whether an open PR exists for the branch:merge" \
        "is_deployment_in_progress_or_pending:Whether deployment or validation is underway:promote"

    _print_catalog_section "Plan Selection & Priority" "$filter_machine" "" \
        "has_plans_in_doing:Whether any plans exist in /doing/:plan" \
        "has_plans_in_todo:Whether any plans exist in /todo/:plan" \
        "all_plans_blocked:Whether every plan is blocked:plan" \
        "get_highest_priority_non_blocked_plan:Which plan to work on next:plan" \
        "deployment_failure_plan_exists:Whether a deployment-failure plan blocks all work:all" \
        "are_all_sibling_plans_complete:Whether all child plans of a parent are done:promote"

    _print_catalog_section "Plan Structure" "$filter_machine" "" \
        "get_plan_location:Which directory contains a plan file:plan" \
        "read_plan_metadata:Contents of a plan file:plan" \
        "plan_has_acceptance_criteria:Whether the plan has acceptance criteria:plan" \
        "plan_has_child_plans:Whether the plan is decomposed:plan" \
        "child_plans_exist_in_todo:Whether child plans exist as files:plan" \
        "is_plan_too_large:Whether the plan needs decomposition:plan:judgment" \
        "is_plan_specific_enough:Whether the plan is ready for test lists:plan:judgment"

    _print_catalog_section "Test List Status" "$filter_machine" "" \
        "test_lists_complete_for_all_applicable_types:Whether test lists cover all types:plan"

    _print_catalog_section "Test Execution" "$filter_machine" "" \
        "does_targeted_test_fail:Whether the targeted test fails:code" \
        "all_tests_pass:Whether the full test suite passes:code" \
        "remaining_test_list_items_exist:Whether unimplemented test items remain:code" \
        "get_test_list_progress:Progress through the test list:code" \
        "regression_detected:Whether a previously passing test now fails:code" \
        "is_simpler_solution_available:Whether simpler code exists:code:judgment" \
        "is_plan_fundamentally_flawed:Whether the plan has a fatal flaw:code:judgment"

    _print_catalog_section "Quality Gates" "$filter_machine" "" \
        "quality_gates_met:Whether all quality metrics meet thresholds:code" \
        "test_coverage_meets_threshold:Whether coverage meets minimums:code" \
        "complexity_within_limits:Whether complexity is within maximums:code" \
        "lint_violations_at_zero:Whether there are zero lint violations:code" \
        "security_findings_at_zero:Whether there are zero critical findings:code"

    _print_catalog_section "Blocker Tracking" "$filter_machine" "" \
        "blocker_exists_for_plan:Whether the plan has an unresolved blocker:plan,code" \
        "blocker_resolved:Whether a blocker has been resolved:plan,code" \
        "get_previous_state_before_block:State before blocking:plan,code"

    _print_catalog_section "GitHub PR State" "$filter_machine" "" \
        "get_pr_status:PR status (open/closed/merged):merge" \
        "ci_checks_status:Aggregate CI check status:merge" \
        "reviews_submitted:Whether reviews have been submitted:merge" \
        "any_reviewer_requested_changes:Whether changes were requested:merge" \
        "all_required_reviewers_approved:Whether all reviewers approved:merge" \
        "unresolved_review_comments_exist:Whether unresolved comments remain:merge" \
        "merge_conflicts_exist:Whether the PR has merge conflicts:merge" \
        "branch_protection_satisfied:Whether branch protection rules are met:merge" \
        "is_pr_merged:Whether the PR has been merged:merge" \
        "does_fix_require_significant_rework:Whether fixes need TDD cycle:merge:judgment"

    _print_catalog_section "GitHub Deployment State" "$filter_machine" "" \
        "deployment_workflow_status:Deployment workflow status:promote" \
        "deployment_succeeded:Whether deployment completed successfully:promote" \
        "deployment_failed:Whether deployment failed:promote" \
        "health_checks_passed:Whether health checks pass:promote" \
        "smoke_tests_passed:Whether smoke tests passed:promote" \
        "manual_testing_approved:Whether manual testing was approved:promote" \
        "production_monitors_green:Whether production monitoring is healthy:promote"

    _print_catalog_section "Environment & Promotion Path" "$filter_machine" "" \
        "get_current_environment:Which environment the deployment targets:promote" \
        "is_production_deployment:Whether this is the production deployment:promote" \
        "get_next_environment:Next environment in the promotion path:promote"
}

_print_actions_catalog() {
    local filter_machine="$1"

    _print_catalog_section "Plan File Management" "$filter_machine" "" \
        "create_plan_file:Create a new plan file:plan:human" \
        "move_plan_to_doing:Move plan from /todo/ to /doing/:plan" \
        "move_plan_to_todo:Move plan from /doing/ to /todo/:plan" \
        "move_plan_to_done:Archive completed plan to /done/:promote" \
        "write_acceptance_criteria:Write acceptance criteria:plan:human" \
        "write_test_lists:Write test lists for all types:plan:human" \
        "decompose_plan_into_children:Break plan into child plans:plan:human" \
        "annotate_plan_with_revision_needed:Add revision notes to plan:code" \
        "create_deployment_failure_plan:Auto-create fix plan:promote" \
        "mark_parent_plan_complete:Complete parent when all children done:promote"

    _print_catalog_section "State File Management" "$filter_machine" "" \
        "update_plan_state:Update plan-state.md:plan" \
        "update_code_state:Update code-state.md:code" \
        "record_blocker:Record blocker in state file:plan,code" \
        "clear_blocker:Clear resolved blocker:plan,code" \
        "record_plan_flaw_on_exit_to_plan:Record flaw details in code-state.md:code"

    _print_catalog_section "Git Operations" "$filter_machine" "" \
        "create_feature_branch:Create feature branch from dev:plan" \
        "commit_with_bundled_state:Commit with bundled state file changes:all" \
        "push_to_remote:Push to remote repository:all"

    _print_catalog_section "Test & Code Authoring" "$filter_machine" "" \
        "write_failing_test:Write next test as failing code:code:human" \
        "write_production_code:Write minimal code to pass test:code:human" \
        "refactor_code:Improve code without changing behavior:code:human"

    _print_catalog_section "Pull Request Operations" "$filter_machine" "" \
        "create_pull_request:Create PR targeting environment branch:merge:human" \
        "push_pr_fix:Push commits to address feedback:merge:human" \
        "merge_pull_request:Merge approved PR:merge" \
        "submit_review:Submit PR review:merge:human" \
        "address_review_feedback:Modify code per review:merge:human"

    _print_catalog_section "Deployment & Validation" "$filter_machine" "" \
        "trigger_deployment:Initiate CI/CD deployment:promote" \
        "run_post_deployment_checks:Run health checks and smoke tests:promote" \
        "execute_manual_testing:Perform manual testing:promote:human" \
        "approve_manual_testing:Approve manual testing results:promote:human" \
        "perform_rollback:Revert to previous known-good state:promote" \
        "run_ci_checks:Execute CI checks on PR:merge"

    _print_catalog_section "Orchestration" "$filter_machine" "" \
        "auto_select_next_plan:Select highest-priority non-blocked plan:plan" \
        "halt_all_work:Block all work on deployment failure:promote" \
        "resume_normal_work:Clear deployment-failure halt:promote"
}

# Helper: print a catalog section with entries
# Entry format: "name:description:machines[:judgment|human]"
_print_catalog_section() {
    local title="$1" filter_machine="$2"
    shift 2
    shift  # skip empty string

    local entries=("$@")
    local printed_header=false

    for entry in "${entries[@]}"; do
        IFS=':' read -r name desc machines tag <<< "$entry"

        # Filter by machine if specified
        if [[ -n "$filter_machine" && "$machines" != "all" ]]; then
            if ! echo "$machines" | grep -qw "$filter_machine"; then
                continue
            fi
        fi

        if [[ "$printed_header" == "false" ]]; then
            print_header "  ${title}"
            printed_header=true
        fi

        local suffix=""
        case "$tag" in
            judgment) suffix=" ${YELLOW}(judgment call)${RESET}" ;;
            human)    suffix=" ${YELLOW}(human/agent)${RESET}" ;;
        esac

        printf "    %-45s %s%s\n" "$name" "$desc" "$suffix"
    done

    if [[ "$printed_header" == "true" ]]; then
        echo ""
    fi
}
