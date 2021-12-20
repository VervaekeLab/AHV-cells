function [psthMat, param] = session_to_psth(session, varargin)

%% Input parser
inputP = inputParser;
addParameter( inputP, 'eventType', 'pupilReset' , @(x)ismember(x,{'pupilReset','spikes'}) )
addParameter( inputP, 'classifyUsing', 'spikes' , @(x)ismember(x,{'absPupilReset','spikes'}) )
addParameter( inputP, 'intvT', 5000 ) % seconds to compare baseline / plot
addParameter( inputP, 'intvAroundEvent', -400 ) % ms around event for classification
addParameter(inputP, 'resetApart', 400) % in ms
addParameter( inputP, 'trialSegment' , 'stationaryplus', @(x)ismember(x,{'all','moving','stationary','stationaryplus','timeWindow'})  )
addParameter(inputP, 'debugMode', false)
parse(inputP, varargin{:})
param = inputP.Results;

%% Get pupil resets, filter
[pupil, dpupil] = get_pupil_data(session);
dpupil = smooth(dpupil,11);

%% Mark events

% make psth for each cell
eventIdx = markEvents(session,param);


%% Collect psth

intv = ceil( param.intvT / 1000 / session.dt); % seconds into bins

for i=1:session.nRois
    clear psth1
    psth1.nEvents       = length(eventIdx{i});
    psth1.dpupil        = psth(dpupil, eventIdx{i}, intv);
    psth1.velocity      = psth(session.velocity, eventIdx{i}, intv);
    psth1.lickResponses = psth(session.lickResponses, eventIdx{i}, intv);
    psth1.waterRewards  = psth(session.waterRewards, eventIdx{i}, intv);
    psth1.deconvolved   = psth(session.deconvolved(i,:), eventIdx{i}, intv);
    psthMat(i) = psth1;
end

%% Classify cells
psthMat = classifyCells(psthMat,session,param);


end


%% SUPPORTING FUNCTIONS

function eventIdx = markEvents(session,param)

switch param.eventType
    
    case 'spikes'
        for i=1:session.nRois
            eventIdx0{i} = find(session.deconvolved(i,:));
            %fprintf(1,'using spike events...\n')
        end
        
    case 'pupilReset'
        if( 0)
            warning('use old version\n')
            [freqPupilReset, eventIdx0{1}, dpupil, pupil] = velocityFromPupilReset(session, 'removeConsecutive', removeConsecutive);
        else
            warning('use updated\n')
            windowSize = 33; %11; %33; %33; %11;
            quantileReset = 0.95; %0.99 %0.95;
            threshStdDPupil = 1;
            removeConsecutive = true;
            [ pupilResetIdx, dpupil, pupil ] = markPupilReset(session,'threshStdDpupil',threshStdDPupil,...
                'quantileReset', quantileReset,...
                'deltaT',1,'maxFrequency',10,'threshStdDPupil', threshStdDPupil,...
                'useFindpeaks', true, 'showPlots', false);
            freqPupilReset = pupilResets_to_freq( pupilResetIdx , dpupil , windowSize, session.dt);
        end
        for i=1:session.nRois
            eventIdx0{i}= find(pupilResetIdx);
        end
        
    otherwise
        error('wrong eventType')
        
end

%% Filter events
intv  = param.resetApart;
intvbin = (intv / 1000) / session.dt ;
nSamples = session.nSamples;
for i=1:length(eventIdx0)
    eventIdxFilter{i} = filterEvents(eventIdx0{i}, nSamples, intvbin);
end

%% Filter time
%trialSegment = 'stationary';
for i=1:length(eventIdx0)
    [eventIdxTime{i}, ~] = filterTime( eventIdxFilter{i}, param.trialSegment,session);
end

%% Collect
for i=1:length(eventIdx0)
    eventIdx{i} = eventIdxTime{i};
end


end


function X = psth(x, fidx, intv)

X = nan( length(fidx), length([-intv:intv]));

% create a window around idx
for i=1:length(fidx)
    interval = fidx(i) - [-intv:intv] ;
    useidx = ( interval>=1  & interval<=length(x) ) ;
    X(i, useidx) = x( interval(useidx) );
end

end


function eventIdxFilter = filterEvents(eventIdx, nSamples, intvbin)

eventvec = false(1,nSamples);
eventvec(eventIdx) =true;

% Filter those with preceding events
for i = 1:length(eventIdx)
    idx = eventIdx(i) + [ 1:intvbin ];
    idx(idx>length(eventvec)) = [];
    eventvec( idx ) = false;
end
eventIdxFilter = find(eventvec);

end


function [eventIdxTime, useTime] = filterTime(eventIdxFilter,trialSegment,session)

%% mark trialTime

clear trialTime
uniqTrialNo = unique(session.trialNo); uniqTrialNo = uniqTrialNo(uniqTrialNo>0);
for i=1:length(uniqTrialNo)
    trialNo = uniqTrialNo(i);
    idxT = (session.trialNo == trialNo);
    trialTime(idxT) = [ 1:sum(idxT) ] *session.dt;
end



switch trialSegment
    
    case 'timeWindow'
        useTime = trialTime > 10 & trialTime < 12;
        
    case 'moving'
        useTime = session.rotating;
        
    case 'stationary'
        fprintf(1,'Use stationary segments of trial\n')
        useTime = ~session.rotating;
        
    case 'stationaryplus'
        
        margin = 2000; % msec
        intv = floor((margin/1000) / session.dt);
        
        
        useTime = ~session.rotating;
        idxR = find(session.rotating);
        for i=1:length(idxR)
            margin = idxR(i) + [-intv:intv] ;
            margin( margin>session.nSamples) = [];
            margin( margin<1) = [];
            useTime( margin ) = false;
        end
        
    otherwise
        error('trialSegment')
end

eventvec = false(1,session.nSamples);
eventvec(eventIdxFilter) = true;
eventIdxTime = find(eventvec  & useTime);


end


function Xshuf = shuffleMatrix(X)

shiftIndividualEvent = true;
nIter = 100 ;
nEvent = size(X,1);
rounding = 1;
binShiftMax = size(X,2);

for iter=1:nIter
    %if mod(iter,100)==0, fprintf(1,'%d / %d\n',iter, nIter), end
    
    
    if shiftIndividualEvent
        %fprintf(1,'shiftIndividualEvents\n')
        %shif = randperm( ceil(binShiftMax/rounding), nEvent) * rounding;
        shif = randi( binShiftMax,  1, nEvent );
        try
            Xshuf1 = nan(size(X,1),size(X,2));
        catch
            keyboard
        end
        for iR = 1:nEvent
            Xshuf1(iR,:) = circshift( X(iR,:), [0,shif(iR)]);
        end
    else
        
        %fprintf(1,'shiftAllEvents\n')
        %shif = randperm( ceil(binShiftMax/rounding), 1) * rounding;
        shif = randi( binShiftMax,  1, nEvent );
        Xshuf1 = circshift( X, [0,shif(1)]);
    end
    
    Xshuf{iter} = Xshuf1;
end

end


function psthMat = classifyCells(psthMat0,session,param)

intv = ceil( param.intvT / 1000 / session.dt); % seconds into bins
intvAroundEventBin = round((param.intvAroundEvent/1000) / session.dt);
midpoint = ceil(length([-intv:intv ])/2);
window = midpoint + [ intvAroundEventBin:0, 0:intvAroundEventBin ];
for i=1:length(psthMat0)
    psth1 = psthMat0(i);
    
    switch param.classifyUsing
    case 'spikes'
        variable = psth1.deconvolved;
    case 'absPupilReset'
        variable = abs(psth1.dpupil);
    otherwise
        error('wrong eventType')
    end

    psth1.variableShuffle = shuffleMatrix(variable);
    psth1.meanVariable = nanmean( variable,1);
    psth1.meanVariableShuffle = cell2mat( cellfun(@(x)nanmean(x,1), psth1.variableShuffle, 'UniformOutput',false)' ) ;
    ydata = (abs(psth1.meanVariable));
    yshuf = (abs(psth1.meanVariableShuffle));
    %pval =  1-mean( any(ydata(:,window) > yshuf(:,window),2)) ;
    %psth1.pval = pval;    
    ythresh = quantile(abs(psth1.meanVariableShuffle), 0.95, 1);
    psth1.ythresh = ythresh;
    psth1.pval = 1-(any(ydata(:,window) > ythresh(:,window),2));
    psth1.tunedCells =  psth1.pval<0.05;
    psthMat(i) = psth1;
end
end