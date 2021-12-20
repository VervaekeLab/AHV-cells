classdef setupDataClass 
    properties
        
        % data
        setupID     = datestr(now,'yyyymmdd-HHMM')
        data        = ''
        protocol    = 'normal'
        tag         = ''
        %runTest     = ''
        dataType    = 'spikeSmooth'
        %trialType   = {''} %{'conjunctive'}
        useStationary  = false  
        useTrials   = ''
        nbins       = 12
        hdframe     = [0 360]
        hdcircular  = true
        spikesMethod = 'spikes2'
        speedThresh = 22.5
        spikeWindow = 25
        spikeRateOffset = 1e-6; %0.1
        tuningWidth = 90
        quanN       = 1
        quanT       = 1
        fixedN      = []
        fixedT      = []
        fixedNTrial = []
        speedBinWidth  = 45
        useStageSpeed  = true
        downsample     = false
        useOnlyHDCells = false
        predName       = {'Activity','Velocity','HD'}
        filterVelo     = []; 
        cutTime        = false;
        absoluteSpeed  = false
        
        
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
                
     end
end
