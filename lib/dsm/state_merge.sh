#!/usr/bin/env bash
# state_merge.sh — Merge machine: derive state from GitHub via gh CLI

get_merge_state() {
    if ! _gh_available; then
        echo "inactive"
        return
    fi

    local branch
    branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null)
    [[ -z "$branch" ]] && { echo "inactive"; return; }

    # Check for open PRs from this branch
    local pr_json
    pr_json=$(gh pr list --repo "$(get_repo_nwo)" --head "${branch}" --json state,reviewDecision,statusCheckRollup --limit 1 2>/dev/null)

    if [[ -z "$pr_json" || "$(echo "$pr_json" | _json_length)" -eq 0 ]]; then
        # No open PR — check for recently merged PR
        local merged_json
        merged_json=$(gh pr list --repo "$(get_repo_nwo)" --head "${branch}" --state merged --json state --limit 1 2>/dev/null)
        if [[ -n "$merged_json" && "$(echo "$merged_json" | _json_length)" -gt 0 ]]; then
            echo "merged"
        else
            echo "inactive"
        fi
        return
    fi

    local pr_state review_decision
    pr_state=$(echo "$pr_json" | _json_field 0 "state")
    review_decision=$(echo "$pr_json" | _json_field 0 "reviewDecision")

    case "$pr_state" in
        MERGED) echo "merged" ;;
        CLOSED) echo "inactive" ;;
        OPEN)
            # Check CI status
            local checks_failing
            checks_failing=$(echo "$pr_json" | _json_checks_failing)
            if [[ "$checks_failing" -gt 0 ]] 2>/dev/null; then
                echo "blocked"
                return
            fi
            # Check merge conflicts
            local pr_number
            pr_number=$(gh pr list --repo "$(get_repo_nwo)" --head "${branch}" --json number --limit 1 2>/dev/null | _json_field 0 "number")
            if [[ -n "$pr_number" ]]; then
                local mergeable
                mergeable=$(gh pr view "$pr_number" --repo "$(get_repo_nwo)" --json mergeable 2>/dev/null | _json_top_field "mergeable")
                if [[ "$mergeable" == "CONFLICTING" ]]; then
                    echo "blocked"
                    return
                fi
            fi
            # Check review state
            case "$review_decision" in
                CHANGES_REQUESTED) echo "changes-requested" ;;
                APPROVED) echo "approved" ;;
                *)
                    # Check if any reviews exist
                    if [[ -n "$pr_number" ]]; then
                        local review_count
                        review_count=$(gh pr view "$pr_number" --repo "$(get_repo_nwo)" --json reviews 2>/dev/null | _json_array_length "reviews")
                        if [[ "$review_count" -gt 0 ]] 2>/dev/null; then
                            echo "reviewing"
                        else
                            echo "pr-open"
                        fi
                    else
                        echo "pr-open"
                    fi
                    ;;
            esac
            ;;
        *) echo "inactive" ;;
    esac
}

get_merge_detail() {
    local state
    state=$(get_merge_state)
    case "$state" in
        inactive) ;;
        pr-open)  echo "PR open, awaiting review" ;;
        reviewing) echo "review in progress" ;;
        changes-requested) echo "changes requested" ;;
        approved) echo "approved, ready to merge" ;;
        merged) echo "merged" ;;
        blocked) echo "blocked (CI failure or conflicts)" ;;
    esac
}

ci_checks_status() {
    if ! _gh_available; then
        echo "unknown"
        return
    fi
    local branch
    branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null)
    local pr_json
    pr_json=$(gh pr list --repo "$(get_repo_nwo)" --head "${branch}" --json statusCheckRollup --limit 1 2>/dev/null)
    if [[ -z "$pr_json" || "$(echo "$pr_json" | _json_length)" -eq 0 ]]; then
        echo "none"
        return
    fi
    local failing
    failing=$(echo "$pr_json" | _json_checks_failing)
    local pending
    pending=$(echo "$pr_json" | _json_checks_pending)
    if [[ "$failing" -gt 0 ]] 2>/dev/null; then
        echo "failing"
    elif [[ "$pending" -gt 0 ]] 2>/dev/null; then
        echo "pending"
    else
        echo "passing"
    fi
}

# --- Internal helpers ---

_gh_available() {
    command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1
}

get_repo_nwo() {
    # Get owner/repo from git remote
    git -C "$REPO_ROOT" remote get-url origin 2>/dev/null | \
        sed -E 's|.*github\.com[:/]||; s|\.git$||'
}

# Simple JSON field extraction (avoids jq dependency)
# Falls back to jq if available, otherwise uses grep/sed
_json_field() {
    local index="$1" field="$2"
    if command -v jq &>/dev/null; then
        jq -r ".[${index}].${field}" 2>/dev/null
    else
        # Simple extraction for flat JSON
        sed -n "$((index + 1))p" 2>/dev/null | grep -oP "\"${field}\":\s*\"?\K[^\",$}]+" 2>/dev/null
    fi
}

_json_top_field() {
    local field="$1"
    if command -v jq &>/dev/null; then
        jq -r ".${field}" 2>/dev/null
    else
        grep -oP "\"${field}\":\s*\"?\K[^\",$}]+" 2>/dev/null
    fi
}

_json_length() {
    if command -v jq &>/dev/null; then
        jq 'length' 2>/dev/null
    else
        grep -c "}" 2>/dev/null || echo "0"
    fi
}

_json_array_length() {
    local field="$1"
    if command -v jq &>/dev/null; then
        jq ".${field} | length" 2>/dev/null
    else
        echo "0"
    fi
}

_json_checks_failing() {
    if command -v jq &>/dev/null; then
        jq '.[0].statusCheckRollup // [] | map(select(.conclusion == "FAILURE")) | length' 2>/dev/null
    else
        echo "0"
    fi
}

_json_checks_pending() {
    if command -v jq &>/dev/null; then
        jq '.[0].statusCheckRollup // [] | map(select(.status == "IN_PROGRESS" or .status == "PENDING")) | length' 2>/dev/null
    else
        echo "0"
    fi
}
