#!/bin/bash
set -euo pipefail

# =============================================================================
# rootCanal.sh - Download ROOT files from EOS, hadd, and optionally tarball.
#
# With -precise, downloads only the first ROOT file per job (no hadd).
#
# Usage:
#   ./rootCanal.sh -Run3 -GENSIM all
#   ./rootCanal.sh -Run3 -DIGIHLT 7
#   ./rootCanal.sh -Run2 -nTupRUN2 mzd 25
#   ./rootCanal.sh -Run2 -HLTSIM ct 100
#   ./rootCanal.sh -Run3 -RAWRECO both 10 100
#   ./rootCanal.sh -Run3 -RAWRECO -precise all
#   ./rootCanal.sh -Run3 -MINIAOD              # interactive prompt
# =============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../config/common.sh"

# Always create output relative to this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ $# -lt 2 ]]; then
    echo "Usage: ./rootCanal.sh -Run<#> -STEP [-precise] [filter]"
    echo ""
    usage_steps
    echo ""
    echo "  -precise     Download only the first ROOT file per job (no hadd)"
    echo ""
    echo "  Filters:"
    echo "    all              - all jobs"
    echo "    <number>         - single job by number (1-${TOTAL_JOBS})"
    echo "    mzd <value>      - all ct values for a given mzd"
    echo "    ct <value>       - all mzd values for a given ct"
    echo "    both <mzd> <ct>  - single parameter point"
    exit 1
fi

parse_run "$1"; shift
parse_step "$1"; shift
load_step_config

# =============================================================================
# Parse -precise flag
# =============================================================================
PRECISE=false
if [[ "${1:-}" == "-precise" ]]; then
    PRECISE=true
    shift
fi

# =============================================================================
# Parse filter: arguments or interactive prompt
# =============================================================================
if [[ $# -eq 0 ]]; then
    echo "rootCanal: running for ${RUN} ${STEP}"
    if $PRECISE; then echo "  Mode: precise (first file only)"; fi
    echo ""
    echo "Filter options:"
    echo "  all              - all ${TOTAL_JOBS} jobs"
    echo "  <number>         - single job by number (1-${TOTAL_JOBS})"
    echo "  mzd <value>      - all ct values for a given mzd"
    echo "  ct <value>       - all mzd values for a given ct"
    echo "  both <mzd> <ct>  - single parameter point"
    echo ""
    read -rp "Filter: " -a FILTER_ARGS
else
    FILTER_ARGS=("$@")
fi

if [[ ${#FILTER_ARGS[@]} -eq 0 ]]; then
    echo "ERROR: no filter provided. Aborting." >&2
    exit 1
fi

# =============================================================================
# Build list of job numbers to process
# =============================================================================
declare -a job_numbers=()

FILTER_MODE="${FILTER_ARGS[0]}"
FILTER_VAL1="${FILTER_ARGS[1]:-}"
FILTER_VAL2="${FILTER_ARGS[2]:-}"

case "$FILTER_MODE" in
    all)
        for n in $(seq 1 "$TOTAL_JOBS"); do
            job_numbers+=("$n")
        done
        ;;
    mzd)
        if [[ -z "$FILTER_VAL1" ]]; then
            echo "ERROR: mzd filter requires a value." >&2
            exit 1
        fi
        found=false
        for m in "${mzd_values[@]}"; do
            if [[ "$m" == "$FILTER_VAL1" ]]; then found=true; break; fi
        done
        if ! $found; then
            echo "ERROR: mzd=${FILTER_VAL1} not in grid. Available: ${mzd_values[*]}" >&2
            exit 1
        fi
        for n in $(seq 1 "$TOTAL_JOBS"); do
            get_job_info "$n"
            if [[ "$mzd" == "$FILTER_VAL1" ]]; then
                job_numbers+=("$n")
            fi
        done
        ;;
    ct)
        if [[ -z "$FILTER_VAL1" ]]; then
            echo "ERROR: ct filter requires a value." >&2
            exit 1
        fi
        found=false
        for c in "${ct_values[@]}"; do
            if [[ "$c" == "$FILTER_VAL1" ]]; then found=true; break; fi
        done
        if ! $found; then
            echo "ERROR: ct=${FILTER_VAL1} not in grid. Available: ${ct_values[*]}" >&2
            exit 1
        fi
        for n in $(seq 1 "$TOTAL_JOBS"); do
            get_job_info "$n"
            if [[ "$ct" == "$FILTER_VAL1" ]]; then
                job_numbers+=("$n")
            fi
        done
        ;;
    both)
        if [[ -z "$FILTER_VAL1" || -z "$FILTER_VAL2" ]]; then
            echo "ERROR: both filter requires mzd and ct values." >&2
            exit 1
        fi
        for n in $(seq 1 "$TOTAL_JOBS"); do
            get_job_info "$n"
            if [[ "$mzd" == "$FILTER_VAL1" && "$ct" == "$FILTER_VAL2" ]]; then
                job_numbers+=("$n")
                break
            fi
        done
        if [[ ${#job_numbers[@]} -eq 0 ]]; then
            echo "ERROR: mzd=${FILTER_VAL1}, ct=${FILTER_VAL2} not found in grid." >&2
            exit 1
        fi
        ;;
    *)
        if [[ "$FILTER_MODE" =~ ^[0-9]+$ ]] && (( FILTER_MODE >= 1 && FILTER_MODE <= TOTAL_JOBS )); then
            job_numbers+=("$FILTER_MODE")
        else
            echo "ERROR: invalid filter '${FILTER_MODE}'. Use: all, mzd, ct, both, or a job number." >&2
            exit 1
        fi
        ;;
esac

num_jobs=${#job_numbers[@]}

# =============================================================================
# Setup output directory
# =============================================================================
if $PRECISE; then
    OUTPUT_DIR="precise_${RUN}_${STEP}"
else
    OUTPUT_DIR="hadded_${RUN}_${STEP}"
fi

case "$FILTER_MODE" in
    mzd)
        mzd_safe_dir="${FILTER_VAL1/./p}"
        OUTPUT_DIR="${OUTPUT_DIR}_mzd_${mzd_safe_dir}"
        ;;
    ct)
        ct_safe_dir="${FILTER_VAL1/./p}"
        OUTPUT_DIR="${OUTPUT_DIR}_ct_${ct_safe_dir}"
        ;;
    both)
        mzd_safe_dir="${FILTER_VAL1/./p}"
        ct_safe_dir="${FILTER_VAL2/./p}"
        OUTPUT_DIR="${OUTPUT_DIR}_mzd_${mzd_safe_dir}_ct_${ct_safe_dir}"
        ;;
esac

mkdir -p "$OUTPUT_DIR"

MODE_LABEL="hadd"
if $PRECISE; then MODE_LABEL="precise (first file only)"; fi

echo ""
echo "=========================================="
echo " rootCanal: ${RUN} ${STEP}"
echo " Mode       : ${MODE_LABEL}"
echo " Filter     : ${FILTER_MODE} ${FILTER_VAL1} ${FILTER_VAL2}"
echo " Jobs       : ${num_jobs}"
echo " Output dir : ${OUTPUT_DIR}/"
echo "=========================================="
echo ""

# =============================================================================
# Process each job
# =============================================================================
failures=0

for n in "${job_numbers[@]}"; do
    get_job_info "$n"
    output_name="mzd_${mzd_safe}_ct_${ct_safe}.root"

    echo "=========================================="
    echo " Job ${n}/${TOTAL_JOBS}"
    echo " mzd=${mzd}, ct=${ct}"
    echo " Tag: ${job_tag}"
    echo " Output: ${output_name}"
    echo "=========================================="

    # Skip if already exists
    if [[ -f "${OUTPUT_DIR}/${output_name}" ]]; then
        echo "SKIP: ${output_name} already exists. Moving on."
        echo ""
        continue
    fi

    # --- Discover timestamp ---
    remote_dir="${EOS_STEP_DIR}/${job_tag}"
    echo "Querying EOS: ${remote_dir}..."

    timestamp_path=$(xrdfs "$EOS_REMOTE" ls "$remote_dir" 2>/dev/null | head -n 1 || true)

    if [[ -z "$timestamp_path" ]]; then
        echo "WARNING: no timestamp found for ${job_tag}. Skipping."
        failures=$(( failures + 1 ))
        echo ""
        continue
    fi

    echo "Found: ${timestamp_path}"

    # --- List ROOT files ---
    files_dir="${timestamp_path}/0000"

    mapfile -t root_files < <(xrdfs "$EOS_REMOTE" ls "$files_dir" 2>/dev/null | grep '\.root$' || true)

    if [[ ${#root_files[@]} -eq 0 ]]; then
        echo "WARNING: no ROOT files found for ${job_tag}. Skipping."
        failures=$(( failures + 1 ))
        echo ""
        continue
    fi

    echo "Found ${#root_files[@]} ROOT file(s)."

    if $PRECISE; then
        # --- Precise mode: download first file only ---
        first_file="${root_files[0]}"
        echo "Downloading $(basename "$first_file")..."
        xrdcp "${EOS_REMOTE}/${first_file}" "${OUTPUT_DIR}/${output_name}"
        echo "Done: $(ls -lh "${OUTPUT_DIR}/${output_name}" | awk '{print $5}')"
    else
        # --- Hadd mode: download all, hadd, clean up ---
        work_dir="rootCanal_tmp_${job_tag}"

        if [[ -e "$work_dir" ]]; then
            rm -rf "$work_dir"
        fi

        mkdir -p "$work_dir"

        echo "Downloading ${#root_files[@]} file(s)..."
        for f in "${root_files[@]}"; do
            echo "  -> $(basename "$f")"
            xrdcp "${EOS_REMOTE}/${f}" "${work_dir}/"
        done

        echo "Running hadd -> ${output_name}..."
        hadd -f "${OUTPUT_DIR}/${output_name}" "${work_dir}"/*.root

        rm -rf "$work_dir"
        echo "Done: $(ls -lh "${OUTPUT_DIR}/${output_name}" | awk '{print $5}')"
    fi

    echo ""
done

# =============================================================================
# Summary
# =============================================================================
file_count=$(find "$OUTPUT_DIR" -name '*.root' -type f | wc -l)
total_size=$(du -sh "$OUTPUT_DIR" | awk '{print $1}')

echo "=========================================="
echo " rootCanal complete."
echo ""
echo " Downloaded : ${file_count}/${num_jobs}"
echo " Total size : ${total_size}"
echo " Failures   : ${failures}"
echo " Output dir : ${SCRIPT_DIR}/${OUTPUT_DIR}/"
echo "=========================================="

# --- Optional tarball ---
if [[ $num_jobs -gt 1 ]]; then
    echo ""
    read -rp "Create tarball? (yes/no): " do_tar

    if [[ "$do_tar" == "yes" ]]; then
        tarball="${OUTPUT_DIR}.tar.gz"
        echo "Creating ${tarball}..."
        tar czf "$tarball" "$OUTPUT_DIR"
        echo ""
        echo "Tarball: ${tarball} ($(ls -lh "$tarball" | awk '{print $5}'))"
        echo ""
        echo "To pull locally:"
        echo "  scp $(whoami)@lxplus.cern.ch:${SCRIPT_DIR}/${tarball} ."
    else
        echo "No tarball created."
    fi
fi
