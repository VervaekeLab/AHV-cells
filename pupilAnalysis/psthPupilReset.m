function [SN, hfig] = psthPupilReset(session, varargin)

hfig = figure; close
hfig(1) =  [];


%% inputParser

inputP = inputParser;
addParameter( inputP, 'nShowPlots', 0 , @(x)x<=64)
addParameter( inputP, 'plotOnlySignificant', true)
addParameter( inputP, 'intvT', 5000 ) % seconds to compare baseline / plot
addParameter( inputP, 'trialSegment' , 'stationaryplus', @(x)ismember(x,{'all','moving','stationary','stationaryplus','stationaryplusminus'})  )
addParameter( inputP, 'tag'       , '', @ischar  )
addParameter( inputP, 'removeConsecutive' , 0  )
addParameter( inputP, 'resetDirection' , 'CCW'  )
addParameter( inputP, 'filterTrials' , []  )
addParameter(inputP, 'resetApart', 400) % in ms
addParameter(inputP, 'tmargin', 400) % in ms
addParameter(inputP, 'noPupilResetBefore', 0) % in ms
addParameter(inputP, 'removeFirstPupilReset', false) 
addParameter(inputP, 'pthresh', 0.05) 
addParameter(inputP, 'windowSize', 33)
addParameter(inputP, 'quantileReset', 0.95)
addParameter(inputP, 'threshStdDPupil', 1)
addParameter(inputP, 'overwritePupilResetIdx', [])
addParameter( inputP, 'savePlots'     , true, @islogical  )
addParameter( inputP, 'savedir'       , '', @ischar  )
addParameter( inputP, 'noutplot'       , []  )
parse(inputP, varargin{:})

p = (inputP.Results);
v2struct(p)



%% Get pupil resets, filter 

if( 0)
    warning('use old version\n')
    [freqPupilReset, pupilResetIdx0, dpupil, pupil] = velocityFromPupilReset(session, 'removeConsecutive', removeConsecutive);
else
    warning('use updated\n')
    %windowSize = 33; %11; %33; %33; %11;
    %quantileReset = 0.95; %0.99 %0.95;
    %threshStdDPupil = 1;
    removeConsecutive = true;
    [ pupilResetIdx0, dpupil, pupil ] = markPupilReset(session,'threshStdDpupil',threshStdDPupil,...
        'quantileReset', quantileReset,...
        'deltaT',1,'maxFrequency',10,'threshStdDPupil', threshStdDPupil,...
        'useFindpeaks', true, 'showPlots', false);
    %freqPupilReset = pupilResets_to_freq( pupilResetIdx0 , dpupil , windowSize, session.dt);
    freqPupilReset = pupilResets_to_freqMax( pupilResetIdx0 , dpupil , windowSize, session.dt);
end

if ~isempty(overwritePupilResetIdx)
    warning('overwrite pupilReset\n')
    pupilResetIdx0 = overwritePupilResetIdx;
end
[pupilResetIdx, tag1] = filter_fPupilResetIdx( pupilResetIdx0, dpupil, resetDirection, resetApart, ...
    noPupilResetBefore, removeFirstPupilReset, trialSegment, filterTrials, session, tag);
fPupilResetIdx = find(pupilResetIdx);

%test
if (0)
   warning('test filter')
    plotPupilTime
end

%% Skip session if no pupil reset? 
if isempty(fPupilResetIdx)
    SN = [];
    return
end


%% Gather stats
intv = ceil( intvT / 1000 / session.dt); % seconds into bins
%tmargin = 0.1 ; % ms


%[  nReset, tWindow, PSTH, trialNo, trialSpeed, trialVelocity , ...
%    meanDeconvPupil, stdDeconvPupil, seDeconvPupil, ...
%    yquantile, ymean0, ymean0margin, ypass, pmean0, pmean0margin, pupilCell, pupilCellShuffle, statsShuffle ] = ...
%        psthPupilReset_gather_reset( pupilResetIdx, pupil, dpupil, intv, tmargin, pthresh, session); 
[  nReset, tWindow, PSTH, ...
    trialNo, trialSpeed, trialVelocity , meanDeconvPupil, stdDeconvPupil, seDeconvPupil, ...
    pupilCellShuffle, statsShuffle ] = ...
    psthPupilReset_gather_resetTest( pupilResetIdx, pupil, dpupil, ...
    intv, tmargin, pthresh, session);


%% Prepare output
%stats = v2struct(intv, freqPupilReset,pupilResetIdx,fPupilResetIdx, trialNo, trialSpeed, trialVelocity, ...
%    PSTH, ...
%    meanDeconvPupil, stdDeconvPupil, seDeconvPupil, yquantile, ymean0, ymean0margin, tmargin, pmean0, pmean0margin);
stats = v2struct(intv, freqPupilReset,pupilResetIdx,fPupilResetIdx, trialNo, trialSpeed, trialVelocity, ...
    PSTH, meanDeconvPupil, stdDeconvPupil, seDeconvPupil);
sessionID = session.sessionID;
sessionMeta = session_meta(session);
%SN = v2struct(sessionID, sessionMeta, stats, pthresh, ypass, ymean0, pmean0, pupilCell, pupilCellShuffle, statsShuffle);
SN = v2struct(sessionID, sessionMeta, stats, pthresh, pupilCellShuffle, statsShuffle);


%% Make figures


hfig1 = []; hfig2 = []; hfig3 = []; useImagesc = true; 
if nShowPlots>0
    
    [hfig1] = psthPupilReset_figure1( SN, session, [] );    
    %[hfig2] = psthPupilReset_figure2( pupilCellShuffle, fPupilResetIdx, intv, nShowPlots, ...
    %    PSTH, ...
    %    meanDeconvPupil, stdDeconvPupil,seDeconvPupil, session, hfig2 , plotOnlySignificant, ...
    %    ypass, tag1, pthresh, pmean0margin,statsShuffle , useImagesc, tmargin, noutplot);
    [hfig2] = psthPupilReset_figure2( pupilCellShuffle, fPupilResetIdx, intv, nShowPlots, ...
        PSTH, meanDeconvPupil, stdDeconvPupil,seDeconvPupil, session, hfig2 , plotOnlySignificant, ...
        tag1, pthresh, statsShuffle , useImagesc, tmargin, noutplot);
    [hfig3] = psthPupilReset_figure3( SN, session, nShowPlots, plotOnlySignificant, [] );
    hfig = [hfig1, hfig2, hfig3];
    
    % Save plots
    if savePlots
        if isempty(savedir)
            savedir = sprintf('../tmp/%s', datestr(now,'yyyymmdd'));
        end
        %savedir = regexprep(savedir,'[^a-zA-Z0-9./-]','')
        if ~exist(savedir,'dir')
            mkdir(savedir),
            fprintf(1, 'Mkdir %s\n',savedir);
        end
        savename = sprintf('%s/%s-reset%s', savedir, session.sessionID,resetDirection);
        
        savename1 = sprintf('%s-pupilReset', savename);
        saveas(hfig1,[savename1,'.png'],'png')
        fprintf(1,'Saved to %s\n',savename1)
        saveas(hfig1,[savename1,'.fig'],'fig')
        fprintf(1,'Saved to %s\n',savename1)
        
        savename2 = sprintf('%s-psth-%s', savename,tag);
        saveas(hfig2,[savename2,'.png'],'png')
        saveas(hfig2,[savename2,'.eps'],'epsc')
        fprintf(1,'Saved to %s.png\n',savename)
        saveas(hfig2,[savename2,'.fig'],'fig')
        fprintf(1,'Saved to %s.fig\n',savename2)
        
    end
    
end

return




%%



function [pupilResetIdx, tag1] = filter_fPupilResetIdx( pupilResetIdx0, dpupil, resetDirection, resetApart, ...
    noPupilResetBefore, removeFirstPupilReset, trialSegment, filterTrials, session, tag)



    
% filter direction
pupilResetIdxA = pupilResetIdx0 & dpupil>0;
pupilResetIdxB = pupilResetIdx0 & dpupil<0;
switch resetDirection
    case 'both'
        pupilResetIdx = pupilResetIdx0;
    case 'CCW'
        pupilResetIdx = pupilResetIdxA;
    case 'CW'
        pupilResetIdx = pupilResetIdxB;
    otherwise
        error('reset Direction')
end

% remove pupilResetIdx which are too close to another
% filter resets 400ms apart
if resetApart>0
    fPupilResetIdx = find(pupilResetIdx);
    for i=1:length(fPupilResetIdx)
        t = fPupilResetIdx(i);
        intvApart = (resetApart/1000)/session.dt;
        idx = t + [ 1  :  min( intvApart, session.nSamples-2)];
        idx( idx> session.nSamples) = [];
        pupilResetIdx(idx )  = 0;
    end
end


% remove pupilResetIdx which have another pupil reset before
if noPupilResetBefore>0
    
    fPupilResetIdx = find(pupilResetIdx);
    dfPupilReset = [ 0 , diff(fPupilResetIdx) ] * session.dt;
    
    idx = dfPupilReset > noPupilResetBefore/1000 ;
    fPupilResetIdx = fPupilResetIdx(idx) ;
    
    pupilResetIdx = false( size(pupilResetIdx) );
    pupilResetIdx( fPupilResetIdx ) = true ;
    
end


%% mark trialTime

clear trialTime
uniqTrialNo = unique(session.trialNo); uniqTrialNo = uniqTrialNo(uniqTrialNo>0);
for i=1:length(uniqTrialNo)
    trialNo = uniqTrialNo(i);
    idxT = (session.trialNo == trialNo);
    trialTime(idxT) = [ 1:sum(idxT) ] *session.dt;
end

%% remove first pupil Reset of Trial

if (removeFirstPupilReset)
    for i=1:length(uniqTrialNo)
        trialNo = uniqTrialNo(i);
        
        idxT = (session.trialNo == trialNo & session.rotating);
        fPupilResetRotating = find( pupilResetIdx &  idxT, 1, 'first' ) ;
        if ~isempty(fPupilResetRotating)
            pupilResetIdx( fPupilResetRotating ) = false ;
        end
        idxT = (session.trialNo == trialNo & ~session.rotating);
        fPupilResetStationary = find( pupilResetIdx &  idxT, 1, 'first' ) ;
        if ~isempty(fPupilResetStationary)
            pupilResetIdx( fPupilResetStationary ) = false ;
        end
    end
end



%%
switch trialSegment
    
    case 'all'
        fPupilResetIdx = find(pupilResetIdx);
        tag1 = sprintf('%s %s\n%s',session.sessionID,'(stationary+moving)',tag);
    case 'stationary'
        fPupilResetIdx = find(pupilResetIdx & ~session.rotating );
        tag1 = sprintf('%s %s\n%s',session.sessionID,'(stationary)',tag);
    case 'moving'
        minspeed = 1;
        fPupilResetIdx = find(pupilResetIdx & session.rotating  & abs(session.velocity)>1);
        tag1 = sprintf('%s %s\n%s',session.sessionID,'(moving)',tag);
    
    case 'stationaryplus'
        
        
        %t = fPupilResetIdx(i);
        %intvApart = (resetApart/1000)/session.dt;
        %idx = t + [ 1  :  min( intvApart, session.nSamples-2)];
        %idx( idx> session.nSamples) = [];
        %pupilResetIdx(idx )  = 0;
        
        margin = 2; %
        excludeRotate = session.rotating;
        uniqTrialNo = unique(session.trialNo); uniqTrialNo = uniqTrialNo(uniqTrialNo>0);
        for i=1:length(uniqTrialNo)
            trialNo = uniqTrialNo(i);
            fRotating = find (session.trialNo == trialNo & session.rotating, 1, 'last' );
            idx = fRotating + [1 : margin/session.dt ];
            excludeRotate(idx) = 1;
            
            
        end
        
        pupilResetIdx  = pupilResetIdx & ~excludeRotate;
        fPupilResetIdx = find(pupilResetIdx);
        tag1 = sprintf('%s (stationary >%dsec after rotation) \n%s',session.sessionID, margin, tag);
        
        
       case 'stationaryplusminus'
        
        
        %t = fPupilResetIdx(i);
        %intvApart = (resetApart/1000)/session.dt;
        %idx = t + [ 1  :  min( intvApart, session.nSamples-2)];
        %idx( idx> session.nSamples) = [];
        %pupilResetIdx(idx )  = 0;
        
        margin = 1; %
        excludeRotate = session.rotating;
        uniqTrialNo = unique(session.trialNo); uniqTrialNo = uniqTrialNo(uniqTrialNo>0);
        for i=1:length(uniqTrialNo)
            trialNo = uniqTrialNo(i);
            fRotating = find (session.trialNo == trialNo & session.rotating, 1, 'last' );
            idx = fRotating + floor([1 : margin/session.dt ]);
            excludeRotate(idx) = 1;
            
            fRotating = find (session.trialNo == trialNo & session.rotating, 1, 'first' );
            idx = fRotating + floor([ -margin/session.dt : -1 ]);
            idx(idx<1) = [];
            excludeRotate(idx) = 1;
           
        end
        
        pupilResetIdx  = pupilResetIdx & ~excludeRotate;
        fPupilResetIdx = find(pupilResetIdx);
        tag1 = sprintf('%s (stationary >%dsec after rotation) \n%s',session.sessionID, margin, tag);
      
        
        

%         %fPupilResetIdx = find(pupilResetIdx & session.rotating & trialTime > 6 ); tag1 = sprintf('%s %s\n%s',session.sessionID,'(stationary >6s)',tag);
%         session.rotatingplus = session.rotating;
%         idx = find(session.rotating);
%         margin = 2; % 1second
%         intv = 0:floor( margin / session.dt);
%         idxmargin = floor(idx + margin/session.dt); idxmargin(idxmargin>session.nSamples) = [];
%         session.rotatingplus( idxmargin ) = 1;
%         fPupilResetIdx = find(pupilResetIdx & ~session.rotatingplus );
%         tag1 = sprintf('%s (stationary >%dsec after rotation) \n%s',session.sessionID, margin, tag);
        
    case 'stationarymargin'
        %fPupilResetIdx = find(pupilResetIdx & session.rotating & trialTime > 6 ); tag1 = sprintf('%s %s\n%s',session.sessionID,'(stationary >6s)',tag);
        session.rotatingplus = session.rotating;
        idx = find(session.rotating);
        margin = 2; % 1second
        idxmargin = floor(idx + margin/session.dt); 
        idxmargin(idxmargin>session.nSamples) = [];
        idxmargin(idxmargin>session.nSamples) = [];
        session.rotatingplus( idxmargin ) = 1;
        fPupilResetIdx = find(pupilResetIdx & ~session.rotatingplus );
        tag1 = sprintf('%s (stationary >%dsec after rotation) \n%s',session.sessionID, margin, tag);
        
        
    otherwise
        error('trialSegment')
end




%% Filter trials
fPupilResetIdx0 = fPupilResetIdx;
if ~isempty(filterTrials)
    trialsReset = session.trialNo(fPupilResetIdx0);
    if islogical(filterTrials), filterTrials = find(filterTrials); end
    trialsIncluded = ismember(trialsReset, filterTrials );
    fPupilResetIdx = fPupilResetIdx0( trialsIncluded );
end


pupilResetIdx = false(size(pupilResetIdx0));
pupilResetIdx( fPupilResetIdx ) = true;






