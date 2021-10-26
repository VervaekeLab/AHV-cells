function results = runExample()

%% example from sData
%setupData = setupDataClass;
%dataname = {'matfiles/m3072-20191204-1348-001_sessiondata.mat'}; 
%[spikes, predictors, trialNo, sData , idxTime, infoPredictors, uniquePredictors, uid ]...
%       = dataname_to_spikes_predictors( dataname, setupData );

%% example from a spikesPredictor file
load('matfiles/spikesPredictors.mat', 'spikes', 'predictors',  'trialNo', 'setup', 'session', 'infoPredictors')


%% run LNP
setupLNP = setupLNPClass; 
setupLNP.lambdaSmooth = 0.1;
setupLNP.runDecode = false;
setupLNP.saveToFile = false;
setupLNP.predNameSelect = infoPredictors ;
results = singleNeuronClassifier(spikes, predictors, infoPredictors, trialNo, setupLNP ) ;