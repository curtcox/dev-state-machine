#!/usr/bin/env bash
# constants.sh — Shared definitions for the dsm tool

# Directory paths (relative to repo root)
TODO_DIR="todo"
DOING_DIR="doing"
DONE_DIR="done"

# State files
PLAN_STATE_FILE="plan-state.md"
CODE_STATE_FILE="code-state.md"
PENDING_FILE=".dsm-pending"
QUALITY_GATES_FILE=".devstate/quality-gates.yml"

# Machine names
MACHINES=(plan code merge promote)

# Valid states per machine
PLAN_STATES=(idle planning decomposing test-listing ready blocked)
CODE_STATES=(red green refactor blocked)
MERGE_STATES=(pr-open reviewing changes-requested approved merged blocked)
PROMOTE_STATES=(deploying deployed validating promoted failed complete)

# Transition IDs per machine
PLAN_TRANSITIONS=(P1 P2 P3 P4 P5 P6 P7 P8 P9 P10 P11)
CODE_TRANSITIONS=(C1 C2 C3 C4 C5 C6 C7 C8 C9 C10 C11 C12 C13 C14 C15 C16)
MERGE_TRANSITIONS=(M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11)
PROMOTE_TRANSITIONS=(R1 R2 R3 R4 R5 R6 R7 R8 R9)

# Feature branch prefix
FEATURE_BRANCH_PREFIX="feature/plan-"

# Environment branches
ENV_BRANCHES=(dev test main)

# Tool version
DSM_VERSION="0.1.0"
