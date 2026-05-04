#!/bin/bash
set -euo pipefail

LHE="PLACEHOLDER_LHE"
SRC="root://cmseos.fnal.gov//store/user/fuentesi/lhe/Run2/${LHE}"

echo "Staging in ${SRC}"
xrdcp -f "${SRC}" "./${LHE}"
ls -lh "./${LHE}"

echo 'Running cmsRun'

ls -l PSet.py
cmsRun -j FrameworkJobReport.xml PSet.py
