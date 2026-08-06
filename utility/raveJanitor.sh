#!/bin/bash
set -euo pipefail

# =============================================================================
# raveJanitor.sh - Clean up CRAB work directories and registry for a step.
#
# Usage:
#   ./raveJanitor.sh -Run3 -GENSIM
#   ./raveJanitor.sh -Run2 -HLTSIM
# =============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../config/common.sh"

if [[ $# -lt 2 ]]; then
    echo "Usage: ./raveJanitor.sh -Run<#> -STEP"
    echo ""
    usage_steps
    exit 1
fi

parse_run "$1"; shift
parse_step "$1"; shift

echo "raveJanitor: running cleanup for ${RUN} ${STEP}"
echo ""

# === Gather items to delete ===
items_to_delete=()

for ct in "${ct_values[@]}"; do
    for mzd in "${mzd_values[@]}"; do
        mzd_safe="${mzd/./p}"
        ct_safe="${ct/./p}"
        job_tag="${STEP}_mzd_${mzd_safe}_ct_${ct_safe}"
        crab_dir="${WORK_DIR}/crab_${job_tag}"

        if [[ -d "$crab_dir" ]]; then
            items_to_delete+=("$crab_dir")
        fi
    done
done

registry="${SUBMISSION_DIR}/submit_registry_${STEP}.log"
if [[ -f "$registry" ]]; then
    items_to_delete+=("$registry")
fi

if [[ ${#items_to_delete[@]} -eq 0 ]]; then
    echo "No ${STEP} work directories or registry found. Nothing to clean up."
    exit 0
fi

echo "Found the following items to delete:"
echo ""
for item in "${items_to_delete[@]}"; do
    echo "  ${item}"
done

echo ""
read -rp "Delete all ${#items_to_delete[@]} items? This cannot be undone. (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Aborted. Nothing was deleted."
    exit 0
fi

for item in "${items_to_delete[@]}"; do
    rm -rf "$item"
    echo "Deleted: ${item}"
done

echo ""
echo "=========================================="
echo " Cleanup complete. ${#items_to_delete[@]} items removed."
echo "=========================================="
