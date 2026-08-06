#!/bin/bash
set -euo pipefail

# =============================================================================
# raveVision.sh - Monitor CRAB job status across all analysis steps and runs.
#
# Usage:
#   ./raveVision.sh -Run3 -GENSIM all
#   ./raveVision.sh -Run3 -DIGIHLT 7
#   ./raveVision.sh -Run3 -RAWRECO 3 7 12
#   ./raveVision.sh -Run2 -HLTSIM        # interactive prompt
# =============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../config/common.sh"

if [[ $# -lt 2 ]]; then
    echo "Usage: ./raveVision.sh -Run<#> -STEP [all|job_numbers...]"
    echo ""
    usage_steps
    echo ""
    echo "  all           - full scan of all jobs"
    echo "  3 7 12        - check specific job numbers"
    exit 1
fi

parse_run "$1"; shift
parse_step "$1"; shift

# =============================================================================
# Helper: check a single job and classify its status
# =============================================================================
check_job() {
    local n=$1
    get_job_info "$n"
    crab_dir="${WORK_DIR}/crab_${job_tag}"

    echo "=========================================="
    echo " Job ${n}/${TOTAL_JOBS}"
    echo " Job tag  : ${job_tag}"
    echo " CRAB dir : ${crab_dir}"
    echo "=========================================="

    if [[ ! -d "$crab_dir" ]]; then
        echo "WARNING: directory '${crab_dir}' not found. Job may not have been submitted."
        not_submitted_jobs+=("$n")
        echo ""
        return
    fi

    status_output=$(crab status -d "$crab_dir" --verboseErrors 2>&1) || true
    echo "$status_output"

    if echo "$status_output" | grep -q "Jobs status:.*finished.*100\.0%"; then
        finished_jobs+=("$n")
    elif echo "$status_output" | grep -v "Warning:" | grep -qi "failed"; then
        failed_jobs+=("$n")
    elif echo "$status_output" | grep -qi "running\|transferring\|cooloff"; then
        running_jobs+=("$n")
    elif echo "$status_output" | grep -qi "idle\|unsubmitted"; then
        idle_jobs+=("$n")
    else
        other_jobs+=("$n")
    fi

    echo ""
}

# =============================================================================
# Helper: print summary
# =============================================================================
print_summary() {
    local checked=$1

    echo "=========================================="
    echo " Scan complete. ${checked} job(s) checked."
    echo ""
    echo " Finished      : ${#finished_jobs[@]}"
    echo " Running       : ${#running_jobs[@]}"
    echo " Idle          : ${#idle_jobs[@]}"
    echo " Failed        : ${#failed_jobs[@]}"
    echo " Not submitted : ${#not_submitted_jobs[@]}"

    if [[ ${#other_jobs[@]} -gt 0 ]]; then
        echo " Other         : ${#other_jobs[@]}"
    fi

    if [[ ${#failed_jobs[@]} -gt 0 ]]; then
        failed_list=$(IFS=', '; echo "${failed_jobs[*]}")
        failed_args=$(IFS=' '; echo "${failed_jobs[*]}")
        echo ""
        echo " Jobs needing resubmission: ${failed_list}"
        echo ""
        echo " To resubmit, run:"
        echo "   ./crabResubmit.sh -${RUN} -${STEP} ${failed_args}"
    fi

    if [[ ${#running_jobs[@]} -gt 0 ]]; then
        running_list=$(IFS=', '; echo "${running_jobs[*]}")
        echo ""
        echo " Jobs still running: ${running_list}"
    fi

    if [[ ${#idle_jobs[@]} -gt 0 ]]; then
        idle_list=$(IFS=', '; echo "${idle_jobs[*]}")
        echo ""
        echo " Jobs idle/queued: ${idle_list}"
    fi

    if [[ ${#not_submitted_jobs[@]} -gt 0 ]]; then
        not_submitted_list=$(IFS=', '; echo "${not_submitted_jobs[*]}")
        echo ""
        echo " Jobs not submitted: ${not_submitted_list}"
    fi

    echo "=========================================="
}

# =============================================================================
# Parse mode: argument(s) or interactive prompt
# =============================================================================
if [[ $# -eq 0 ]]; then
    echo "raveVision: running for ${RUN} ${STEP}"
    echo ""
    echo "Options:"
    echo "  all                - full scan of all ${TOTAL_JOBS} jobs"
    echo "  1-${TOTAL_JOBS}              - check specific job number(s), space-separated"
    echo ""
    read -rp "Enter choice: " -a ARGS
else
    ARGS=("$@")
fi

if [[ ${#ARGS[@]} -eq 0 ]]; then
    echo "ERROR: no choice provided. Aborting." >&2
    exit 1
fi

# === Initialize status arrays ===
finished_jobs=()
failed_jobs=()
running_jobs=()
idle_jobs=()
not_submitted_jobs=()
other_jobs=()

# =============================================================================
# Execute
# =============================================================================
if [[ "${ARGS[0]}" == "all" ]]; then
    echo ""
    echo "Running full scan of ${TOTAL_JOBS} ${RUN} ${STEP} jobs..."
    echo ""

    for n in $(seq 1 "$TOTAL_JOBS"); do
        check_job "$n"
    done

    print_summary "$TOTAL_JOBS"

else
    # Validate all job numbers first
    for n in "${ARGS[@]}"; do
        if ! [[ "$n" =~ ^[0-9]+$ ]] || (( n < 1 || n > TOTAL_JOBS )); then
            echo "ERROR: invalid job number '${n}'. Must be 1-${TOTAL_JOBS}." >&2
            exit 1
        fi
    done

    echo ""
    echo "Checking ${#ARGS[@]} ${RUN} ${STEP} job(s)..."
    echo ""

    for n in "${ARGS[@]}"; do
        check_job "$n"
    done

    print_summary "${#ARGS[@]}"
fi
