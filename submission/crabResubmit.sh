#!/bin/bash
set -euo pipefail

# =============================================================================
# crabResubmit.sh - Resubmit failed CRAB jobs by job number.
#
# Usage:
#   ./crabResubmit.sh -Run3 -GENSIM 3 7 12
#   ./crabResubmit.sh -Run2 -HLTSIM 5
#   ./crabResubmit.sh -Run3 -RAWRECO        # interactive prompt
# =============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../config/common.sh"

if [[ $# -lt 2 ]]; then
    echo "Usage: ./crabResubmit.sh -Run<#> -STEP [job numbers...]"
    echo ""
    usage_steps
    exit 1
fi

parse_run "$1"; shift
parse_step "$1"; shift

# =============================================================================
# Parse job numbers: from arguments or interactive prompt
# =============================================================================
if [[ $# -gt 0 ]]; then
    job_numbers=("$@")
else
    echo "crabResubmit: running for ${RUN} ${STEP}"
    echo ""
    echo "Enter job numbers to resubmit (space-separated, 1-${TOTAL_JOBS}):"
    read -rp "> " -a job_numbers
fi

if [[ ${#job_numbers[@]} -eq 0 ]]; then
    echo "ERROR: no job numbers provided. Aborting." >&2
    exit 1
fi

# Validate all job numbers before resubmitting anything
for n in "${job_numbers[@]}"; do
    if ! [[ "$n" =~ ^[0-9]+$ ]] || (( n < 1 || n > TOTAL_JOBS )); then
        echo "ERROR: invalid job number '${n}'. Must be 1-${TOTAL_JOBS}." >&2
        exit 1
    fi
done

# =============================================================================
# Resubmit
# =============================================================================
echo ""
echo "Resubmitting ${#job_numbers[@]} ${RUN} ${STEP} job(s)..."
echo ""

failures=0

for n in "${job_numbers[@]}"; do
    get_job_info "$n"

    crab_dir="${WORK_DIR}/crab_${job_tag}"

    echo "=========================================="
    echo " Job ${n}/${TOTAL_JOBS}"
    echo " Job tag  : ${job_tag}"
    echo " CRAB dir : ${crab_dir}"
    echo "=========================================="

    if [[ ! -d "$crab_dir" ]]; then
        echo "WARNING: directory '${crab_dir}' not found. Skipping."
        echo ""
        failures=$(( failures + 1 ))
        continue
    fi

    if crab resubmit -d "$crab_dir"; then
        echo "SUCCESS: ${job_tag} resubmitted."
    else
        echo "FAILED: could not resubmit ${job_tag}."
        failures=$(( failures + 1 ))
    fi

    echo ""
done

echo "=========================================="
echo " Resubmit complete."
echo " Attempted : ${#job_numbers[@]}"
echo " Failures  : ${failures}"
echo "=========================================="
