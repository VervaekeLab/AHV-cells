classdef setupLNPClass 
    properties
        
        % data
        setupID     = datestr(now,'yyyymmdd-HHMM')
        runTest     = ''
        tag         = ''
        data        = ''
        %trialType   = {''} %{'conjunctive'}
        useStationary  = false  
        useTrials   = ''
        nbins       = 12
        hdframe     = [0 360]
        hdcircular  = true
        dataType    = 'spikeSmooth'
        spikesMethod = 'spikes2'
        speedThresh = 22.5
        spikeWindow = 25
        spikeRateOffset = 1e-6; %0.1
        neuronOrder = 'noOrder'
        tuningWidth = 90
        quanN       = 1
        quanT       = 1
        fixedN      = []
        fixedT      = []
        fixedNTrial = []
        speedBinWidth  = 45
        useStageSpeed  = true
        downsample     = false
        selectCells    = 'all'
        useOnlyHDCells = false
        predName       = {'Activity','Velocity','HD'}
        filterVelo     = []; 
        cutTime        = false;
        absoluteSpeed  = false
        protocol    = 'normal'
        
        % algorithm LNP
        method      = 'lnp'
        distrib     = 'poisson'
        link        = 'log'
        fitMethod   = 'fminsearch'  % 'glmfit'
        verboseSearch = true;
        shuffleTime = 0
        kfold       = 8 % cross validation
        kfoldMax    = 8 % cross validation
        crossValMethod = 'leaveOneOutTrial'
        monteCarloPctTrain = 0.5
        plotResults = 1
        saveToFile  = 1
        lambdaSmooth = 0.01 % 100
        lambdaJump  = 10
        deltaTime   = 10
        ATI         = 0
        interlaceTrainTest = false
        runDecode   = true
        plotLogL    = false;
        makeVideoLogL = false;
        predNameSelect = {{'None'}, {'Velocity'}}
        nTrialTrain = []
        nTrialTest = []
        nDecode = []
        method_lnp_new = []
        parallelComputing = true;
        
    end
    methods
        
%          % TrialType
%          function obj=set.trialType(obj,value)
%            
%              obj.trialType = value;
%              trialTypeAccepted = {
%                  ''
%                  'rotation'
%                 'headnbins'
%                 'conjunctive'
%                 'conjunctiveBM'
%                 'conjunctiveWithStationary'
%                 'speedMod'
%                 'speedModStationary'
%                 'speedModContinuous'
%                 'conjSpeedMod'
%                 'conjSpeedModulation'
%                 'speedAcceleration'
%                 'speedActivity'
%                 'ActivityRotationVelo'
%                 'ActivityRotationAbsSpeed'
%                 'HDVeloActivity'};
%              if ~iscell(value), value={value}; end
%              for i = 1:length(value)
%                  match=strcmp(value{i},trialTypeAccepted);
%                  if all(match==0)open method
%                      txt=sprintf('TrialType %s not defined', value{i});
%                      error(txt)
%                  end
%              end
%          end
        
        % Method
        function obj=set.method(obj,value)
          
            obj.method = value;
            methodAccepted = {
                'lnp'
                'pearson'
                'glm'
                'mnr'
                'mahal'
                'svm'};
            if ~iscell(value), value={value}; end
            for i = 1:length(value)
                match=strcmp(value{i},methodAccepted);
                if all(match==0)
                    txt=sprintf('Method %s not defined', value{i});
                    error(txt)
                end
            end
        end
        
        % dataType
        function obj=set.dataType(obj,value)
          
            obj.dataType = value;
            dataTypeAccepted = {
                'dff'
                'spike'
                'spikeSmooth'
                'deconvolved'
                };
            if ~iscell(value), value={value}; end
            for i = 1:length(value)
                match=strcmp(value{i},dataTypeAccepted);
                if all(match==0)
                    txt=sprintf('dataType %s not defined', value{i});
                    error(txt)
                end
            end
        end
        
        % neuronOrder
        function obj=set.neuronOrder(obj,value)
            
            obj.neuronOrder = value;
            neuronOrderAccepted = {
                'topinfo'
                'noOrder'
                'hdscore'
                'random'
                'stability'
                };
            if ~iscell(value), value={value}; end
            for i = 1:length(value)
                match=strcmp(value{i},neuronOrderAccepted);
                if all(match==0)
                    txt=sprintf('dataType %s not defined', value{i});
                    error(txt)
                end
            end
        end
        
        % Method
        function obj=set.crossValMethod(obj,value)
          
            obj.crossValMethod = value;
            accepted = {
                'leaveOneOut'
                'keepOneIn' 
                'monteCarlo'
                'leaveOneOutTrial'
                'keepOneInTrial' 
                };
            if ~iscell(value), value={value}; end
            for i = 1:length(value)
                match=strcmp(value{i},accepted);
                if all(match==0)
                    txt=sprintf('crossValMethod %s not allowed', value{i});
                    error(txt)
                end
            end
        end
        
        
        % selectCells
        function obj=set.selectCells(obj,value)
            
            obj.selectCells = value;
            accepted = {
                'all'
                'HDScore'
                'HDScorePct'
                'IPct'
                'classicHD'
                'Stab1'
                'Stab2'
                'Stab3'
                'Kappa'
                };
            if ~iscell(value), value={value}; end
            for i = 1:length(value)
                match=strcmp(value{i},accepted);
                if all(match==0)
                    txt=sprintf('selectCells %s not defined', value{i});
                    error(txt)
                end
            end
        end
        
        
        % lambdaJump
        % function obj=set.lambdaJump(obj,value)
        %      obj.trialType = value;
        % end
        
    end
end
