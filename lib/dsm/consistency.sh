#!/usr/bin/env bash
# consistency.sh — Preflight checks, rollback stack, postcondition verification

# Rollback stack — list of commands to undo mutations on failure
ROLLBACK_STACK=()

rollback_push() {
    ROLLBACK_STACK+=("$1")
}

rollback_execute() {
    if [[ ${#ROLLBACK_STACK[@]} -eq 0 ]]; then
        return
    fi
    print_warning "Rolling back..."
    for (( i=${#ROLLBACK_STACK[@]}-1; i>=0; i-- )); do
        eval "${ROLLBACK_STACK[$i]}" 2>/dev/null
    done
    ROLLBACK_STACK=()
}

preflight_check() {
    local tid="$1"

    # Check that we're in a git repo
    if ! git -C "$REPO_ROOT" rev-parse --git-dir &>/dev/null; then
        print_error "Not a git repository."
        return 1
    fi

    # Check for clean working tree (for transitions that commit)
    local actions="${T_ACTIONS[$tid]}"
    if echo "$actions" | grep -q "commit_with_bundled_state"; then
        local status
        status=$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)
        # Allow untracked files, but warn about modified files
        if echo "$status" | grep -qE '^[MADRC]'; then
            print_warning "Working tree has staged changes. These will be included in the transition commit."
        fi
    fi

    # Check preconditions
    local preconditions="${T_PRE[$tid]}"
    if [[ -n "$preconditions" ]]; then
        for pre in $preconditions; do
            if ! "$pre" 2>/dev/null; then
                print_error "Precondition not met: ${pre}"
                return 1
            fi
        done
    fi

    return 0
}

verify_postconditions() {
    local tid="$1"
    local postconditions="${T_POST[$tid]}"

    [[ -z "$postconditions" ]] && return 0

    local all_met=true
    for post in $postconditions; do
        if ! "$post" 2>/dev/null; then
            print_warning "Postcondition not yet met: ${post}"
            all_met=false
        fi
    done
    [[ "$all_met" == "true" ]]
}

execute_transition() {
    local tid="$1" machine="$2" current_state="$3"
    local judgment="${T_JUDGMENT[$tid]}"
    local user_action="${T_USER_ACTION[$tid]}"
    local to="${T_TO[$tid]}"
    local desc="${T_DESC[$tid]}"
    local actions="${T_ACTIONS[$tid]}"

    # Preflight
    if ! preflight_check "$tid"; then
        print_error "Preflight check failed. No changes made."
        return 1
    fi

    local plan_id
    plan_id=$(get_active_plan_id)

    # If this is a judgment-call transition with a user action, write pending and exit
    if [[ "$judgment" == "true" && -n "$user_action" ]]; then
        _write_pending "$tid" "$machine" "$current_state" "$plan_id"
        echo ""
        print_header "Transition: ${tid} (${current_state} -> ${to})"
        echo "  ${desc}"
        echo ""
        print_header "Action required:"
        echo -e "  ${YELLOW}${user_action}${RESET}"
        echo ""
        print_dim "After completing the action, run: dsm advance"
        print_dim "(dsm will verify postconditions and complete the transition)"
        echo ""
        return 0
    fi

    # Execute automated transition
    echo ""
    print_header "Executing: ${tid} (${current_state} -> ${to})"
    echo "  ${desc}"
    echo ""

    ROLLBACK_STACK=()
    local commit_message="${tid}: ${desc} [${current_state} -> ${to}]"

    for act in $actions; do
        case "$act" in
            move_plan_to_doing)
                action_move_plan_to_doing "$plan_id"
                rollback_push "mv '${REPO_ROOT}/${DOING_DIR}/${plan_id}.md' '${REPO_ROOT}/${TODO_DIR}/${plan_id}.md'"
                ;;
            move_plan_to_todo)
                action_move_plan_to_todo "$plan_id"
                rollback_push "mv '${REPO_ROOT}/${TODO_DIR}/${plan_id}.md' '${REPO_ROOT}/${DOING_DIR}/${plan_id}.md'"
                ;;
            move_plan_to_done)
                action_move_plan_to_done "$plan_id"
                ;;
            create_feature_branch)
                if ! action_create_feature_branch "$plan_id"; then
                    rollback_execute
                    print_error "Failed to create feature branch."
                    return 1
                fi
                rollback_push "git -C '${REPO_ROOT}' checkout - && git -C '${REPO_ROOT}' branch -D '${FEATURE_BRANCH_PREFIX}${plan_id}'"
                ;;
            update_plan_state)
                action_update_plan_state "$plan_id" "$to"
                rollback_push "git -C '${REPO_ROOT}' checkout -- '${PLAN_STATE_FILE}' 2>/dev/null"
                ;;
            update_code_state)
                action_update_code_state "$plan_id" "$to"
                rollback_push "git -C '${REPO_ROOT}' checkout -- '${CODE_STATE_FILE}' 2>/dev/null"
                ;;
            commit_with_bundled_state)
                if ! action_commit_with_bundled_state "$plan_id" "$commit_message"; then
                    rollback_execute
                    print_error "Failed to commit."
                    return 1
                fi
                ;;
            create_pull_request)
                action_create_pull_request "$plan_id"
                ;;
            merge_pull_request)
                action_merge_pull_request
                ;;
            trigger_deployment)
                action_trigger_deployment
                ;;
            run_post_deployment_checks)
                action_run_post_deployment_checks
                ;;
            perform_rollback)
                action_perform_rollback "$(get_current_environment)"
                ;;
            halt_all_work)
                action_halt_all_work
                ;;
            create_deployment_failure_plan)
                action_create_deployment_failure_plan "$(get_current_environment)" "$desc"
                ;;
            auto_select_next_plan)
                action_auto_select_next_plan
                ;;
            mark_parent_plan_complete)
                action_mark_parent_plan_complete "$plan_id"
                ;;
            *)
                print_dim "  Action: ${act} (no automated implementation)"
                ;;
        esac
    done

    # Verify postconditions
    if ! verify_postconditions "$tid"; then
        print_warning "Transition completed but some postconditions not yet met."
    else
        print_success "Transition complete."
    fi

    # Show new state
    local new_state
    case "$machine" in
        plan)    new_state=$(get_plan_state) ;;
        code)    new_state=$(get_code_state) ;;
        merge)   new_state=$(get_merge_state) ;;
        promote) new_state=$(get_promote_state) ;;
    esac
    echo ""
    print_dim "Current state: ${machine^} / ${new_state}"
    echo ""
}

handle_pending_transition() {
    local dry_run="${1:-false}"
    local pending_file="${REPO_ROOT}/${PENDING_FILE}"
    [[ ! -f "$pending_file" ]] && return 1

    # Read pending transition
    local tid from to plan_id postcondition user_action
    tid=$(grep -oP '(?<=^transition=).*' "$pending_file")
    from=$(grep -oP '(?<=^from=).*' "$pending_file")
    to=$(grep -oP '(?<=^to=).*' "$pending_file")
    plan_id=$(grep -oP '(?<=^plan=).*' "$pending_file")
    postcondition=$(grep -oP '(?<=^postcondition=).*' "$pending_file")
    user_action=$(grep -oP '(?<=^user_action=).*' "$pending_file")

    echo ""
    print_header "Pending transition: ${tid} (${from} -> ${to})"

    if [[ "$dry_run" == "true" ]]; then
        echo ""
        echo "  Waiting for: ${user_action}"
        if [[ -n "$postcondition" ]]; then
            echo "  Postcondition to verify: ${postcondition}"
            if "$postcondition" 2>/dev/null; then
                print_success "  Postcondition MET — ready to complete"
            else
                print_warning "  Postcondition NOT YET MET"
            fi
        fi
        echo ""
        return
    fi

    # Verify postconditions
    if [[ -n "$postcondition" ]]; then
        local all_met=true
        for post in $postcondition; do
            if ! "$post" 2>/dev/null; then
                print_warning "Postcondition not yet met: ${post}"
                echo ""
                echo "  Required action: ${user_action}"
                echo ""
                print_dim "Complete the action and run 'dsm advance' again."
                echo ""
                all_met=false
            fi
        done
        if [[ "$all_met" == "false" ]]; then
            return 1
        fi
    fi

    # Complete the transition
    print_success "Postconditions met. Completing transition..."

    local machine="${T_MACHINE[$tid]}"
    local real_to="${T_TO[$tid]}"

    # Update state files and commit
    case "$machine" in
        plan)
            action_update_plan_state "$plan_id" "$real_to"
            ;;
        code)
            local test_index test_total
            test_index=$(_parse_code_state_field "test_index" 2>/dev/null)
            test_total=$(_parse_code_state_field "test_total" 2>/dev/null)
            # Increment test index for transitions that write a new test
            case "$tid" in
                C1|C3|C6)
                    test_index=$(( ${test_index:-0} + 1 ))
                    ;;
            esac
            action_update_code_state "$plan_id" "$real_to" "$test_index" "$test_total"
            ;;
    esac

    local commit_message="${tid}: ${T_DESC[$tid]} [${from} -> ${to}]"
    action_commit_with_bundled_state "$plan_id" "$commit_message"

    # Remove pending file
    rm -f "$pending_file"

    print_success "Transition ${tid} complete."
    echo ""
}

_write_pending() {
    local tid="$1" machine="$2" from="$3" plan_id="$4"
    local pending_file="${REPO_ROOT}/${PENDING_FILE}"
    local postcondition="${T_POST[$tid]}"
    local user_action="${T_USER_ACTION[$tid]}"
    local to="${T_TO[$tid]}"

    cat > "$pending_file" <<EOF
transition=${tid}
machine=${machine}
from=${from}
to=${to}
plan=${plan_id}
postcondition=${postcondition}
user_action=${user_action}
EOF
}
