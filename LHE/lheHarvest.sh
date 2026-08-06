#!/bin/bash
set -euo pipefail

# =============================================================================
# lheHarvest.sh - Post-process MadGraph output: unzip, rename, collect, tar.
#
# Takes a MadGraph process directory with completed runs and produces a
# tarball of LHE files named by their (mzd, ct) grid point.
#
# Usage:
#   ./lheHarvest.sh /path/to/PROC_HAHM_variableMW_v5_UFO_0
#   ./lheHarvest.sh /path/to/PROC_HAHM_variableMW_v5_UFO_0 --tar
# =============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../config/common.sh"

if [[ $# -lt 1 ]]; then
    echo "Usage: ./lheHarvest.sh /path/to/PROC_dir [--tar]"
    echo ""
    echo "  Unzips, renames (mzd_X_ct_Y.lhe), and collects all LHE files."
    echo "  --tar  Also create a tarball for transfer to EOS."
    exit 1
fi

PROC_DIR="$1"
EVENTS_DIR="${PROC_DIR}/Events"
DO_TAR=false
[[ "${2:-}" == "--tar" ]] && DO_TAR=true

if [[ ! -d "$EVENTS_DIR" ]]; then
    echo "ERROR: Events directory not found at ${EVENTS_DIR}" >&2
    exit 1
fi

num_mzd=${#mzd_values[@]}

# =============================================================================
# Step 1: Unzip .gz files
# =============================================================================
echo "Step 1: Unzipping LHE files..."
echo ""

for i in $(seq 1 "$TOTAL_JOBS"); do
    run_num=$(printf "%02d" "$i")
    run_dir="${EVENTS_DIR}/run_${run_num}"

    if [[ ! -d "$run_dir" ]]; then
        echo "  run_${run_num}: directory not found, skipping."
        continue
    fi

    gz_count=$(find "$run_dir" -name "*.gz" -type f | wc -l)
    if [[ $gz_count -gt 0 ]]; then
        find "$run_dir" -name "*.gz" -type f -exec gunzip {} \;
        echo "  run_${run_num}: unzipped ${gz_count} file(s)."
    else
        echo "  run_${run_num}: no .gz files (already unzipped or missing)."
    fi
done

echo ""

# =============================================================================
# Step 2: Rename LHE files to mzd_X_ct_Y.lhe
# =============================================================================
echo "Step 2: Renaming LHE files..."
echo ""

job_num=0
for ct in "${ct_values[@]}"; do
    for mzd in "${mzd_values[@]}"; do
        job_num=$(( job_num + 1 ))
        run_num=$(printf "%02d" "$job_num")
        run_dir="${EVENTS_DIR}/run_${run_num}"

        if [[ ! -d "$run_dir" ]]; then
            echo "  run_${run_num}: directory not found, skipping."
            continue
        fi

        lhe_file=$(find "$run_dir" -name "*.lhe" -type f | head -1)

        if [[ -z "$lhe_file" ]]; then
            echo "  run_${run_num}: no .lhe file found."
            continue
        fi

        new_name="$(dirname "$lhe_file")/mzd_${mzd}_ct_${ct}.lhe"

        if [[ "$lhe_file" == "$new_name" ]]; then
            echo "  run_${run_num}: already named mzd_${mzd}_ct_${ct}.lhe"
        else
            mv "$lhe_file" "$new_name"
            echo "  run_${run_num}: -> mzd_${mzd}_ct_${ct}.lhe"
        fi
    done
done

echo ""

# =============================================================================
# Step 3: Collect all LHE files into one directory
# =============================================================================
COLLECT_DIR="${EVENTS_DIR}/collected_lhe"
mkdir -p "$COLLECT_DIR"

echo "Step 3: Collecting LHE files into ${COLLECT_DIR}..."
echo ""

collected=0
for i in $(seq 1 "$TOTAL_JOBS"); do
    run_num=$(printf "%02d" "$i")
    run_dir="${EVENTS_DIR}/run_${run_num}"

    if [[ ! -d "$run_dir" ]]; then
        continue
    fi

    while IFS= read -r lhe_file; do
        filename=$(basename "$lhe_file")
        cp "$lhe_file" "${COLLECT_DIR}/"
        echo "  ${filename}"
        collected=$(( collected + 1 ))
    done < <(find "$run_dir" -name "*.lhe" -type f)
done

echo ""
echo "Collected ${collected}/${TOTAL_JOBS} LHE files."

# =============================================================================
# Step 4: Tarball (optional)
# =============================================================================
if $DO_TAR; then
    echo ""
    TAR_NAME="lhe_files.tar.gz"
    echo "Step 4: Creating tarball ${TAR_NAME}..."
    tar -czf "${EVENTS_DIR}/${TAR_NAME}" -C "$COLLECT_DIR" .
    tar_size=$(ls -lh "${EVENTS_DIR}/${TAR_NAME}" | awk '{print $5}')

    echo ""
    echo "=========================================="
    echo " Tarball created: ${EVENTS_DIR}/${TAR_NAME} (${tar_size})"
    echo ""
    echo " To copy to lxplus:"
    echo "   scp ${EVENTS_DIR}/${TAR_NAME} $(whoami)@lxplus.cern.ch:/path/to/destination/"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo " LHE files ready in: ${COLLECT_DIR}/"
    echo " To also create a tarball, re-run with --tar"
    echo "=========================================="
fi
