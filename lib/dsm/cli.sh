#!/usr/bin/env bash
# cli.sh — Argument parsing, help text, dispatch

main() {
    local subcommand="${1:-help}"
    shift 2>/dev/null || true

    case "$subcommand" in
        status)   cmd_status "$@" ;;
        explain)  cmd_advance --dry-run "$@" ;;
        advance)  cmd_advance "$@" ;;
        list)     cmd_list "$@" ;;
        help)     cmd_help "$@" ;;
        version)  echo "dsm ${DSM_VERSION}" ;;
        *)
            print_error "Unknown command: ${subcommand}"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

cmd_help() {
    local topic="${1:-}"
    case "$topic" in
        status)   _help_status ;;
        explain)  _help_explain ;;
        advance)  _help_advance ;;
        list)     _help_list ;;
        "")       _help_main ;;
        *)
            print_error "Unknown help topic: ${topic}"
            _help_main
            exit 1
            ;;
    esac
}

_help_main() {
    cat <<EOF
dsm — Development State Machine CLI

Usage: dsm <command> [options]

Commands:
  status    Show current state of all machines
  explain   Explain what advancing would do (dry run)
  advance   Advance the active machine to its next state
  list      List available functions or actions
  help      Show help for a command
  version   Show version

Run 'dsm help <command>' for details on a specific command.
EOF
}

_help_status() {
    cat <<EOF
dsm status — Show current state of all machines

Usage: dsm status [options]

Options:
  --machine <plan|code|merge|promote>   Show only one machine
  --json                                Output as JSON

Examples:
  dsm status                    Show all machines
  dsm status --machine plan     Show only Plan machine
  dsm status --json             JSON output for scripting
EOF
}

_help_explain() {
    cat <<EOF
dsm explain — Explain what advancing would do (dry run)

Usage: dsm explain [options]

Options:
  --machine <plan|code|merge|promote>   Target a specific machine
  --transition <id>                     Explain a specific transition (e.g., P1, C2)

This command never changes any state. It shows:
  - Available transitions from the current state
  - Actions that would be performed
  - Preconditions and postconditions

Examples:
  dsm explain                   Explain next transition for active machine
  dsm explain --transition P1   Explain transition P1 specifically
EOF
}

_help_advance() {
    cat <<EOF
dsm advance — Advance the active machine to its next state

Usage: dsm advance [options]

Options:
  --machine <plan|code|merge|promote>   Target a specific machine
  --transition <id>                     Select a specific transition (e.g., P1, C2)
  --dry-run                             Same as 'dsm explain'

When multiple transitions are available, you will be prompted to choose.
Judgment-call transitions print instructions and wait for you to act;
run 'dsm advance' again after completing the action.

Examples:
  dsm advance                       Advance active machine
  dsm advance --transition C3       Take transition C3 specifically
  dsm advance --dry-run             Preview without acting
EOF
}

_help_list() {
    cat <<EOF
dsm list — List available functions or actions

Usage: dsm list <functions|actions> [options]

Options:
  --machine <plan|code|merge|promote>   Filter to one machine

Examples:
  dsm list functions                 List all informational functions
  dsm list actions                   List all actions
  dsm list functions --machine code  List functions used by Code machine
EOF
}

# Parse common options shared across commands
# Sets: OPT_MACHINE, OPT_JSON, OPT_TRANSITION, OPT_DRY_RUN
parse_options() {
    OPT_MACHINE=""
    OPT_JSON=false
    OPT_TRANSITION=""
    OPT_DRY_RUN=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --machine)
                OPT_MACHINE="$2"
                if ! is_valid_machine "$OPT_MACHINE"; then
                    print_error "Invalid machine: ${OPT_MACHINE}"
                    print_error "Valid machines: ${MACHINES[*]}"
                    exit 1
                fi
                shift 2
                ;;
            --json)
                OPT_JSON=true
                shift
                ;;
            --transition)
                OPT_TRANSITION="$2"
                shift 2
                ;;
            --dry-run)
                OPT_DRY_RUN=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

is_valid_machine() {
    local m="$1"
    for valid in "${MACHINES[@]}"; do
        [[ "$m" == "$valid" ]] && return 0
    done
    return 1
}

# --- Command Implementations ---

cmd_status() {
    parse_options "$@"

    local active_machine
    active_machine=$(determine_active_machine)

    local plan_state plan_detail code_state code_detail
    local merge_state merge_detail promote_state promote_detail

    plan_state=$(get_plan_state)
    plan_detail=$(get_plan_detail)
    code_state=$(get_code_state)
    code_detail=$(get_code_detail)
    merge_state=$(get_merge_state)
    merge_detail=$(get_merge_detail)
    promote_state=$(get_promote_state)
    promote_detail=$(get_promote_detail)

    if [[ -n "$OPT_MACHINE" ]]; then
        local state detail
        case "$OPT_MACHINE" in
            plan)    state="$plan_state"; detail="$plan_detail" ;;
            code)    state="$code_state"; detail="$code_detail" ;;
            merge)   state="$merge_state"; detail="$merge_detail" ;;
            promote) state="$promote_state"; detail="$promote_detail" ;;
        esac
        if [[ "$OPT_JSON" == "true" ]]; then
            echo "{ \"machine\": \"${OPT_MACHINE}\", \"state\": $(json_string "$state"), \"detail\": $(json_string "$detail"), \"active\": $([[ "$active_machine" == "$OPT_MACHINE" ]] && echo true || echo false) }"
        else
            echo ""
            local is_active="$([[ "$active_machine" == "$OPT_MACHINE" ]] && echo true || echo false)"
            print_machine_state "$OPT_MACHINE" "$state" "$detail" "$is_active"
            echo ""
        fi
        return
    fi

    if [[ "$OPT_JSON" == "true" ]]; then
        print_json_status "$active_machine" \
            "$plan_state" "$plan_detail" \
            "$code_state" "$code_detail" \
            "$merge_state" "$merge_detail" \
            "$promote_state" "$promote_detail"
    else
        print_status_table "$active_machine" \
            "$plan_state" "$plan_detail" \
            "$code_state" "$code_detail" \
            "$merge_state" "$merge_detail" \
            "$promote_state" "$promote_detail"
    fi
}

cmd_advance() {
    parse_options "$@"

    # Check for pending transition first
    if [[ -f "${REPO_ROOT}/${PENDING_FILE}" ]]; then
        handle_pending_transition "$OPT_DRY_RUN"
        return
    fi

    local active_machine
    if [[ -n "$OPT_MACHINE" ]]; then
        active_machine="$OPT_MACHINE"
    else
        active_machine=$(determine_active_machine)
    fi

    local current_state
    case "$active_machine" in
        plan)    current_state=$(get_plan_state) ;;
        code)    current_state=$(get_code_state) ;;
        merge)   current_state=$(get_merge_state) ;;
        promote) current_state=$(get_promote_state) ;;
    esac

    if [[ -z "$current_state" || "$current_state" == "inactive" ]]; then
        print_error "Machine '${active_machine}' is not active."
        exit 1
    fi

    # Get valid transitions
    local valid_transitions
    valid_transitions=($(get_valid_transitions "$active_machine" "$current_state"))

    if [[ ${#valid_transitions[@]} -eq 0 ]]; then
        echo ""
        print_warning "No transitions available from ${active_machine^} / ${current_state}."
        print_dim "The system may be waiting for an external event."
        echo ""
        return
    fi

    # If --transition specified, validate it exists in the transition table
    if [[ -n "$OPT_TRANSITION" ]]; then
        local found=false
        for tid in "${valid_transitions[@]}"; do
            if [[ "$tid" == "$OPT_TRANSITION" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            print_error "Transition ${OPT_TRANSITION} is not valid from ${active_machine^} / ${current_state}."
            print_error "Valid transitions: ${valid_transitions[*]}"
            exit 1
        fi

        # Dry-run with specific transition: always show details regardless of eligibility
        if [[ "$OPT_DRY_RUN" == "true" ]]; then
            print_explain "$OPT_TRANSITION" "$active_machine" "$current_state"
            if ! is_transition_eligible "$OPT_TRANSITION"; then
                print_warning "Note: This transition's preconditions are not currently met."
            fi
            return
        fi

        valid_transitions=("$OPT_TRANSITION")
    fi

    # Check eligibility
    local eligible_transitions=()
    for tid in "${valid_transitions[@]}"; do
        if is_transition_eligible "$tid"; then
            eligible_transitions+=("$tid")
        fi
    done

    if [[ ${#eligible_transitions[@]} -eq 0 ]]; then
        echo ""
        print_warning "No eligible transitions from ${active_machine^} / ${current_state}."
        echo ""
        print_dim "Valid transitions and why they're not eligible:"
        for tid in "${valid_transitions[@]}"; do
            local to desc preconditions
            to=$(get_transition_field "$tid" "to")
            desc=$(get_transition_field "$tid" "desc")
            preconditions=$(get_transition_field "$tid" "preconditions")
            echo "  ${tid}: ${current_state} -> ${to}  (${desc})"
            if [[ -n "$preconditions" ]]; then
                echo "    Preconditions not met: ${preconditions}"
            fi
        done
        echo ""
        return
    fi

    # Dry run mode (no specific transition)
    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        if [[ ${#eligible_transitions[@]} -eq 1 ]]; then
            print_explain "${eligible_transitions[0]}" "$active_machine" "$current_state"
        else
            print_transition_choice eligible_transitions "$active_machine" "$current_state"
            echo ""
            for tid in "${eligible_transitions[@]}"; do
                print_explain "$tid" "$active_machine" "$current_state"
            done
        fi
        return
    fi

    # Select transition
    local selected_tid
    if [[ ${#eligible_transitions[@]} -eq 1 ]]; then
        selected_tid="${eligible_transitions[0]}"
    else
        print_transition_choice eligible_transitions "$active_machine" "$current_state"
        local choice
        read -rp "Select transition [1-${#eligible_transitions[@]}]: " choice
        if [[ "$choice" -lt 1 || "$choice" -gt ${#eligible_transitions[@]} ]] 2>/dev/null; then
            print_error "Invalid choice."
            exit 1
        fi
        selected_tid="${eligible_transitions[$((choice - 1))]}"
    fi

    # Execute
    execute_transition "$selected_tid" "$active_machine" "$current_state"
}

cmd_list() {
    local what="${1:-}"
    shift 2>/dev/null || true

    case "$what" in
        functions) parse_options "$@"; print_functions_list "$OPT_MACHINE" ;;
        actions)   parse_options "$@"; print_actions_list "$OPT_MACHINE" ;;
        "")
            print_error "Usage: dsm list <functions|actions> [options]"
            exit 1
            ;;
        *)
            print_error "Unknown list type: ${what}. Use 'functions' or 'actions'."
            exit 1
            ;;
    esac
}
