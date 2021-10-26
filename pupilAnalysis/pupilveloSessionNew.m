function Results = pupilveloSession(session,in_light,walls_only,selectTrialFactor,tag, plotfig1,plotfig2,plotfig3,plotfig4, rootdir, timeCut)

addpath(localpath('projdir'))
smoothFactor = 5;
Results = [];

% Check inputs
if nargin<11, error('nargin<11?'), end
if ~exist('rootdir','var'), rootdir = sprintf('%s/LinearNonLinearPoisson/tmp',projdir); end

% Check session
sessionID = session.sessionID;
fprintf(1,'%s...',sessionID)
if ~isfield(session,'pupilCenter')
    fprintf(1,'no pupil data\n')
    return
else
    fprintf(1,'yes pupil data\n')
end


% Get session meta data
fovLocationName = session.fovLocationName ;
protocol = session.experimentInfo.sessionProtocol;
trialSummary = session.trialSummary;
rotatingCW = session.trialSummary.rotatingCW;
rotatingCCW = session.trialSummary.rotatingCCW;
rotationLength = session.trialSummary.rotationLength;
stageSpeed = session.trialSummary.stageSpeed;


% Get pupil data
if size(session.pupilCenter,3) == 2
    % good 
elseif size(session.pupilCenter,1) == 2
    tmp1 = session.pupilCenter(1,:); 
    tmp2 = session.pupilCenter(2,:);
    tmp(:,:,1) = tmp1;
    tmp(:,:,2) = tmp2;
    session.pupilCenter = tmp;
    fprintf(1,'fixed pupilCenter dimension\n');
else
    error('pupilCenter dimension error')
end
pupilx  = squeeze(session.pupilCenter(:,:,1));
pupily  = squeeze(session.pupilCenter(:,:,2));    
[coeff,score] = pca([pupilx', pupily']);

if isnan(score)
    fprintf(1,'pupilx/pupily is all NaNs\n')
    Results = [];
    return
end

pupil1 = score(:,1).';
pupil2 = score(:,2).';
velocity = session.velocity;
stagePositions = session.stagePositions;
rotationLength = session.trialSummary.rotationLength;

% Scale to [-1,1]
%pupil1 = normalize(pupil1, 'range');
%pupil1 = 2*pupil1 -1;
%pupil1 = pupil1 - nanmedian(pupil1);
pupil1 = pupil1 - nanmean(pupil1);
dpupil1 = [0, diff(pupil1)];

%pupil2 = normalize(pupil2, 'range');
%pupil2 = 2*pupil2 -1;
%pupil2 = pupil2 - nanmedian(pupil2);
pupil2 = pupil2 - nanmean(pupil2);
dpupil2 = [0, diff(pupil2)];

if (0)
    %         % Identify resets
    %pupilResetIdx = ( abs(dpupil1) > 0.15);
    %         qAbsDPupil = quantile( abs(dpupil1), quantileReset );
    %         pupilResetIdx = ( abs(dpupil1) > qAbsDPupil );
    %
    %
    %         % Get pupil movements removing resets (not used)
    %         if(0)
    %             dpupil1NoReset = dpupil1;
    %             dpupil1NoReset(pupilResetIdx) = 0;
    %             pupil1NoReset = pupil1(1) + cumsum(dpupil1NoReset,'omitnan');
    %         end
end

% Trial Start
uniqTrialNo = unique(session.trialSummary.trialNo); uniqTrialNo(uniqTrialNo==0) = [];
trialStart = nan(1,length(uniqTrialNo));
for i = 1:length(uniqTrialNo)
    idxT1 = find( session.trialNo == uniqTrialNo(i), 1, 'first' ) ;
    trialStart(i) = idxT1;
    idxT1 = find( session.trialNo == uniqTrialNo(i), 1, 'last' ) ;
    trialEnd(i) = idxT1;
end
clear i




%% Get velocity from pupil
%switch selectTrialFactor
%    case 'rotationLength'
%        trialFactor = rotationLength;
%    case 'stageSpeed'
%        trialFactor = stageSpeed;
%end
trialFactor = session.trialSummary.(selectTrialFactor);
uniqTrialFactor = unique(trialFactor); 
windowSize = 33; %11; %33; %33; %11;
quantileReset = 0.95;
threshStdDPupil = 5;
removeConsecutive = true;
[ freqPupilReset, pupilResetIdx ] = velocityFromPupilReset(session,'windowSize',windowSize,...
    'quantileReset', quantileReset, 'removeConsecutive', removeConsecutive, 'showPlots',true, 'smoothdPupilSize', 3, 'threshStdDPupil', threshStdDPupil);


%freqPupilReset = abs(freqPupilReset);
%warning('absolute freq')



%% Collect

clear Results
for cw_ccw = {'CW','CCW'}
    
    nTrialFactor = length(uniqTrialFactor);
    for iFactor = 1:nTrialFactor
        
        trialFilter = uniqTrialFactor(iFactor) ;
        
        %% Prepare
        switch char(cw_ccw)
            case 'CW'
                trials1 = find( rotatingCW(:)' & (trialFactor(:)'== trialFilter) );
            case 'CCW'
                trials1 = find( rotatingCCW(:)' & (trialFactor(:)'== trialFilter) );
        end
        
        PCell = {}; VCell = {}; ZCell = {}; OmegaCell = {};
        deconvolvedCell = {}; dffCell = {}; bodyMovementCell = {};
        idxT = {}; trials={};
        for ii = 1:length(trials1)
            
            idxT1 = false(1,session.nSamples);
            idxT1( trialStart(trials1(ii)) : trialEnd(trials1(ii)) ) = true;
            
            trials{ii} = trials1;
            idxT{ii} = idxT1;
            %PCell{ii} = freqPupilReset(idxT1);
            PCell{ii} = freqPupilReset(idxT1);
            VCell{ii} = velocity(idxT1);
            
            % Laurens
            is_active = 0; % in_light = 1;
            T = [0:(length(find(idxT1))-1)] * session.dt ;
            VL = Example_Simulations_Kalman_Model_PRT(T,velocity(idxT1),is_active, in_light, walls_only);
            colVestibularReal = 1;
            ZCell{ii} = VL.Z(:,colVestibularReal)';
            OmegaCell{ii}  = VL.Xf(:,1)';
            
            
            % Neural data
            dffCell{ii} = session.dff(:,idxT1);
            deconvolvedCell{ii} = session.deconvolved(:,idxT1);
            bodyMovementCell{ii} = session.bodyMovement(:,idxT1);
            dpupilCell{ii} = dpupil1(:,idxT1);
            
            %idxT(rotate.stationary) = false;  % rotating part only
        end
        clear ii
        
        % Trim cell into matrix (trialTypes x time)
        tmax = min(cellfun(@length,PCell)); %160;
        lengthA = length(PCell);
        PMat = zeros(lengthA,tmax);
        VMat = zeros(lengthA,tmax);
        ZMat = zeros(lengthA,tmax);
        OmegaMat = zeros(lengthA,tmax);
        for k=1:lengthA
            PMat(k,1:tmax) = PCell{k}(:,1:tmax);
            VMat(k,1:tmax) = VCell{k}(:,1:tmax);
            ZMat(k,1:tmax) = ZCell{k}(:,1:tmax);
            OmegaMat(k,1:tmax) = OmegaCell{k}(:,1:tmax);
        end
        
        % Neural activity
        meanDeconvolvedMat = zeros(lengthA, tmax);
        meanDffMat = zeros(lengthA, tmax);
        for k=1:lengthA
            meanDeconvolvedMat(k,1:tmax) = nanmean(deconvolvedCell{k}(:,1:tmax),1);
            meanDffMat(k,1:tmax) = nanmean(dffCell{k}(:,1:tmax),1);
        end
        
        % body Movement
        bodyMovementMat = zeros(lengthA, tmax);
        dpupilMat = zeros(lengthA, tmax);
        for k=1:lengthA
            bodyMovementMat(k, 1:tmax) = bodyMovementCell{k}(:,1:tmax);
            dpupilMat(k, 1:tmax) = dpupilCell{k}(:,1:tmax);
        end
        
        %Collect
        switch char(cw_ccw)
            case 'CW' , col2 = 1;
            case 'CCW', col2 = 2;
            otherwise
                error('')
        end
        uniqStageSpeed = unique(stageSpeed);
        S1 = v2struct(sessionID,smoothFactor,uniqStageSpeed,selectTrialFactor,trialFilter, ...
            quantileReset,windowSize,cw_ccw,...
            trials,velocity,idxT,tmax,PMat,VMat,ZMat,OmegaMat, ...
            meanDeconvolvedMat, meanDffMat, bodyMovementMat, dpupilMat);
        
        Results(iFactor,col2) = S1;
        
        %continue
        
        
    end %iFactor
end %cw_ccw


%% Plots only

% Figure over time
pupilData = v2struct(pupil1,dpupil1,quantileReset,pupilResetIdx,quantileReset,threshStdDPupil, freqPupilReset);
manudir = localpath('manudir');
savedir = sprintf('%s/figures/figureS8-pupil/%s-examples',manudir,datestr(now,'yyyymmdd'));
figureS8A_pupil_vs_time(session, pupilData, is_active, in_light, walls_only, 'savedir', savedir)




plotfig4tmp = false;
pupilVeloSession_plots(Results,session,smoothFactor,pupil1,dpupil1,dpupil2,...
    freqPupilReset,pupilResetIdx,quantileReset,plotfig1,plotfig2,plotfig3, plotfig4tmp ,rootdir,tag,windowSize);
if plotfig4
    pupilVeloSession_scatter(Results,session,smoothFactor,quantileReset,rootdir,tag,windowSize, timeCut)
end

%return
pause(0)

end







%%


