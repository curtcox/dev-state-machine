#!/usr/bin/env bash
# output.sh — Text and JSON formatting for all commands

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    BOLD="\033[1m"
    DIM="\033[2m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    RED="\033[31m"
    CYAN="\033[36m"
    RESET="\033[0m"
else
    BOLD="" DIM="" GREEN="" YELLOW="" RED="" CYAN="" RESET=""
fi

print_header() {
    echo -e "${BOLD}$1${RESET}"
}

print_success() {
    echo -e "${GREEN}$1${RESET}"
}

print_warning() {
    echo -e "${YELLOW}$1${RESET}"
}

print_error() {
    echo -e "${RED}$1${RESET}" >&2
}

print_dim() {
    echo -e "${DIM}$1${RESET}"
}

print_machine_state() {
    local machine="$1" state="$2" detail="$3" is_active="$4"
    local prefix="  "
    if [[ "$is_active" == "true" ]]; then
        prefix="${GREEN}> ${RESET}"
    fi
    local state_display
    if [[ -z "$state" || "$state" == "inactive" ]]; then
        state_display="${DIM}--${RESET}"
    else
        state_display="${CYAN}${state}${RESET}"
    fi
    local detail_display=""
    if [[ -n "$detail" ]]; then
        detail_display="${DIM}  (${detail})${RESET}"
    fi
    printf "${prefix}%-10s %s%s\n" "${machine^}:" "$state_display" "$detail_display"
}

print_status_table() {
    local active_machine="$1"
    local plan_state="$2" plan_detail="$3"
    local code_state="$4" code_detail="$5"
    local merge_state="$6" merge_detail="$7"
    local promote_state="$8" promote_detail="$9"

    echo ""
    print_header "Active machine: ${active_machine^}"
    echo ""
    print_machine_state "plan" "$plan_state" "$plan_detail" "$([[ "$active_machine" == "plan" ]] && echo true)"
    print_machine_state "code" "$code_state" "$code_detail" "$([[ "$active_machine" == "code" ]] && echo true)"
    print_machine_state "merge" "$merge_state" "$merge_detail" "$([[ "$active_machine" == "merge" ]] && echo true)"
    print_machine_state "promote" "$promote_state" "$promote_detail" "$([[ "$active_machine" == "promote" ]] && echo true)"
    echo ""
}

print_json_status() {
    local active_machine="$1"
    local plan_state="$2" plan_detail="$3"
    local code_state="$4" code_detail="$5"
    local merge_state="$6" merge_detail="$7"
    local promote_state="$8" promote_detail="$9"

    cat <<EOF
{
  "active_machine": "${active_machine}",
  "plan": { "state": $(json_string "$plan_state"), "detail": $(json_string "$plan_detail") },
  "code": { "state": $(json_string "$code_state"), "detail": $(json_string "$code_detail") },
  "merge": { "state": $(json_string "$merge_state"), "detail": $(json_string "$merge_detail") },
  "promote": { "state": $(json_string "$promote_state"), "detail": $(json_string "$promote_detail") }
}
EOF
}

json_string() {
    if [[ -z "$1" || "$1" == "inactive" ]]; then
        echo "null"
    else
        echo "\"$1\""
    fi
}

print_transition_choice() {
    local -n transitions_ref=$1
    local current_machine="$2" current_state="$3"

    echo ""
    print_header "Current state: ${current_machine^} / ${current_state}"
    echo "Multiple transitions available:"
    echo ""
    local i=1
    for tid in "${transitions_ref[@]}"; do
        local to desc judgment
        to=$(get_transition_field "$tid" "to")
        desc=$(get_transition_field "$tid" "desc")
        judgment=$(get_transition_field "$tid" "judgment")
        local suffix=""
        if [[ "$judgment" == "true" ]]; then
            suffix=" ${YELLOW}(judgment call)${RESET}"
        fi
        echo -e "  ${BOLD}${i}.${RESET} ${tid}: ${current_state} -> ${to}    ${desc}${suffix}"
        ((i++))
    done
    echo ""
}

print_explain() {
    local tid="$1" machine="$2" from="$3"
    local to desc actions preconditions postconditions judgment user_action
    to=$(get_transition_field "$tid" "to")
    desc=$(get_transition_field "$tid" "desc")
    actions=$(get_transition_field "$tid" "actions")
    preconditions=$(get_transition_field "$tid" "preconditions")
    postconditions=$(get_transition_field "$tid" "postconditions")
    judgment=$(get_transition_field "$tid" "judgment")
    user_action=$(get_transition_field "$tid" "user_action")

    echo ""
    print_header "Transition: ${tid}"
    echo "  ${from} -> ${to}"
    echo "  ${desc}"
    echo ""

    if [[ -n "$preconditions" ]]; then
        print_header "Preconditions:"
        for pre in $preconditions; do
            echo "  - ${pre}"
        done
        echo ""
    fi

    if [[ -n "$actions" ]]; then
        print_header "Actions:"
        for act in $actions; do
            local act_judgment=""
            if is_judgment_action "$act"; then
                act_judgment=" ${YELLOW}(you do this)${RESET}"
            fi
            echo -e "  - ${act}${act_judgment}"
        done
        echo ""
    fi

    if [[ "$judgment" == "true" && -n "$user_action" ]]; then
        print_header "Your action:"
        echo -e "  ${YELLOW}${user_action}${RESET}"
        echo ""
    fi

    if [[ -n "$postconditions" ]]; then
        print_header "Postconditions (verified after):"
        for post in $postconditions; do
            echo "  - ${post}"
        done
        echo ""
    fi
}

print_functions_list() {
    local filter_machine="${1:-}"
    echo ""
    print_header "Informational Functions"
    echo ""
    _print_catalog "functions" "$filter_machine"
}

print_actions_list() {
    local filter_machine="${1:-}"
    echo ""
    print_header "Actions"
    echo ""
    _print_catalog "actions" "$filter_machine"
}

_print_catalog() {
    local catalog_type="$1" filter_machine="$2"
    if [[ "$catalog_type" == "functions" ]]; then
        _print_functions_catalog "$filter_machine"
    else
        _print_actions_catalog "$filter_machine"
    fi
}

is_judgment_action() {
    local action="$1"
    case "$action" in
        write_failing_test|write_production_code|refactor_code|\
        create_plan_file|write_acceptance_criteria|write_test_lists|\
        decompose_plan_into_children|create_pull_request|push_pr_fix|\
        submit_review|address_review_feedback|\
        execute_manual_testing|approve_manual_testing|\
        identify_blocker|resolve_blocker)
            return 0 ;;
        *)
            return 1 ;;
    esac
}
