#!/bin/bash
# =============================================================================
# common.sh — Shared configuration for HAHM-Analysis
#
# Source this file from any script:
#   source "$(dirname "${BASH_SOURCE[0]}")/../config/common.sh"
#
# What to edit:
#   - EOS_USER       : your EOS username
#   - mzd_values     : dark photon mass grid points
#   - ct_values      : proper lifetime grid points
#   - STEP_REGISTRY  : pipeline step definitions (add/remove/reorder steps)
# =============================================================================

# === Repository layout ===
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="${REPO_ROOT}/submission/templates"
SUBMISSION_DIR="${REPO_ROOT}/submission"
WORK_DIR="${SUBMISSION_DIR}/work"

# === EOS Configuration ===
EOS_REMOTE="root://cmseos.fnal.gov"
EOS_USER="fuentesi"
EOS_BASE="/store/user/${EOS_USER}"

# === Physics Grid ===
mzd_values=(0.25 1 5 10 20 30 40 50 60)
ct_values=(0 1 10 100 500 1000)
TOTAL_JOBS=$(( ${#mzd_values[@]} * ${#ct_values[@]} ))

# === Valid steps per run ===
VALID_RUN3_STEPS=(GENSIM DIGIHLT RAWRECO MINIAOD nTupRUN3)
VALID_RUN2_STEPS=(RAWSIM HLTSIM MINIAODSIM nTupRUN2)

# =============================================================================
# Step Registry
# =============================================================================
# Each entry defines a pipeline step. Fields (pipe-delimited):
#
#   1  tmpl_cfg          CMSSW config template filename
#   2  work_cfg          CMSSW config working copy filename
#   3  tmpl_crab         CRAB config template filename
#   4  work_crab         CRAB config working copy filename
#   5  input_mode        GENSIM_MODE | WTTR_MODE | EOS_MODE
#   6  input_eos_subdir  EOS subdirectory of the input step's output
#   7  input_tag_prefix  Job tag prefix used by the input step
#   8  tmpl_lhe          LHE staging script template (GENSIM_MODE only)
#   9  work_lhe          LHE staging script working copy (GENSIM_MODE only)
#  10  wttr_file         WTTR discovery filename (WTTR_MODE only)
#  11  eos_subdir        EOS subdirectory for this step's output
#
# Empty fields are left blank between pipes.
# =============================================================================
declare -A STEP_REGISTRY

# --- Run3 pipeline ---
STEP_REGISTRY[Run3_GENSIM]="tmp_GEN-SIM.py|GEN-SIM.py|tmp_crab_GENSIM.py|crab_GENSIM.py|GENSIM_MODE|||tmp_lhe_GENSIM.sh|lhe_GENSIM.sh||GENSIM"
STEP_REGISTRY[Run3_DIGIHLT]="tmp_DIGI-L1-DIGI2RAW-HLT.py|DIGI-L1-DIGI2RAW-HLT.py|tmp_crab_DIGIHLT.py|crab_DIGIHLT.py|EOS_MODE|GENSIM|GENSIM||||DIGIHLT"
STEP_REGISTRY[Run3_RAWRECO]="tmp_RAW2DIGI-L1Reco-RECO-RECOSIM.py|RAW2DIGI-L1Reco-RECO-RECOSIM.py|tmp_crab_RAWRECO.py|crab_RAWRECO.py|EOS_MODE|DIGIHLT|DIGIHLT||||RAWRECO"
STEP_REGISTRY[Run3_MINIAOD]="tmp_MiniAOD.py|MiniAOD.py|tmp_crab_MINIAOD.py|crab_MINIAOD.py|EOS_MODE|RAWRECO|RAWRECO||||MINIAOD"
STEP_REGISTRY[Run3_nTupRUN3]="tmp_ConfFile_cfg.py|ConfFile_cfg.py|tmp_crab_nTupRUN3.py|crab_nTupRUN3.py|EOS_MODE|MINIAOD|MINIAOD||||nTupRUN3"

# --- Run2 pipeline ---
STEP_REGISTRY[Run2_RAWSIM]="tmp_RAWSIM_cfg.py|RAWSIM_cfg.py|tmp_crab_RAWSIM.py|crab_RAWSIM.py|GENSIM_MODE|||tmp_lhe_RAWSIM.sh|lhe_RAWSIM.sh||RAWSIM"
STEP_REGISTRY[Run2_HLTSIM]="tmp_HLTSIM_cfg.py|HLTSIM_cfg.py|tmp_crab_HLTSIM.py|crab_HLTSIM.py|WTTR_MODE|RAWSIM|RAWSIM|||WTTR_HLTSIM.dat|HLTSIM"
STEP_REGISTRY[Run2_MINIAODSIM]="tmp_MINIAODSIM_cfg.py|MINIAODSIM_cfg.py|tmp_crab_MINIAODSIM.py|crab_MINIAODSIM.py|WTTR_MODE|HLTSIM|HLTSIM|||WTTR_MINIAODSIM.dat|MINIAOD"
STEP_REGISTRY[Run2_nTupRUN2]="tmp_ConfFile_cfg.py|ConfFile_cfg.py|tmp_crab_nTupRUN2.py|crab_nTupRUN2.py|EOS_MODE|MINIAOD|MINIAODSIM||||nTupRUN2"

# =============================================================================
# Shared functions
# =============================================================================

# Print valid steps for usage messages
usage_steps() {
    local run3_str run2_str
    run3_str=$(printf -- '-%s, ' "${VALID_RUN3_STEPS[@]}")
    run2_str=$(printf -- '-%s, ' "${VALID_RUN2_STEPS[@]}")
    echo "  -Run3 steps: ${run3_str%, }"
    echo "  -Run2 steps: ${run2_str%, }"
}

# Parse -Run2 or -Run3 flag. Sets RUN.
parse_run() {
    case "${1:-}" in
        -Run2) RUN="Run2" ;;
        -Run3) RUN="Run3" ;;
        *)
            echo "ERROR: first argument must be -Run2 or -Run3 (got '${1:-}')." >&2
            return 1
            ;;
    esac
}

# Parse step flag (e.g. -GENSIM). Requires RUN to be set. Sets STEP.
parse_step() {
    local step_arg="${1#-}"
    local -a valid_steps
    if [[ "$RUN" == "Run3" ]]; then
        valid_steps=("${VALID_RUN3_STEPS[@]}")
    else
        valid_steps=("${VALID_RUN2_STEPS[@]}")
    fi

    for s in "${valid_steps[@]}"; do
        if [[ "$step_arg" == "$s" ]]; then
            STEP="$s"
            return 0
        fi
    done

    echo "ERROR: unknown ${RUN} step '${1:-}'. Valid: ${valid_steps[*]}" >&2
    return 1
}

# Load step configuration from the registry. Requires RUN and STEP to be set.
# Sets: TMPL_CFG, WORK_CFG, TMPL_CRAB, WORK_CRAB, INPUT_MODE,
#       INPUT_EOS_SUBDIR, INPUT_TAG_PREFIX, TMPL_LHE_SH, WORK_LHE_SH,
#       WTTR_FILE, EOS_SUBDIR
# Also sets derived paths: TMPL_CFG_PATH, TMPL_CRAB_PATH, TMPL_LHE_PATH,
#       INPUT_BASE, WTTR_PATH, EOS_STEP_DIR
load_step_config() {
    local key="${RUN}_${STEP}"
    local entry="${STEP_REGISTRY[$key]:-}"
    if [[ -z "$entry" ]]; then
        echo "ERROR: no registry entry for '${key}'." >&2
        return 1
    fi

    IFS='|' read -r TMPL_CFG WORK_CFG TMPL_CRAB WORK_CRAB INPUT_MODE \
                    INPUT_EOS_SUBDIR INPUT_TAG_PREFIX TMPL_LHE_SH WORK_LHE_SH \
                    WTTR_FILE EOS_SUBDIR <<< "$entry"

    TMPL_CFG_PATH="${TEMPLATE_DIR}/${RUN}/${TMPL_CFG}"
    TMPL_CRAB_PATH="${TEMPLATE_DIR}/${RUN}/${TMPL_CRAB}"

    TMPL_LHE_PATH=""
    [[ -n "$TMPL_LHE_SH" ]] && TMPL_LHE_PATH="${TEMPLATE_DIR}/${RUN}/${TMPL_LHE_SH}"

    INPUT_BASE=""
    [[ -n "$INPUT_EOS_SUBDIR" ]] && INPUT_BASE="${EOS_BASE}/${INPUT_EOS_SUBDIR}"

    WTTR_PATH=""
    [[ -n "$WTTR_FILE" ]] && WTTR_PATH="${SUBMISSION_DIR}/${WTTR_FILE}"

    EOS_STEP_DIR="${EOS_BASE}/${EOS_SUBDIR}"
}

# Map a job number (1–TOTAL_JOBS) to its grid point and tag.
# Sets: mzd, ct, mzd_safe, ct_safe, job_tag
get_job_info() {
    local n=$1
    local idx=$(( n - 1 ))
    local ct_index=$(( idx / ${#mzd_values[@]} ))
    local mzd_index=$(( idx % ${#mzd_values[@]} ))

    mzd="${mzd_values[$mzd_index]}"
    ct="${ct_values[$ct_index]}"
    mzd_safe="${mzd/./p}"
    ct_safe="${ct/./p}"
    job_tag="${STEP}_mzd_${mzd_safe}_ct_${ct_safe}"
}
