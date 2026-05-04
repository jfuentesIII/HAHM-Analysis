from WMCore.Configuration import Configuration

config = Configuration()

config.section_("General")
config.General.workArea = 'work'
config.General.requestName = 'PLACEHOLDER_JOBTAG'
config.General.transferOutputs = True
config.General.transferLogs = True

config.section_("JobType")
config.JobType.pluginName = 'PrivateMC'
config.JobType.psetName = 'RAWSIM_cfg.py'
config.JobType.scriptExe = 'lhe_RAWSIM.sh'
config.JobType.inputFiles = ['lhe_RAWSIM.sh']
config.JobType.outputFiles = ['file:RAWSIM.root']
config.JobType.maxJobRuntimeMin = 500
config.JobType.numCores = 4
config.JobType.maxMemoryMB = 5000

config.section_("Data")
config.Data.outputPrimaryDataset = 'RAWSIM'
config.Data.splitting = 'EventBased'
config.Data.unitsPerJob = 500
config.Data.totalUnits = 10000
config.Data.publication = False
config.Data.outputDatasetTag = 'PLACEHOLDER_JOBTAG'
config.Data.outLFNDirBase = '/store/user/fuentesi/'

config.section_("Site")
config.Site.storageSite = 'T3_US_FNALLPC'
config.Site.whitelist = ['T3_US_Rutgers', 'T2_US_Caltech', 'T2_PL_Cyfronet', 'T2_HU_Budapest', 'T2_ES_CIEMAT', 'T2_KR_KISTI', 'T3_US_FNALLPC']
