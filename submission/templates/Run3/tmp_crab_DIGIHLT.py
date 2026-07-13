from WMCore.Configuration import Configuration

config = Configuration()

config.section_("General")
config.General.workArea = 'work'
config.General.requestName = 'PLACEHOLDER_JOBTAG'
config.General.transferOutputs = True
config.General.transferLogs = True

config.section_("JobType")
config.JobType.pluginName = 'ANALYSIS'
config.JobType.psetName = 'DIGI-L1-DIGI2RAW-HLT.py'
config.JobType.allowUndistributedCMSSW = True
config.JobType.maxJobRuntimeMin = 300
config.JobType.maxMemoryMB = 16000
config.JobType.numCores = 8

config.section_("Data")
config.Data.userInputFiles = PLACEHOLDER_INPUTFILES

config.Data.outputPrimaryDataset = 'DIGIHLT'
config.Data.splitting = 'FileBased'
config.Data.unitsPerJob = 1
config.Data.publication = False
config.Data.outputDatasetTag = 'PLACEHOLDER_JOBTAG'
config.Data.outLFNDirBase = '/store/user/fuentesi/'

config.section_("Site")
config.Site.storageSite = 'T3_US_FNALLPC'
config.Site.whitelist = ['T3_US_Rutgers', 'T2_US_Caltech', 'T2_PL_Cyfronet', 'T2_HU_Budapest', 'T2_ES_CIEMAT', 'T2_KR_KISTI', 'T3_US_FNALLPC']

