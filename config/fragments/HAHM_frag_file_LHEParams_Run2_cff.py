import FWCore.ParameterSet.Config as cms
from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.Pythia8CP5Settings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *
generator = cms.EDFilter("Pythia8HadronizerFilter",
    #useExternalLHE = cms.bool(True),
    pythiaPylistVerbosity = cms.untracked.int32(0),
    filterEfficiency = cms.untracked.double(1.0),
    pythiaHepMCVerbosity = cms.untracked.bool(False),
    comEnergy = cms.double(13000.0),
    maxEventsToPrint = cms.untracked.int32(1),
    PythiaParameters = cms.PSet(
        pythia8CommonSettingsBlock,
        pythia8CP5SettingsBlock,
        pythia8PSweightsSettingsBlock,
        processParameters = cms.vstring(
            "Main:timesAllowErrors = 10000",
            "ParticleDecays:limitTau0 = on",
            "ParticleDecays:tau0Max = 100000",  # optional: allow long-lived decays
            "SLHA:useDecayTable = on",
            #"6000113:m0 = 20.0",
            '13:mayDecay = off',        # prevents muons from decaying
            '-13:mayDecay = off',
            'MultipartonInteractions:pTmin = 1.0', # Helps Pythia with balencing momentum
            'BeamRemnants:reconnectRange = 2.0',
            'SpaceShower:pTmaxMatch = 1',
            'SpaceShower:pTmaxFudge = 0.9',
            'HiddenValley:fragment = off',   # Applicable since ZD is not colored
            ),
	parameterSets = cms.vstring(
            'pythia8CommonSettings',
            'pythia8CP5Settings',
            'pythia8PSweightsSettings',
            'processParameters'
        )
    )
)
