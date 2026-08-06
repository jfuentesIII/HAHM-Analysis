#!/bin/bash
set -euo pipefail

# =============================================================================
# mgScan.sh - Launch a MadGraph parameter scan for the HAHM model.
#
# Generates param_card.dat and run_card.dat from templates, stamps them
# with the physics grid and epsilon table from common.sh, copies them
# into the MadGraph process directory, and launches generate_events.
#
# Usage:
#   ./mgScan.sh -Run2 /path/to/PROC_dir
#   ./mgScan.sh -Run3 /path/to/PROC_dir
#   ./mgScan.sh -Run2 /path/to/PROC_dir -nevents 50000
#
# Prerequisites:
#   - MadGraph process directory already generated (via proc_card)
#   - Template cards in LHE/cards/
# =============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../config/common.sh"

CARD_DIR="${REPO_ROOT}/LHE/cards"

if [[ $# -lt 2 ]]; then
    echo "Usage: ./mgScan.sh -Run<#> /path/to/PROC_dir [-nevents N]"
    echo ""
    echo "  -Run2   13 TeV  (beam energy 6500 GeV)"
    echo "  -Run3   13.6 TeV (beam energy 6800 GeV)"
    echo ""
    echo "  -nevents N   Events per grid point (default: 10000)"
    exit 1
fi

parse_run "$1"; shift
PROC_DIR="$1"; shift

NEVENTS=10000
if [[ $# -ge 2 ]] && [[ "$1" == "-nevents" ]]; then
    NEVENTS="$2"
    shift 2
fi

EBEAM="${BEAM_ENERGY[$RUN]}"

# =============================================================================
# Validate
# =============================================================================
if [[ ! -d "$PROC_DIR" ]]; then
    echo "ERROR: process directory not found: ${PROC_DIR}" >&2
    exit 1
fi

if [[ ! -d "${PROC_DIR}/Cards" ]]; then
    echo "ERROR: no Cards/ directory in ${PROC_DIR}. Is this a MadGraph process dir?" >&2
    exit 1
fi

if [[ ! -f "${CARD_DIR}/param_card_template.dat" ]]; then
    echo "ERROR: param_card_template.dat not found in ${CARD_DIR}" >&2
    exit 1
fi

if [[ ! -f "${CARD_DIR}/run_card_template.dat" ]]; then
    echo "ERROR: run_card_template.dat not found in ${CARD_DIR}" >&2
    exit 1
fi

num_mzd=${#mzd_values[@]}
num_ct=${#ct_values[@]}

echo "=========================================="
echo " mgScan: ${RUN} HAHM parameter scan"
echo ""
echo " Process dir : ${PROC_DIR}"
echo " Beam energy : ${EBEAM} GeV (${RUN})"
echo " Events/point: ${NEVENTS}"
echo " Grid        : ${num_mzd} mzd x ${num_ct} ct = ${TOTAL_JOBS} points"
echo "=========================================="
echo ""

# =============================================================================
# Build scan strings from common.sh grid and epsilon table
# =============================================================================
echo "Building param_card scan lines..."

# mzd scan: repeat the mzd array once per ct value
mzd_scan=""
for (( ci=0; ci<num_ct; ci++ )); do
    for (( mi=0; mi<num_mzd; mi++ )); do
        [[ -n "$mzd_scan" ]] && mzd_scan+=","
        mzd_scan+="${mzd_values[$mi]}"
    done
done

# epsilon scan: read from the epsilon_table in grid order
epsilon_scan=""
for (( ci=0; ci<num_ct; ci++ )); do
    for (( mi=0; mi<num_mzd; mi++ )); do
        idx=$(( ci * num_mzd + mi ))
        [[ -n "$epsilon_scan" ]] && epsilon_scan+=","
        epsilon_scan+="${epsilon_table[$idx]}"
    done
done

echo "  mzd scan    : ${TOTAL_JOBS} values"
echo "  epsilon scan : ${TOTAL_JOBS} values"

# =============================================================================
# Stamp param_card
# =============================================================================
echo ""
echo "Generating param_card.dat..."

sed -e "s|PLACEHOLDER_MZD_SCAN|${mzd_scan}|g" \
    -e "s|PLACEHOLDER_EPSILON_SCAN|${epsilon_scan}|g" \
    "${CARD_DIR}/param_card_template.dat" > "${PROC_DIR}/Cards/param_card.dat"

echo "  Written to ${PROC_DIR}/Cards/param_card.dat"

# =============================================================================
# Stamp run_card
# =============================================================================
echo "Generating run_card.dat..."

sed -e "s|PLACEHOLDER_NEVENTS|${NEVENTS}|g" \
    -e "s|PLACEHOLDER_EBEAM|${EBEAM}|g" \
    "${CARD_DIR}/run_card_template.dat" > "${PROC_DIR}/Cards/run_card.dat"

echo "  Written to ${PROC_DIR}/Cards/run_card.dat"

# =============================================================================
# Launch MadGraph
# =============================================================================
echo ""
echo "=========================================="
echo " Cards are ready. To launch the scan:"
echo ""
echo "   cd ${PROC_DIR}"
echo "   ./bin/generate_events -f"
echo ""
echo " After completion, post-process with:"
echo ""
echo "   ./LHE/lheHarvest.sh ${PROC_DIR} --tar"
echo "=========================================="
