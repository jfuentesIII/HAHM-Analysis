#!/bin/bash
set -euo pipefail

# =============================================================================
# ravePregame.sh - EOS discovery for WTTR_MODE steps.
#
# Run this OUTSIDE the VM on your normal cmslpc shell where xrdfs works.
# It queries EOS for input ROOT files and writes a WTTR discovery file
# for use by crabRave.sh inside the VM.
#
# Usage:
#   ./ravePregame.sh -Run2 -HLTSIM
#   ./ravePregame.sh -Run2 -MINIAODSIM
# =============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../config/common.sh"

if [[ $# -lt 2 ]]; then
    echo "Usage: ./ravePregame.sh -Run<#> -STEP"
    echo ""
    usage_steps
    echo ""
    echo "Discovers EOS inputs for WTTR_MODE steps."
    echo "Run this OUTSIDE the VM where xrdfs is available."
    exit 1
fi

parse_run "$1"; shift
parse_step "$1"; shift
load_step_config

if [[ "$INPUT_MODE" != "WTTR_MODE" ]]; then
    echo "ERROR: ${RUN} ${STEP} does not use WTTR mode (input_mode=${INPUT_MODE})." >&2
    echo "  ravePregame is only needed for WTTR_MODE steps." >&2
    exit 1
fi

# =============================================================================
# Pre-flight checks
# =============================================================================
echo "ravePregame: discovering inputs for ${RUN} ${STEP}"
echo ""

if ! command -v xrdfs &>/dev/null; then
    echo "ERROR: 'xrdfs' command not found. Are you on cmslpc (outside the VM)?" >&2
    exit 1
fi

echo "Discovering ${INPUT_TAG_PREFIX} outputs for ${TOTAL_JOBS} jobs..."
echo ""

# =============================================================================
# Discovery loop
# =============================================================================
echo "# ravePregame ${RUN} ${STEP} discovery - $(date)" > "$WTTR_PATH"
echo "# jobTag|inputFileList" >> "$WTTR_PATH"

discovered=0
errors=0

for ct in "${ct_values[@]}"; do
    for mzd in "${mzd_values[@]}"; do
        mzd_safe="${mzd/./p}"
        ct_safe="${ct/./p}"
        input_tag="${INPUT_TAG_PREFIX}_mzd_${mzd_safe}_ct_${ct_safe}"
        job_tag="${STEP}_mzd_${mzd_safe}_ct_${ct_safe}"
        input_dir="${INPUT_BASE}/${input_tag}"

        echo "Querying: ${input_dir}..."

        timestamp_path=$(xrdfs "$EOS_REMOTE" ls "$input_dir" 2>/dev/null | head -n 1 || true)

        if [[ -z "$timestamp_path" ]]; then
            echo "  ERROR: no timestamp directory found for ${input_tag}." >&2
            errors=$(( errors + 1 ))
            continue
        fi

        mapfile -t root_files < <(xrdfs "$EOS_REMOTE" ls "${timestamp_path}/0000" 2>/dev/null | grep '\.root$' || true)

        if [[ ${#root_files[@]} -eq 0 ]]; then
            echo "  ERROR: no ROOT files found for ${input_tag}." >&2
            errors=$(( errors + 1 ))
            continue
        fi

        # Build Python-style list
        input_list="["
        for f in "${root_files[@]}"; do
            input_list+="'${f}', "
        done
        input_list="${input_list%, }]"

        echo "${job_tag}|${input_list}" >> "$WTTR_PATH"
        discovered=$(( discovered + 1 ))
        echo "  Found ${#root_files[@]} file(s)."
    done
done

echo ""
echo "=========================================="
echo " Discovery complete."
echo " Discovered : ${discovered}/${TOTAL_JOBS}"
echo " Errors     : ${errors}"
echo " Output     : ${WTTR_PATH}"
echo "=========================================="

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "WARNING: ${errors} job(s) had missing or empty directories."
    echo "  Check that all ${INPUT_TAG_PREFIX} jobs completed before proceeding."
fi
