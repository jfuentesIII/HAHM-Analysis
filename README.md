HAHM-Analysis
==============

Toolkit for private Monte Carlo production of Hidden Abelian Higgs Model (HAHM)
samples targeting dark photon (ZD) searches. Supports Run 2 (13 TeV) and
Run 3 (13.6 TeV) CMS workflows using CRAB for grid job submission.


Signal Grid
-----------

9 dark photon masses (mzd): 0.25, 1, 5, 10, 20, 30, 40, 50, 60 GeV
6 proper lifetimes (ct):    0, 1, 10, 100, 500, 1000 mm
= 54 signal points per run era


Workflow Pipelines
------------------

Run 3: LHE -> GEN-SIM -> DIGI-HLT -> RAW-RECO -> MiniAOD -> nTuplizer
Run 2: LHE -> RAWSIM -> HLTSIM -> MINIAODSIM -> nTuplizer

Run 3 uses CMSSW_14_0_21_patch4 (CMSSW_15_0_17 for MiniAOD/nTup).
Run 2 uses CMSSW_10_6_20 inside a Singularity VM.


Repository Layout
-----------------

config/
  common.sh              Shared configuration: EOS user, physics grid, step
                         registry, and helper functions. Edit this file to
                         adapt the suite for your own analysis.
  fragments/             Pythia8 hadronizer fragments (Run 2 and Run 3).

submission/
  crabRave.sh            Submit CRAB jobs for any step/run.
  crabResubmit.sh        Resubmit failed jobs by job number.
  seafoodBoil.sh         Kill all CRAB tasks for a step.
  ravePregame.sh         Discover EOS inputs for WTTR_MODE steps (run outside VM).
  templates/Run2/        CRAB config templates for Run 2 steps.
  templates/Run3/        CRAB config templates for Run 3 steps.

utility/
  raveVision.sh          Monitor CRAB job status (finished/running/failed/idle).
  raveJanitor.sh         Clean up work directories and registry logs.
  rootCanal.sh           Download ROOT files from EOS, hadd, and optionally tarball.

docs/
  cmsDriver_commands.txt Reference for all cmsDriver.py commands and manual edits.


Quick Start
-----------

1. Edit config/common.sh:
   - Set EOS_USER to your username.
   - Adjust mzd_values and ct_values if your grid differs.
   - Add or modify entries in STEP_REGISTRY for custom pipeline steps.

2. Generate CMSSW configs using the commands in docs/cmsDriver_commands.txt.
   Place the resulting template configs in submission/templates/Run2 or Run3.

3. Submit jobs:
     ./submission/crabRave.sh -Run3 -GENSIM
     ./submission/crabRave.sh -Run3 -GENSIM -batch 1    (first half only)

4. Monitor:
     ./utility/raveVision.sh -Run3 -GENSIM all
     ./utility/raveVision.sh -Run3 -GENSIM 3 7 12

5. Resubmit failures:
     ./submission/crabResubmit.sh -Run3 -GENSIM 3 7 12

6. Download results:
     ./utility/rootCanal.sh -Run3 -nTupRUN3 all
     ./utility/rootCanal.sh -Run3 -nTupRUN3 mzd 10
     ./utility/rootCanal.sh -Run3 -nTupRUN3 -precise all


Run 2 VM Notes
--------------

Run 2 intermediate steps (HLTSIM, MINIAODSIM) run inside a Singularity VM
where xrdfs is unavailable. Before submitting these steps from inside the VM,
run the discovery script from your normal cmslpc shell:

  ./submission/ravePregame.sh -Run2 -HLTSIM
  ./submission/ravePregame.sh -Run2 -MINIAODSIM

This generates WTTR discovery files that crabRave.sh reads inside the VM.


Other Utilities
---------------

Kill all tasks for a step:
  ./submission/seafoodBoil.sh -Run3 -DIGIHLT

Clean up work directories and registry:
  ./utility/raveJanitor.sh -Run3 -DIGIHLT
