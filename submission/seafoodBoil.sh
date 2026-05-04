#!/bin/bash
set -euo pipefail

# =============================================================================
# seafoodBoil.sh — Kill all CRAB tasks for a given analysis step.
#
# Usage:
#   ./seafoodBoil.sh -Run3 -GENSIM
#   ./seafoodBoil.sh -Run2 -HLTSIM
# =============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../config/common.sh"

if [[ $# -lt 2 ]]; then
    echo "Usage: ./seafoodBoil.sh -Run<#> -STEP"
    echo ""
    usage_steps
    exit 1
fi

parse_run "$1"; shift
parse_step "$1"; shift

# =============================================================================
# Pre-flight checks
# =============================================================================
echo "seafoodBoil: killing ${RUN} ${STEP} tasks"
echo ""

if ! command -v crab &>/dev/null; then
    echo "ERROR: 'crab' command not found. Source the CRAB environment first." >&2
    exit 1
fi

# =============================================================================
# Main loop
# =============================================================================
job_num=0

for ct in "${ct_values[@]}"; do
    for mzd in "${mzd_values[@]}"; do
        job_num=$(( job_num + 1 ))

        mzd_safe="${mzd/./p}"
        ct_safe="${ct/./p}"
        job_tag="${STEP}_mzd_${mzd_safe}_ct_${ct_safe}"
        task_dir="${WORK_DIR}/crab_${job_tag}"

        echo "=========================================="
        echo " Job ${job_num}/${TOTAL_JOBS}"
        echo " Job tag  : ${job_tag}"
        echo "=========================================="

        if [[ ! -d "$task_dir" ]]; then
            echo "SKIP: ${task_dir} not found. Moving on."
            echo ""
            continue
        fi

        echo "Killing..."
        if crab kill -d "$task_dir"; then
            echo "KILLED: ${job_tag}"
        else
            echo "WARNING: crab kill failed for ${job_tag}. Continuing." >&2
        fi

        echo ""
    done
done

echo "=========================================="
echo " seafoodBoil: ${RUN} ${STEP} complete."
echo " Attempted ${job_num}/${TOTAL_JOBS} tasks."
echo "=========================================="
